#!/usr/bin/env bun
/**
 * Large CSV Parsing Test
 *
 * Tests OCSV parser performance with large datasets (10,000+ rows)
 */

import { dlopen, FFIType, suffix } from "bun:ffi";
import { readFileSync, existsSync } from "fs";

// Load the OCSV library
const lib = dlopen(`../libcsv.${suffix}`, {
  ocsv_parser_create: {
    returns: FFIType.ptr,
  },
  ocsv_parser_destroy: {
    args: [FFIType.ptr],
  },
  ocsv_parse_string: {
    args: [FFIType.ptr, FFIType.cstring, FFIType.i32],
    returns: FFIType.i32,
  },
  ocsv_get_row_count: {
    args: [FFIType.ptr],
    returns: FFIType.i32,
  },
  ocsv_get_field_count: {
    args: [FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
});

console.log("🚀 OCSV - Large CSV Performance Test\n");
console.log("─".repeat(60));

// Check if large data file exists
if (!existsSync("./large_data.csv")) {
  console.log("❌ large_data.csv not found!");
  console.log("\n💡 Generate it first:");
  console.log("   bun run generate_large_data.ts");
  process.exit(1);
}

// Read the CSV file
console.log("📖 Reading large_data.csv...");
const readStart = performance.now();
const csvData = readFileSync("./large_data.csv", "utf-8");
const readEnd = performance.now();

const fileSizeBytes = Buffer.byteLength(csvData, 'utf-8');
const fileSizeMB = (fileSizeBytes / (1024 * 1024)).toFixed(2);

console.log(`   File size: ${fileSizeMB} MB`);
console.log(`   Read time: ${(readEnd - readStart).toFixed(2)}ms`);
console.log("─".repeat(60));

// Parse the CSV
console.log("\n⚡ Parsing CSV...");
const parser = lib.symbols.ocsv_parser_create();

try {
  const buffer = Buffer.from(csvData);

  const parseStart = performance.now();
  const result = lib.symbols.ocsv_parse_string(parser, buffer, buffer.length);
  const parseEnd = performance.now();

  if (result !== 0) {
    throw new Error("Failed to parse CSV");
  }

  const rowCount = lib.symbols.ocsv_get_row_count(parser);
  const parseTime = parseEnd - parseStart;

  console.log("✅ Parsing complete!");
  console.log("─".repeat(60));

  // Statistics
  console.log("\n📊 Results:");
  console.log(`   Total rows: ${rowCount.toLocaleString()}`);
  console.log(`   Data rows: ${(rowCount - 1).toLocaleString()} (excluding header)`);
  console.log(`   Parse time: ${parseTime.toFixed(2)}ms`);
  console.log(`   Throughput: ${(fileSizeBytes / (1024 * 1024) / (parseTime / 1000)).toFixed(2)} MB/s`);
  console.log(`   Rows/sec: ${Math.floor((rowCount / (parseTime / 1000))).toLocaleString()}`);

  // Verify row structure
  console.log("\n🔍 Row Structure Verification:");
  const sampleRows = [0, 1, 2, Math.floor(rowCount / 2), rowCount - 1];
  for (const rowIdx of sampleRows) {
    if (rowIdx < rowCount) {
      const fieldCount = lib.symbols.ocsv_get_field_count(parser, rowIdx);
      const rowType = rowIdx === 0 ? "Header" : `Row ${rowIdx}`;
      console.log(`   ${rowType}: ${fieldCount} fields`);
    }
  }

  // Memory usage (approximate)
  console.log("\n💾 Memory:");
  console.log(`   File size: ${fileSizeMB} MB`);
  console.log(`   Rows parsed: ${rowCount.toLocaleString()}`);

  // Benchmark comparison
  console.log("\n📈 Performance:");
  const bytesPerRow = fileSizeBytes / rowCount;
  console.log(`   Bytes/row: ${bytesPerRow.toFixed(2)}`);
  console.log(`   μs/row: ${((parseTime * 1000) / rowCount).toFixed(2)}`);

  console.log("\n✅ Test complete!");
  console.log("─".repeat(60));

} catch (error) {
  console.error("❌ Error:", error);
  process.exit(1);
} finally {
  lib.symbols.ocsv_parser_destroy(parser);
}
