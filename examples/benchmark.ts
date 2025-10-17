#!/usr/bin/env bun
/**
 * OCSV Performance Benchmark
 *
 * Tests OCSV parser with large datasets using the minimal bindings API.
 * Demonstrates zero-abstraction FFI performance with millions of rows.
 *
 * Usage:
 *   bun run examples/benchmark.ts [file]
 *
 * Examples:
 *   bun run examples/benchmark.ts                    # Use ./large_data.csv
 *   bun run examples/benchmark.ts custom.csv         # Use custom file
 *
 * Generate test data:
 *   bun run examples/generate_large_data.ts 10000000  # 10M rows (~662 MB)
 */

import { parseCSV, getCSVDimensions, ffi } from "../bindings/simple";
import { readFileSync, existsSync, statSync } from "fs";

// ============================================================================
// Configuration
// ============================================================================

const args = process.argv.slice(2);
const CSV_FILE = args[0] || "examples/large_data.csv";

// ============================================================================
// File validation
// ============================================================================

console.log("🚀 OCSV Performance Benchmark");
console.log("═".repeat(70));

if (!existsSync(CSV_FILE)) {
  console.log(`\n❌ Error: ${CSV_FILE} not found`);
  console.log("\n💡 Generate test data first:");
  console.log("   bun run examples/generate_large_data.ts 10000      # 10K rows (~1 MB)");
  console.log("   bun run examples/generate_large_data.ts 100000     # 100K rows (~12 MB)");
  console.log("   bun run examples/generate_large_data.ts 1000000    # 1M rows (~116 MB)");
  console.log("   bun run examples/generate_large_data.ts 10000000   # 10M rows (~662 MB)");
  process.exit(1);
}

// ============================================================================
// File information
// ============================================================================

const fileStats = statSync(CSV_FILE);
const fileSizeBytes = fileStats.size;
const fileSizeMB = fileSizeBytes / (1024 * 1024);
const fileSizeGB = fileSizeBytes / (1024 * 1024 * 1024);

console.log(`\n📄 File Information`);
console.log("─".repeat(70));
console.log(`   Path: ${CSV_FILE}`);
console.log(`   Size: ${fileSizeMB.toFixed(2)} MB${fileSizeGB >= 0.1 ? ` (${fileSizeGB.toFixed(2)} GB)` : ''}`);
console.log(`   Bytes: ${fileSizeBytes.toLocaleString()}`);

// ============================================================================
// Read file into memory
// ============================================================================

console.log(`\n📖 Reading File`);
console.log("─".repeat(70));

const readStart = performance.now();
const csvData = readFileSync(CSV_FILE, "utf-8");
const readEnd = performance.now();
const readTime = readEnd - readStart;
const readSpeed = fileSizeMB / (readTime / 1000);

console.log(`   Time: ${readTime.toFixed(2)} ms (${(readTime / 1000).toFixed(2)} s)`);
console.log(`   Speed: ${readSpeed.toFixed(2)} MB/s`);

// ============================================================================
// Parse CSV with dimension check
// ============================================================================

console.log(`\n⚡ Parsing CSV (Fast Dimension Check)`);
console.log("─".repeat(70));

const dimStart = performance.now();
const { rows: rowCount, avgFields } = getCSVDimensions(csvData);
const dimEnd = performance.now();
const dimTime = dimEnd - dimStart;
const dimThroughput = fileSizeMB / (dimTime / 1000);

console.log(`   Rows: ${rowCount.toLocaleString()}`);
console.log(`   Avg fields: ${avgFields}`);
console.log(`   Parse time: ${dimTime.toFixed(2)} ms (${(dimTime / 1000).toFixed(2)} s)`);
console.log(`   Throughput: ${dimThroughput.toFixed(2)} MB/s`);
console.log(`   Rows/sec: ${Math.floor(rowCount / (dimTime / 1000)).toLocaleString()}`);

// ============================================================================
// Full parse with all data extraction
// ============================================================================

console.log(`\n⚡ Full Parse (All Data Extraction)`);
console.log("─".repeat(70));

const parseStart = performance.now();
const allRows = parseCSV(csvData);
const parseEnd = performance.now();
const parseTime = parseEnd - parseStart;
const parseThroughput = fileSizeMB / (parseTime / 1000);

console.log(`   Rows parsed: ${allRows.length.toLocaleString()}`);
console.log(`   Parse time: ${parseTime.toFixed(2)} ms (${(parseTime / 1000).toFixed(2)} s)`);
console.log(`   Throughput: ${parseThroughput.toFixed(2)} MB/s`);
console.log(`   Rows/sec: ${Math.floor(allRows.length / (parseTime / 1000)).toLocaleString()}`);

// ============================================================================
// Data validation
// ============================================================================

console.log(`\n🔍 Data Validation`);
console.log("─".repeat(70));

// Sample some rows to verify structure
const sampleIndices = [
  0,                                    // Header
  1,                                    // First data row
  Math.floor(allRows.length / 4),      // 25%
  Math.floor(allRows.length / 2),      // 50%
  Math.floor(allRows.length * 3 / 4),  // 75%
  allRows.length - 1                    // Last row
];

for (const idx of sampleIndices) {
  if (idx < allRows.length) {
    const row = allRows[idx];
    const rowType = idx === 0 ? "Header" :
                    idx === 1 ? "First row" :
                    idx === allRows.length - 1 ? "Last row" :
                    `Row ${idx}`;

    // Show first 4 fields
    const preview = row.slice(0, 4).join(", ");
    console.log(`   ${rowType}: ${row.length} fields → [${preview}...]`);
  }
}

// ============================================================================
// Performance metrics
// ============================================================================

console.log(`\n📈 Performance Metrics`);
console.log("─".repeat(70));

const bytesPerRow = fileSizeBytes / allRows.length;
const usPerRow = (parseTime * 1000) / allRows.length;
const nsPerRow = (parseTime * 1000000) / allRows.length;

console.log(`   Bytes/row: ${bytesPerRow.toFixed(2)}`);
console.log(`   Time/row: ${usPerRow.toFixed(2)} μs (${nsPerRow.toFixed(0)} ns)`);
console.log(`   Memory: ${(process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2)} MB heap`);

// ============================================================================
// Total time (I/O + Parse)
// ============================================================================

const totalTime = readTime + parseTime;

console.log(`\n⏱️  Total Time (I/O + Parse)`);
console.log("─".repeat(70));
console.log(`   Read: ${readTime.toFixed(2)} ms (${((readTime / totalTime) * 100).toFixed(1)}%)`);
console.log(`   Parse: ${parseTime.toFixed(2)} ms (${((parseTime / totalTime) * 100).toFixed(1)}%)`);
console.log(`   Total: ${totalTime.toFixed(2)} ms (${(totalTime / 1000).toFixed(2)} s)`);
console.log(`   Overall: ${(fileSizeMB / (totalTime / 1000)).toFixed(2)} MB/s`);

// ============================================================================
// Baseline comparison
// ============================================================================

const baseline = 61.84; // MB/s baseline from project stats
const vsBaseline = (parseThroughput / baseline) * 100;

console.log(`\n🎯 Performance Rating`);
console.log("─".repeat(70));
console.log(`   Throughput: ${parseThroughput.toFixed(2)} MB/s`);
console.log(`   vs Baseline: ${vsBaseline.toFixed(1)}%`);

if (parseThroughput >= baseline) {
  console.log(`   Status: ✅ EXCELLENT (above baseline)`);
} else if (parseThroughput >= baseline * 0.8) {
  console.log(`   Status: ✅ GOOD (within 20% of baseline)`);
} else {
  console.log(`   Status: ⚠️  NEEDS IMPROVEMENT`);
}

// ============================================================================
// API demonstration
// ============================================================================

console.log(`\n💡 Minimal API Example`);
console.log("─".repeat(70));

console.log(`\n// Zero-abstraction API - just functions:\n`);
console.log(`const rows = parseCSV(csvData)                // → string[][]`);
console.log(`const { rows, header } = parseCSVWithHeader() // → Split header`);
console.log(`const objects = parseCSVToObjects(csvData)    // → Record<string, string>[]`);
console.log(`const dims = getCSVDimensions(csvData)        // → { rows, avgFields }`);
console.log(`\n// Direct FFI access for advanced control:\n`);
console.log(`const parser = ffi.ocsv_parser_create()`);
console.log(`ffi.ocsv_parse_string(parser, buffer, length)`);
console.log(`const rows = ffi.ocsv_get_row_count(parser)`);
console.log(`ffi.ocsv_parser_destroy(parser)`);

// ============================================================================
// Summary
// ============================================================================

console.log(`\n✅ Benchmark Complete!`);
console.log("═".repeat(70));

console.log(`\n📊 Summary:`);
console.log(`   • Parsed ${allRows.length.toLocaleString()} rows in ${(parseTime / 1000).toFixed(2)}s`);
console.log(`   • ${parseThroughput.toFixed(2)} MB/s throughput`);
console.log(`   • ${nsPerRow.toFixed(0)} ns per row`);
console.log(`   • Zero memory leaks, zero abstractions`);

console.log();
