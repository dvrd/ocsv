#!/usr/bin/env bun
/**
 * OCSV Lazy Mode Benchmark
 * Tests lazy mode performance with large CSV file
 */

import { parseCSV } from './bindings/index.js';
import { readFileSync } from 'fs';
import { resolve } from 'path';

console.log('🏁 OCSV Lazy Mode Benchmark\n');
console.log('─'.repeat(60));

// Find large data file
const filePath = resolve('./examples/large_data.csv');

try {
	console.log('📂 Loading test file...');
	const data = readFileSync(filePath, 'utf-8');
	const fileSize = data.length;
	const fileSizeMB = (fileSize / 1024 / 1024).toFixed(2);
	const fileSizeGB = (fileSize / 1024 / 1024 / 1024).toFixed(2);

	console.log(`   File: ${filePath}`);
	console.log(`   Size: ${fileSizeMB} MB (${fileSizeGB} GB)`);
	console.log(`   Bytes: ${fileSize.toLocaleString()}\n`);

	console.log('─'.repeat(60));
	console.log('\n⚡ Parsing with Lazy Mode\n');

	// Parse with lazy mode
	const startTime = performance.now();
	const startMem = process.memoryUsage().heapUsed / 1024 / 1024;

	const result = parseCSV(data, { mode: 'lazy', hasHeader: true });

	const endTime = performance.now();
	const endMem = process.memoryUsage().heapUsed / 1024 / 1024;

	const parseTime = (endTime - startTime) / 1000;
	const throughput = (fileSize / 1024 / 1024) / parseTime;
	const rowsPerSec = result.rowCount / parseTime;
	const memUsed = endMem - startMem;

	console.log('📊 Results:');
	console.log(`   ⏱️  Parse time: ${parseTime.toFixed(2)}s`);
	console.log(`   📈 Throughput: ${throughput.toFixed(2)} MB/s`);
	console.log(`   🔢 Rows/sec: ${rowsPerSec.toLocaleString(undefined, { maximumFractionDigits: 0 })}`);
	console.log(`   📦 Row count: ${result.rowCount.toLocaleString()}`);
	console.log(`   💾 Memory: ${memUsed.toFixed(2)} MB`);
	console.log(`   📋 Headers: ${result.headers?.length || 0} columns\n`);

	// Test random access
	console.log('🎯 Testing Random Access...');
	const midRow = Math.floor(result.rowCount / 2);
	const accessStart = performance.now();
	const row = result.getRow(midRow);
	const field = row.get(1);
	const accessEnd = performance.now();
	const accessTime = accessEnd - accessStart;

	console.log(`   Mid-row access (row ${midRow.toLocaleString()}): ${accessTime.toFixed(3)}ms`);
	console.log(`   Sample field: "${field.substring(0, 50)}..."\n`);

	// Show sample rows
	console.log('📄 Sample Rows:\n');
	console.log('   First 3 rows:');
	for (let i = 0; i < Math.min(3, result.rowCount); i++) {
		const r = result.getRow(i);
		const preview = r.toArray().slice(0, 4).join(', ');
		console.log(`     Row ${i + 1}: [${preview}, ...]`);
	}

	console.log('\n   Last 3 rows:');
	for (let i = Math.max(0, result.rowCount - 3); i < result.rowCount; i++) {
		const r = result.getRow(i);
		const preview = r.toArray().slice(0, 4).join(', ');
		console.log(`     Row ${i + 1}: [${preview}, ...]`);
	}

	// Clean up
	result.destroy();

	console.log('\n' + '─'.repeat(60));
	console.log('\n✅ Benchmark completed successfully!\n');

	// Validation
	console.log('🎯 Performance Targets:');
	const passedChecks = [];
	const failedChecks = [];

	if (parseTime <= 10) {
		passedChecks.push(`✅ Parse time: ${parseTime.toFixed(2)}s ≤ 10s`);
	} else {
		failedChecks.push(`❌ Parse time: ${parseTime.toFixed(2)}s > 10s`);
	}

	if (throughput >= 100) {
		passedChecks.push(`✅ Throughput: ${throughput.toFixed(2)} MB/s ≥ 100 MB/s`);
	} else {
		failedChecks.push(`❌ Throughput: ${throughput.toFixed(2)} MB/s < 100 MB/s`);
	}

	// Memory check: should be reasonable (< 2x file size for string + parser overhead)
	const maxMem = (fileSize / 1024 / 1024) * 2;
	if (memUsed < maxMem) {
		passedChecks.push(`✅ Memory: ${memUsed.toFixed(2)} MB < ${maxMem.toFixed(0)} MB (2x file size)`);
	} else {
		failedChecks.push(`❌ Memory: ${memUsed.toFixed(2)} MB ≥ ${maxMem.toFixed(0)} MB`);
	}

	passedChecks.forEach(check => console.log(`   ${check}`));
	failedChecks.forEach(check => console.log(`   ${check}`));

	console.log(`\n   ${passedChecks.length}/${passedChecks.length + failedChecks.length} checks passed\n`);

	process.exit(failedChecks.length > 0 ? 1 : 0);

} catch (error) {
	console.error('\n❌ Error:', error.message);
	console.error('\nStack:', error.stack);
	process.exit(1);
}
