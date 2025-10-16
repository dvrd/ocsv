/**
 * OCSV Performance Comparison Benchmark
 * Compares FFI Direct vs Eager Mode vs Lazy Mode
 */

import { parseCSV } from '../bindings/index.js';
import { dlopen, FFIType, ptr } from 'bun:ffi';
import { readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

console.log('🏁 OCSV Performance Comparison\n');
console.log('─'.repeat(60));

// Check if large file exists
const largeFilePath = resolve('./examples/large_data.csv');
if (!existsSync(largeFilePath)) {
	console.error('❌ Large test file not found: examples/large_data.csv');
	console.error('   Please generate the file first or use a smaller test.');
	process.exit(1);
}

console.log('📂 Loading test file...');
const data = readFileSync(largeFilePath, 'utf-8');
const fileSize = data.length;
const fileSizeMB = (fileSize / 1024 / 1024).toFixed(2);
const fileSizeGB = (fileSize / 1024 / 1024 / 1024).toFixed(2);

console.log(`   File size: ${fileSizeMB} MB (${fileSizeGB} GB)`);
console.log(`   Raw bytes: ${fileSize.toLocaleString()}\n`);

console.log('─'.repeat(60));

// 1. FFI Direct (baseline)
console.log('\n1️⃣  FFI Direct (baseline)\n');

const libPath = resolve('./libocsv.dylib');
if (!existsSync(libPath)) {
	console.error('❌ Library not found: libocsv.dylib');
	process.exit(1);
}

const lib = dlopen(libPath, {
	ocsv_parser_create: { returns: FFIType.ptr },
	ocsv_parser_destroy: { args: [FFIType.ptr], returns: FFIType.void },
	ocsv_parse_string: { args: [FFIType.ptr, FFIType.cstring, FFIType.i32], returns: FFIType.i32 },
	ocsv_get_row_count: { args: [FFIType.ptr], returns: FFIType.i32 },
});

const parser = lib.symbols.ocsv_parser_create();
const buffer = Buffer.from(data + '\0');

const ffiStart = performance.now();
lib.symbols.ocsv_parse_string(parser, ptr(buffer), data.length);
const ffiEnd = performance.now();

const ffiRowCount = lib.symbols.ocsv_get_row_count(parser);
lib.symbols.ocsv_parser_destroy(parser);

const ffiTime = (ffiEnd - ffiStart) / 1000;
const ffiThroughput = (fileSize / 1024 / 1024) / ffiTime;
const ffiRowsPerSec = ffiRowCount / ffiTime;

console.log(`   ⏱️  Parse time: ${ffiTime.toFixed(2)}s`);
console.log(`   📊 Throughput: ${ffiThroughput.toFixed(2)} MB/s`);
console.log(`   📈 Rows/sec: ${ffiRowsPerSec.toLocaleString(undefined, {maximumFractionDigits: 0})}`);
console.log(`   📦 Row count: ${ffiRowCount.toLocaleString()}`);

// 2. Lazy Mode
console.log('\n2️⃣  Lazy Mode (new)\n');

const lazyStart = performance.now();
const lazyResult = parseCSV(data, { mode: 'lazy' });
const lazyEnd = performance.now();

const lazyTime = (lazyEnd - lazyStart) / 1000;
const lazyThroughput = (fileSize / 1024 / 1024) / lazyTime;
const lazyRowsPerSec = lazyResult.rowCount / lazyTime;

console.log(`   ⏱️  Parse time: ${lazyTime.toFixed(2)}s`);
console.log(`   📊 Throughput: ${lazyThroughput.toFixed(2)} MB/s`);
console.log(`   📈 Rows/sec: ${lazyRowsPerSec.toLocaleString(undefined, {maximumFractionDigits: 0})}`);
console.log(`   📦 Row count: ${lazyResult.rowCount.toLocaleString()}`);
console.log(`   ⚡ Speedup vs FFI: ${(ffiTime / lazyTime).toFixed(2)}x`);
console.log(`   📉 Overhead: ${((lazyTime / ffiTime - 1) * 100).toFixed(1)}%`);

// Test random access performance
console.log('\n   Testing random access...');
const accessStart = performance.now();
const midRow = lazyResult.getRow(Math.floor(lazyResult.rowCount / 2));
const accessTime = performance.now() - accessStart;
console.log(`   🎯 Mid-row access: ${accessTime.toFixed(3)}ms`);
console.log(`   📄 Sample field: "${midRow.get(1).substring(0, 20)}..."`);

lazyResult.destroy();

// 3. Eager Mode
console.log('\n3️⃣  Eager Mode (current)\n');

const eagerStart = performance.now();
const eagerResult = parseCSV(data);
const eagerEnd = performance.now();

const eagerTime = (eagerEnd - eagerStart) / 1000;
const eagerThroughput = (fileSize / 1024 / 1024) / eagerTime;
const eagerRowsPerSec = eagerResult.rowCount / eagerTime;

console.log(`   ⏱️  Parse time: ${eagerTime.toFixed(2)}s`);
console.log(`   📊 Throughput: ${eagerThroughput.toFixed(2)} MB/s`);
console.log(`   📈 Rows/sec: ${eagerRowsPerSec.toLocaleString(undefined, {maximumFractionDigits: 0})}`);
console.log(`   📦 Row count: ${eagerResult.rowCount.toLocaleString()}`);
console.log(`   🐌 Slowdown vs FFI: ${(eagerTime / ffiTime).toFixed(2)}x`);
console.log(`   📈 Overhead: ${((eagerTime / ffiTime - 1) * 100).toFixed(0)}%`);

// 4. Summary
console.log('\n─'.repeat(60));
console.log('\n📊 Performance Summary\n');

const results = [
	{ name: 'FFI Direct', throughput: ffiThroughput, time: ffiTime, color: '🥇' },
	{ name: 'Lazy Mode', throughput: lazyThroughput, time: lazyTime, color: '🥈' },
	{ name: 'Eager Mode', throughput: eagerThroughput, time: eagerTime, color: '🥉' },
].sort((a, b) => b.throughput - a.throughput);

results.forEach((r, i) => {
	const pct = ((r.throughput / ffiThroughput) * 100).toFixed(0);
	console.log(`${r.color} ${r.name.padEnd(12)} ${r.throughput.toFixed(2).padStart(7)} MB/s  (${pct}%)  ${r.time.toFixed(2)}s`);
});

console.log('\n📈 Performance Improvements:\n');
console.log(`   Lazy vs Eager:  ${(eagerTime / lazyTime).toFixed(2)}x faster`);
console.log(`   Lazy vs FFI:    ${(lazyTime / ffiTime).toFixed(2)}x overhead`);

// Validation
console.log('\n─'.repeat(60));
console.log('\n🎯 Validation\n');

const target = 180;
let passed = 0;
let failed = 0;

// Check 1: Throughput
if (lazyThroughput >= target) {
	console.log(`   ✅ Lazy mode throughput: ${lazyThroughput.toFixed(2)} MB/s >= ${target} MB/s`);
	passed++;
} else {
	console.log(`   ❌ Lazy mode throughput: ${lazyThroughput.toFixed(2)} MB/s < ${target} MB/s`);
	failed++;
}

// Check 2: Parse time
const maxTime = 7;
if (lazyTime <= maxTime) {
	console.log(`   ✅ Lazy mode parse time: ${lazyTime.toFixed(2)}s <= ${maxTime}s`);
	passed++;
} else {
	console.log(`   ❌ Lazy mode parse time: ${lazyTime.toFixed(2)}s > ${maxTime}s`);
	failed++;
}

// Check 3: FFI overhead
const maxOverhead = 1.15; // 15% overhead
if (lazyTime / ffiTime <= maxOverhead) {
	console.log(`   ✅ FFI overhead: ${((lazyTime / ffiTime - 1) * 100).toFixed(1)}% <= 15%`);
	passed++;
} else {
	console.log(`   ⚠️  FFI overhead: ${((lazyTime / ffiTime - 1) * 100).toFixed(1)}% > 15%`);
	// This is a warning, not a failure
}

// Check 4: Faster than eager
if (lazyTime < eagerTime) {
	console.log(`   ✅ Lazy faster than eager: ${(eagerTime / lazyTime).toFixed(2)}x`);
	passed++;
} else {
	console.log(`   ❌ Lazy slower than eager: ${(lazyTime / eagerTime).toFixed(2)}x`);
	failed++;
}

console.log('\n─'.repeat(60));

if (failed === 0) {
	console.log('\n✅ ALL CHECKS PASSED - Lazy mode meets all targets!\n');
	process.exit(0);
} else {
	console.log(`\n⚠️  ${failed} check(s) failed, ${passed} passed\n`);
	process.exit(1);
}
