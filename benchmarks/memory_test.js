/**
 * OCSV Memory Leak Test
 * Tests lazy mode for memory leaks and memory usage
 */

import { parseCSV } from '../bindings/index.js';
import { readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

console.log('🧪 OCSV Memory Leak Test\n');
console.log('─'.repeat(60));

// Check if large file exists
const largeFilePath = resolve('./examples/large_data.csv');
if (!existsSync(largeFilePath)) {
	console.error('❌ Large test file not found: examples/large_data.csv');
	console.error('   Using smaller test data instead...\n');

	// Generate test data
	const rows = 100000;
	const testData = Array.from({ length: rows }, (_, i) =>
		`${i},User${i},user${i}@example.com,City${i % 100}`
	).join('\n');

	runMemoryTest(testData, 'Generated 100k rows');
} else {
	console.log('📂 Loading large test file...');
	const data = readFileSync(largeFilePath, 'utf-8');
	const sizeMB = (data.length / 1024 / 1024).toFixed(2);
	console.log(`   File size: ${sizeMB} MB\n`);

	runMemoryTest(data, `large_data.csv (${sizeMB} MB)`);
}

function runMemoryTest(data, description) {
	console.log(`🔬 Testing with: ${description}`);
	console.log('─'.repeat(60));

	// Test 1: Single parse memory usage
	console.log('\n1️⃣  Single Parse Memory Usage\n');

	if (global.gc) global.gc();
	const memBefore = process.memoryUsage().heapUsed / 1024 / 1024;

	const result = parseCSV(data, { mode: 'lazy' });

	const memAfter = process.memoryUsage().heapUsed / 1024 / 1024;
	const memDelta = memAfter - memBefore;

	console.log(`   Memory before: ${memBefore.toFixed(2)} MB`);
	console.log(`   Memory after:  ${memAfter.toFixed(2)} MB`);
	console.log(`   Memory delta:  ${memDelta.toFixed(2)} MB`);

	// Access some rows
	console.log('\n   Accessing 100 rows...');
	for (let i = 0; i < 100; i++) {
		result.getRow(i).toArray();
	}

	const memAfterAccess = process.memoryUsage().heapUsed / 1024 / 1024;
	console.log(`   Memory after access: ${memAfterAccess.toFixed(2)} MB`);
	console.log(`   Access overhead: ${(memAfterAccess - memAfter).toFixed(2)} MB`);

	result.destroy();

	if (global.gc) global.gc();
	const memAfterDestroy = process.memoryUsage().heapUsed / 1024 / 1024;
	console.log(`   Memory after destroy: ${memAfterDestroy.toFixed(2)} MB`);

	const target = 200;
	if (memDelta < target) {
		console.log(`   ✅ Memory usage: ${memDelta.toFixed(2)} MB < ${target} MB`);
	} else {
		console.log(`   ❌ Memory usage: ${memDelta.toFixed(2)} MB >= ${target} MB`);
	}

	// Test 2: Multiple iterations (leak detection)
	console.log('\n2️⃣  Memory Leak Test (10 iterations)\n');

	const iterations = 10;
	const memReadings = [];

	for (let i = 0; i < iterations; i++) {
		if (global.gc) global.gc();

		const memStart = process.memoryUsage().heapUsed / 1024 / 1024;

		const result = parseCSV(data, { mode: 'lazy' });

		// Use result
		for (let j = 0; j < 100; j++) {
			result.getRow(j).toArray();
		}

		result.destroy();

		if (global.gc) global.gc();

		const memEnd = process.memoryUsage().heapUsed / 1024 / 1024;
		memReadings.push(memEnd);

		console.log(`   Iteration ${(i + 1).toString().padStart(2)}: ${memEnd.toFixed(2)} MB`);
	}

	// Analyze memory growth
	const firstReading = memReadings[0];
	const lastReading = memReadings[memReadings.length - 1];
	const growth = lastReading - firstReading;
	const growthPct = (growth / firstReading) * 100;

	console.log(`\n   📊 Analysis:`);
	console.log(`      First reading:  ${firstReading.toFixed(2)} MB`);
	console.log(`      Last reading:   ${lastReading.toFixed(2)} MB`);
	console.log(`      Memory growth:  ${growth.toFixed(2)} MB (${growthPct.toFixed(1)}%)`);

	const maxGrowth = 50;
	if (growth < maxGrowth) {
		console.log(`   ✅ No significant memory leak detected`);
	} else {
		console.log(`   ❌ Possible memory leak: ${growth.toFixed(2)} MB growth`);
	}

	// Test 3: LRU Cache behavior
	console.log('\n3️⃣  LRU Cache Behavior\n');

	if (global.gc) global.gc();
	const cacheMemBefore = process.memoryUsage().heapUsed / 1024 / 1024;

	const cacheResult = parseCSV(data, { mode: 'lazy' });

	// Access many rows to test cache eviction
	console.log('   Accessing 2000 rows (cache size: 1000)...');
	for (let i = 0; i < 2000; i++) {
		cacheResult.getRow(i).get(0);
	}

	const cacheMemAfter = process.memoryUsage().heapUsed / 1024 / 1024;
	const cacheSize = cacheResult._rowCache.size;

	console.log(`   Cache size: ${cacheSize} rows`);
	console.log(`   Memory for cache: ${(cacheMemAfter - cacheMemBefore).toFixed(2)} MB`);

	if (cacheSize <= 1000) {
		console.log(`   ✅ LRU eviction working (size <= 1000)`);
	} else {
		console.log(`   ❌ LRU eviction not working (size > 1000)`);
	}

	cacheResult.destroy();

	// Summary
	console.log('\n─'.repeat(60));
	console.log('\n📋 Summary\n');

	let passed = 0;
	let failed = 0;

	if (memDelta < target) {
		console.log(`   ✅ Memory usage acceptable: ${memDelta.toFixed(2)} MB`);
		passed++;
	} else {
		console.log(`   ❌ Memory usage too high: ${memDelta.toFixed(2)} MB`);
		failed++;
	}

	if (growth < maxGrowth) {
		console.log(`   ✅ No memory leaks detected`);
		passed++;
	} else {
		console.log(`   ❌ Possible memory leak: ${growth.toFixed(2)} MB`);
		failed++;
	}

	if (cacheSize <= 1000) {
		console.log(`   ✅ LRU cache working correctly`);
		passed++;
	} else {
		console.log(`   ❌ LRU cache not evicting: ${cacheSize} rows`);
		failed++;
	}

	console.log('\n─'.repeat(60));

	if (failed === 0) {
		console.log('\n✅ ALL MEMORY TESTS PASSED\n');
		process.exit(0);
	} else {
		console.log(`\n⚠️  ${failed} test(s) failed, ${passed} passed\n`);
		process.exit(1);
	}
}

console.log('\n💡 Tip: Run with --expose-gc for more accurate results:');
console.log('   bun --expose-gc benchmarks/memory_test.js\n');
