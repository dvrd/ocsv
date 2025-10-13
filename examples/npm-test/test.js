/**
 * OCSV npm package test
 *
 * This tests the npm package API
 */

import { parseCSV, parseCSVFile, Parser } from '../../bindings/index.js';

console.log('🧪 Testing OCSV npm package...\n');

// Test 1: Basic parsing
console.log('Test 1: Basic CSV parsing');
try {
	const result = parseCSV('name,age,city\nAlice,30,NYC\nBob,25,SF');
	console.log('✓ Parsed successfully');
	console.log('  Rows:', result.rows);
	console.log('  Row count:', result.rowCount);
} catch (error) {
	console.error('✗ Failed:', error.message);
}

console.log('\n---\n');

// Test 2: Parsing with headers
console.log('Test 2: CSV parsing with headers');
try {
	const result = parseCSV('name,age,city\nAlice,30,NYC\nBob,25,SF', { hasHeader: true });
	console.log('✓ Parsed successfully');
	console.log('  Headers:', result.headers);
	console.log('  Rows:', result.rows);
	console.log('  Row count:', result.rowCount);
} catch (error) {
	console.error('✗ Failed:', error.message);
}

console.log('\n---\n');

// Test 3: Complex CSV (quotes, commas)
console.log('Test 3: Complex CSV with quotes and embedded commas');
try {
	const complexCSV = `product,price,description
"Widget A",19.99,"A great product, with many features"
"Gadget B",29.99,"Essential gadget"`;

	const result = parseCSV(complexCSV, { hasHeader: true });
	console.log('✓ Parsed successfully');
	console.log('  Headers:', result.headers);
	console.log('  Rows:');
	result.rows.forEach((row, i) => {
		console.log(`    ${i + 1}:`, row);
	});
} catch (error) {
	console.error('✗ Failed:', error.message);
}

console.log('\n---\n');

// Test 4: Empty fields
console.log('Test 4: CSV with empty fields');
try {
	const result = parseCSV('a,,c\n,b,\n1,2,3');
	console.log('✓ Parsed successfully');
	console.log('  Rows:', result.rows);
} catch (error) {
	console.error('✗ Failed:', error.message);
}

console.log('\n---\n');

// Test 5: Manual parser management
console.log('Test 5: Manual parser management');
try {
	const parser = new Parser();
	try {
		const result = parser.parse('x,y,z\n1,2,3\n4,5,6');
		console.log('✓ Parsed successfully');
		console.log('  Rows:', result.rows);
		console.log('  Row count:', result.rowCount);
	} finally {
		parser.destroy();
		console.log('  Parser destroyed');
	}
} catch (error) {
	console.error('✗ Failed:', error.message);
}

console.log('\n---\n');

// Test 6: Create and parse a test file
console.log('Test 6: Parse CSV from file');
try {
	// Create test CSV file
	const fs = require('fs');
	const testData = `name,age,department,salary
John Doe,35,Engineering,95000
Jane Smith,28,Marketing,75000
Bob Johnson,42,Sales,85000`;

	fs.writeFileSync('test-data.csv', testData);
	console.log('  Created test-data.csv');

	const result = await parseCSVFile('test-data.csv', { hasHeader: true });
	console.log('✓ Parsed successfully from file');
	console.log('  Headers:', result.headers);
	console.log('  Row count:', result.rowCount);
	console.log('  Rows:');
	result.rows.forEach((row, i) => {
		console.log(`    ${i + 1}:`, row);
	});

	// Cleanup
	fs.unlinkSync('test-data.csv');
	console.log('  Cleaned up test file');
} catch (error) {
	console.error('✗ Failed:', error.message);
}

console.log('\n✅ All tests completed!');
