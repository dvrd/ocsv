#!/usr/bin/env bun
/**
 * Large CSV Parsing Test
 *
 * Tests OCSV parser performance with large datasets (10K to 10M+ rows)
 *
 * Usage:
 *   bun run test_large_data.ts [file]
 *
 * Examples:
 *   bun run test_large_data.ts                # Test ./large_data.csv (default)
 *   bun run test_large_data.ts huge.csv       # Test custom file
 */

import { dlopen, FFIType, suffix } from "bun:ffi";
import { readFileSync, existsSync, statSync } from "fs";

// Parse command line arguments
const args = process.argv.slice(2);
const CSV_FILE = args[0] || "./large_data.csv";

// Load the OCSV library
const lib = dlopen(`../libocsv.${suffix}`, {
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
  ocsv_get_field: {
    args: [FFIType.ptr, FFIType.i32, FFIType.i32],
    returns: FFIType.cstring,
  },
});

console.log("🚀 OCSV - Large CSV Performance Test\n");
console.log("─".repeat(60));

// Check if file exists
if (!existsSync(CSV_FILE)) {
  console.log(`❌ ${CSV_FILE} not found!`);
  console.log("\n💡 Generate test data first:");
  console.log("   bun run generate_large_data.ts 10000          # 10K rows");
  console.log("   bun run generate_large_data.ts 100000         # 100K rows");
  console.log("   bun run generate_large_data.ts 1000000        # 1M rows");
  console.log("   bun run generate_large_data.ts 10000000       # 10M rows");
  process.exit(1);
}

// Get file info
const fileStats = statSync(CSV_FILE);
const fileSizeBytes = fileStats.size;
const fileSizeMB = (fileSizeBytes / (1024 * 1024)).toFixed(2);
const fileSizeGB = (fileSizeBytes / (1024 * 1024 * 1024)).toFixed(2);

console.log(`📄 File: ${CSV_FILE}`);
console.log(`   Size: ${fileSizeMB} MB${parseFloat(fileSizeGB) >= 0.1 ? ` (${fileSizeGB} GB)` : ''}`);
console.log(`   Bytes: ${fileSizeBytes.toLocaleString()}`);
console.log("─".repeat(60));

// Read the CSV file
console.log("\n📖 Reading file into memory...");
const readStart = performance.now();
const csvData = readFileSync(CSV_FILE, "utf-8");
const readEnd = performance.now();
const readTime = readEnd - readStart;

console.log(`   Read time: ${readTime.toFixed(2)}ms (${(readTime / 1000).toFixed(2)}s)`);
console.log(`   Read speed: ${(fileSizeBytes / (1024 * 1024) / (readTime / 1000)).toFixed(2)} MB/s`);
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
  const parseTimeSeconds = parseTime / 1000;

  console.log("✅ Parsing complete!");
  console.log("─".repeat(60));

  // Statistics
  console.log("\n📊 Parsing Results:");
  console.log(`   Total rows: ${rowCount.toLocaleString()} (including header)`);
  console.log(`   Data rows: ${(rowCount - 1).toLocaleString()} (excluding header)`);
  console.log(`   Parse time: ${parseTime.toFixed(2)}ms (${parseTimeSeconds.toFixed(2)}s)`);

  const throughputMBps = fileSizeBytes / (1024 * 1024) / parseTimeSeconds;
  const rowsPerSec = Math.floor(rowCount / parseTimeSeconds);
  console.log(`   Throughput: ${throughputMBps.toFixed(2)} MB/s`);
  console.log(`   Rows/sec: ${rowsPerSec.toLocaleString()}`);

  // Verify row structure
  console.log("\n🔍 Data Validation:");
  const sampleRows = [0, 1, 2, Math.floor(rowCount / 2), rowCount - 1];
  for (const rowIdx of sampleRows) {
    if (rowIdx < rowCount) {
      const fieldCount = lib.symbols.ocsv_get_field_count(parser, rowIdx);
      const rowType = rowIdx === 0 ? "Header" : `Row ${rowIdx}`;
      console.log(`   ${rowType}: ${fieldCount} fields`);
    }
  }

  // Sample some actual data
  console.log("\n📝 Sample Data:");
  if (rowCount > 1) {
    // Show first data row
    const row1FieldCount = lib.symbols.ocsv_get_field_count(parser, 1);
    const row1Fields = [];
    for (let i = 0; i < Math.min(5, row1FieldCount); i++) {
      const field = lib.symbols.ocsv_get_field(parser, 1, i);
      row1Fields.push(field);
    }
    console.log(`   First row: [${row1Fields.join(", ")}${row1FieldCount > 5 ? ", ..." : ""}]`);

    // Show middle row
    const midRow = Math.floor(rowCount / 2);
    const midFieldCount = lib.symbols.ocsv_get_field_count(parser, midRow);
    const midFields = [];
    for (let i = 0; i < Math.min(5, midFieldCount); i++) {
      const field = lib.symbols.ocsv_get_field(parser, midRow, i);
      midFields.push(field);
    }
    console.log(`   Middle row: [${midFields.join(", ")}${midFieldCount > 5 ? ", ..." : ""}]`);
  }

  // Performance metrics
  console.log("\n📈 Performance Metrics:");
  const bytesPerRow = fileSizeBytes / rowCount;
  const usPerRow = (parseTime * 1000) / rowCount;
  const nsPerRow = (parseTime * 1000000) / rowCount;
  console.log(`   Bytes/row: ${bytesPerRow.toFixed(2)}`);
  console.log(`   Time/row: ${usPerRow.toFixed(2)} μs (${nsPerRow.toFixed(0)} ns)`);

  // Total time including I/O
  const totalTime = readTime + parseTime;
  const totalTimeSeconds = totalTime / 1000;
  console.log("\n⏱️  Total Time (I/O + Parse):");
  console.log(`   Read: ${readTime.toFixed(2)}ms (${((readTime / totalTime) * 100).toFixed(1)}%)`);
  console.log(`   Parse: ${parseTime.toFixed(2)}ms (${((parseTime / totalTime) * 100).toFixed(1)}%)`);
  console.log(`   Total: ${totalTime.toFixed(2)}ms (${totalTimeSeconds.toFixed(2)}s)`);
  console.log(`   Overall: ${(fileSizeBytes / (1024 * 1024) / totalTimeSeconds).toFixed(2)} MB/s`);

  // Comparison with baseline
  console.log("\n🎯 Performance Rating:");
  const baseline = 61.84; // MB/s baseline from project stats
  const vsBaseline = ((throughputMBps / baseline) * 100).toFixed(1);
  if (throughputMBps >= baseline) {
    console.log(`   ✅ ${throughputMBps.toFixed(2)} MB/s (${vsBaseline}% of baseline)`);
  } else {
    console.log(`   ⚠️  ${throughputMBps.toFixed(2)} MB/s (${vsBaseline}% of baseline)`);
  }

  console.log("\n✅ Test complete!");
  console.log("─".repeat(60));

} catch (error) {
  console.error("❌ Error:", error);
  process.exit(1);
} finally {
  lib.symbols.ocsv_parser_destroy(parser);
}
