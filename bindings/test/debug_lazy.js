/**
 * Debug script for lazy mode
 */

import { Parser, lib } from "../index.js";
import { ptr } from "bun:ffi";
import { LazyRow } from "../lazy.js";

console.log("Debug: Testing LazyRow directly\n");

// Create parser
const parser = new Parser();
const csv = "name,age\nAlice,30";
const buffer = Buffer.from(csv + '\0');

console.log("1. Parsing CSV...");
const parseResult = lib.symbols.ocsv_parse_string(parser.parser, ptr(buffer), csv.length);
console.log(`   Parse result: ${parseResult}`);

console.log("\n2. Getting row count...");
const rowCount = lib.symbols.ocsv_get_row_count(parser.parser);
console.log(`   Row count: ${rowCount}`);

console.log("\n3. Getting field count for row 0...");
const fieldCount0 = lib.symbols.ocsv_get_field_count(parser.parser, 0);
console.log(`   Field count: ${fieldCount0}`);

console.log("\n4. Getting field 0,0...");
const field00 = lib.symbols.ocsv_get_field(parser.parser, 0, 0);
console.log(`   Field value: "${field00}"`);

console.log("\n5. Getting field 0,1...");
const field01 = lib.symbols.ocsv_get_field(parser.parser, 0, 1);
console.log(`   Field value: "${field01}"`);

console.log("\n6. Creating LazyRow for row 0...");
const row0 = new LazyRow(parser.parser, 0);
console.log(`   Row length: ${row0.length}`);

console.log("\n7. Getting field with LazyRow.get(0)...");
const val0 = row0.get(0);
console.log(`   Field value: "${val0}"`);

console.log("\n8. Getting field with LazyRow.get(1)...");
const val1 = row0.get(1);
console.log(`   Field value: "${val1}"`);

console.log("\n9. Converting row to array...");
const arr = row0.toArray();
console.log(`   Array: [${arr.join(', ')}]`);

console.log("\n✅ Debug completed");

parser.destroy();
