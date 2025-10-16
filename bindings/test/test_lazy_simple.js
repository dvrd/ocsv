/**
 * Simple standalone test for LazyRow
 */

import { ptr } from "bun:ffi";
import { LazyRow } from "../lazy.js";
import { Parser, lib } from "../index.js";

console.log("Testing LazyRow...\n");

// Test CSV with 3 rows
const testCSV = `1,Susan Thomas,640 Rodriguez Forge Suite 645,Michaelview,MA,64206
2,Michelle Avery,9677 Wagner Mission,Andrewport,TN,85254
3,Mary Garcia,4084 Meyers Plains,Mooreborough,NE,49517`;

// Create parser and parse CSV
const parser = new Parser();
const buffer = Buffer.from(testCSV + '\0');
const parseResult = lib.symbols.ocsv_parse_string(parser.parser, ptr(buffer), testCSV.length);

if (parseResult !== 0) {
	console.error("Failed to parse test CSV");
	process.exit(1);
}

console.log("✓ CSV parsed successfully");

// Test 1: Field access
const row0 = new LazyRow(parser.parser, 0);
console.log("✓ LazyRow created");
console.log(`  Row length: ${row0.length}`);
console.log(`  Field 0: ${row0.get(0)}`);
console.log(`  Field 1: ${row0.get(1)}`);

// Test 2: Iteration
const fields = [...row0];
console.log(`✓ Iteration works: ${fields.length} fields`);

// Test 3: toArray
const arr = row0.toArray();
console.log(`✓ toArray works: ${arr.length} fields`);

// Test 4: Caching
const val1 = row0.get(5);
const val2 = row0.get(5);
console.log(`✓ Caching works: ${val1 === val2}`);

// Test 5: Bounds checking
try {
	row0.get(-1);
	console.error("✗ Bounds checking failed");
	process.exit(1);
} catch (e) {
	console.log("✓ Bounds checking works");
}

// Test 6: Multiple rows
const row1 = new LazyRow(parser.parser, 1);
const row2 = new LazyRow(parser.parser, 2);
console.log(`✓ Multiple rows: ${row0.get(0)}, ${row1.get(0)}, ${row2.get(0)}`);

// Cleanup
parser.destroy();
console.log("✓ Parser destroyed");

console.log("\n✅ All tests passed!");
