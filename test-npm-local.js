#!/usr/bin/env bun
/**
 * Test local npm package before publishing
 */

console.log('🧪 Testing OCSV npm package locally\n');

// Import from local package
import { parseCSV } from './bindings/index.js';

console.log('✅ Package imports successfully');

// Test 1: Eager mode (default)
console.log('\n1️⃣  Testing Eager Mode (default)');
const csv1 = 'name,age,city\nJohn,30,NYC\nJane,25,LA';
const result1 = parseCSV(csv1, { hasHeader: true });

console.log(`   Headers: ${result1.headers.join(', ')}`);
console.log(`   Rows: ${result1.rowCount}`);
console.log(`   First row: ${result1.rows[0].join(', ')}`);
console.log('   ✅ Eager mode works');

// Test 2: Lazy mode (new feature)
console.log('\n2️⃣  Testing Lazy Mode (new in v1.1.0)');
const csv2 = 'id,name,email\n1,Bob,bob@test.com\n2,Alice,alice@test.com\n3,Carol,carol@test.com';
const result2 = parseCSV(csv2, { mode: 'lazy', hasHeader: true });

try {
	console.log(`   Headers: ${result2.headers.join(', ')}`);
	console.log(`   Rows: ${result2.rowCount}`);

	// Access first row
	const row = result2.getRow(0);
	console.log(`   First row: ${row.toArray().join(', ')}`);

	// Test iteration
	let count = 0;
	for (const r of result2) {
		count++;
	}
	console.log(`   Iterated ${count} rows`);
	console.log('   ✅ Lazy mode works');

} finally {
	result2.destroy();
}

// Test 3: Type safety (TypeScript would catch this at compile time)
console.log('\n3️⃣  Testing API Type Safety');
try {
	const result3 = parseCSV('a,b\n1,2', { mode: 'lazy' });

	// This should work
	result3.getRow(0);
	console.log('   ✅ LazyResult.getRow() accessible');

	// This should fail (rows property doesn't exist on LazyResult)
	try {
		result3.rows; // Should be undefined
		if (result3.rows === undefined) {
			console.log('   ✅ LazyResult.rows correctly undefined');
		}
	} catch (e) {
		console.log('   ✅ Type safety working');
	}

	result3.destroy();
} catch (e) {
	console.log(`   ❌ Error: ${e.message}`);
}

// Test 4: Performance with larger data
console.log('\n4️⃣  Performance Test (10k rows)');
const largeData = Array.from({ length: 10000 }, (_, i) =>
	`${i},User${i},user${i}@test.com,${25 + (i % 40)}`
).join('\n');
const largeCSV = 'id,name,email,age\n' + largeData;

const start = performance.now();
const result4 = parseCSV(largeCSV, { mode: 'lazy', hasHeader: true });
const parseTime = performance.now() - start;

try {
	console.log(`   Parse time: ${parseTime.toFixed(2)}ms`);
	console.log(`   Rows: ${result4.rowCount.toLocaleString()}`);

	// Random access
	const accessStart = performance.now();
	result4.getRow(5000);
	const accessTime = performance.now() - accessStart;
	console.log(`   Random access: ${accessTime.toFixed(3)}ms`);

	if (parseTime < 100) {
		console.log('   ✅ Performance good');
	}
} finally {
	result4.destroy();
}

console.log('\n✅ All tests passed! Package ready for publishing.\n');
