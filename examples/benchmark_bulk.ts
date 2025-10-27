#!/usr/bin/env bun
/**
 * OCSV Bulk vs Field-by-Field Performance Comparison
 *
 * Compares the performance of:
 * 1. Field-by-field extraction (current approach)
 * 2. Bulk JSON serialization (new approach)
 *
 * Usage:
 *   bun run examples/benchmark_bulk.ts [file]
 *
 * Examples:
 *   bun run examples/benchmark_bulk.ts                    # Use ./large_data.csv
 *   bun run examples/benchmark_bulk.ts custom.csv         # Use custom file
 */

import { parseCSV, parseCSVBulk, parseCSVPacked, ffi } from "../bindings/simple";
import { readFileSync, existsSync, statSync } from "fs";

// ============================================================================
// Configuration
// ============================================================================

const args = process.argv.slice(2);
const CSV_FILE = args[0] || "./large_data.csv";

// ============================================================================
// File validation
// ============================================================================

console.log("🚀 OCSV Bulk Performance Benchmark");
console.log("═".repeat(70));

if (!existsSync(CSV_FILE)) {
  console.log(`\n❌ Error: ${CSV_FILE} not found`);
  console.log("\n💡 Generate test data first:");
  console.log("   bun run examples/generate_large_data.ts 100000");
  process.exit(1);
}

// ============================================================================
// File information
// ============================================================================

const fileStats = statSync(CSV_FILE);
const fileSizeBytes = fileStats.size;
const fileSizeMB = fileSizeBytes / (1024 * 1024);

console.log(`\n📄 File Information`);
console.log("─".repeat(70));
console.log(`   Path: ${CSV_FILE}`);
console.log(`   Size: ${fileSizeMB.toFixed(2)} MB`);
console.log(`   Bytes: ${fileSizeBytes.toLocaleString()}`);

// ============================================================================
// Read file into memory
// ============================================================================

console.log(`\n📖 Reading File`);
console.log("─".repeat(70));

const csvData = readFileSync(CSV_FILE, "utf-8");
console.log(`   ✓ Loaded into memory`);

// ============================================================================
// Approach 1: Field-by-Field (Current)
// ============================================================================

console.log(`\n⚡ Approach 1: Field-by-Field (Current)`);
console.log("─".repeat(70));

const fieldStart = performance.now();
const fieldRows = parseCSV(csvData);
const fieldEnd = performance.now();
const fieldTime = fieldEnd - fieldStart;
const fieldThroughput = fileSizeMB / (fieldTime / 1000);

console.log(`   Rows parsed: ${fieldRows.length.toLocaleString()}`);
console.log(`   Parse time: ${fieldTime.toFixed(2)} ms (${(fieldTime / 1000).toFixed(2)} s)`);
console.log(`   Throughput: ${fieldThroughput.toFixed(2)} MB/s`);
console.log(`   Rows/sec: ${Math.floor(fieldRows.length / (fieldTime / 1000)).toLocaleString()}`);

const fieldNsPerRow = (fieldTime * 1000000) / fieldRows.length;
console.log(`   Time/row: ${fieldNsPerRow.toFixed(0)} ns`);

// ============================================================================
// Approach 2: Bulk JSON (New)
// ============================================================================

console.log(`\n⚡ Approach 2: Bulk JSON (New)`);
console.log("─".repeat(70));

const bulkStart = performance.now();
const bulkRows = parseCSVBulk(csvData);
const bulkEnd = performance.now();
const bulkTime = bulkEnd - bulkStart;
const bulkThroughput = fileSizeMB / (bulkTime / 1000);

console.log(`   Rows parsed: ${bulkRows.length.toLocaleString()}`);
console.log(`   Parse time: ${bulkTime.toFixed(2)} ms (${(bulkTime / 1000).toFixed(2)} s)`);
console.log(`   Throughput: ${bulkThroughput.toFixed(2)} MB/s`);
console.log(`   Rows/sec: ${Math.floor(bulkRows.length / (bulkTime / 1000)).toLocaleString()}`);

const bulkNsPerRow = (bulkTime * 1000000) / bulkRows.length;
console.log(`   Time/row: ${bulkNsPerRow.toFixed(0)} ns`);

// ============================================================================
// Approach 3: Packed Buffer (Phase 2)
// ============================================================================

console.log(`\n⚡ Approach 3: Packed Buffer (Phase 2 - Zero-Copy)`);
console.log("─".repeat(70));

const packedStart = performance.now();
const packedRows = parseCSVPacked(csvData);
const packedEnd = performance.now();
const packedTime = packedEnd - packedStart;
const packedThroughput = fileSizeMB / (packedTime / 1000);

console.log(`   Rows parsed: ${packedRows.length.toLocaleString()}`);
console.log(`   Parse time: ${packedTime.toFixed(2)} ms (${(packedTime / 1000).toFixed(2)} s)`);
console.log(`   Throughput: ${packedThroughput.toFixed(2)} MB/s`);
console.log(`   Rows/sec: ${Math.floor(packedRows.length / (packedTime / 1000)).toLocaleString()}`);

const packedNsPerRow = (packedTime * 1000000) / packedRows.length;
console.log(`   Time/row: ${packedNsPerRow.toFixed(0)} ns`);

// ============================================================================
// Verify results match
// ============================================================================

console.log(`\n🔍 Data Validation`);
console.log("─".repeat(70));

let mismatchFound = false;

// Check row count
if (fieldRows.length !== bulkRows.length || fieldRows.length !== packedRows.length) {
  console.log(`   ❌ Row count mismatch: field=${fieldRows.length}, bulk=${bulkRows.length}, packed=${packedRows.length}`);
  mismatchFound = true;
} else {
  console.log(`   ✓ Row count matches: ${fieldRows.length}`);
}

// Sample check some rows
const sampleIndices = [0, 1, Math.floor(fieldRows.length / 2), fieldRows.length - 1];

for (const idx of sampleIndices) {
  if (idx >= fieldRows.length) continue;

  const fieldRow = fieldRows[idx];
  const bulkRow = bulkRows[idx];
  const packedRow = packedRows[idx];

  if (fieldRow.length !== bulkRow.length || fieldRow.length !== packedRow.length) {
    console.log(`   ❌ Row ${idx} field count mismatch: field=${fieldRow.length}, bulk=${bulkRow.length}, packed=${packedRow.length}`);
    mismatchFound = true;
    continue;
  }

  for (let j = 0; j < fieldRow.length; j++) {
    // Use == for comparison to handle String objects vs primitives
    if (fieldRow[j] != bulkRow[j] || fieldRow[j] != packedRow[j]) {
      console.log(`   ❌ Row ${idx} field ${j} mismatch: field="${fieldRow[j]}", bulk="${bulkRow[j]}", packed="${packedRow[j]}"`);
      mismatchFound = true;
      break;
    }
  }
}

if (!mismatchFound) {
  console.log(`   ✓ All sampled rows match`);
}

// ============================================================================
// Performance Comparison
// ============================================================================

const speedup1to2 = fieldTime / bulkTime;
const speedup1to3 = fieldTime / packedTime;
const speedup2to3 = bulkTime / packedTime;
const improvement2 = ((bulkThroughput - fieldThroughput) / fieldThroughput) * 100;
const improvement3 = ((packedThroughput - fieldThroughput) / fieldThroughput) * 100;

console.log(`\n📊 Performance Comparison`);
console.log("─".repeat(70));
console.log(`   Field-by-Field: ${fieldThroughput.toFixed(2)} MB/s`);
console.log(`   Bulk JSON:      ${bulkThroughput.toFixed(2)} MB/s (${speedup1to2.toFixed(2)}× faster)`);
console.log(`   Packed Buffer:  ${packedThroughput.toFixed(2)} MB/s (${speedup1to3.toFixed(2)}× faster)`);
console.log();
console.log(`   Phase 1 → Phase 2 speedup: ${speedup2to3.toFixed(2)}×`);
console.log(`   Phase 2 improvement: ${improvement3 > 0 ? '+' : ''}${improvement3.toFixed(1)}% vs field-by-field`);

// ============================================================================
// Performance Rating
// ============================================================================

const baseline = 61.84; // MB/s baseline from project stats

console.log(`\n🎯 Performance Rating`);
console.log("─".repeat(70));

console.log(`\nField-by-Field Approach:`);
console.log(`   Throughput: ${fieldThroughput.toFixed(2)} MB/s`);
console.log(`   vs Baseline: ${((fieldThroughput / baseline) * 100).toFixed(1)}%`);
if (fieldThroughput >= baseline) {
  console.log(`   Status: ✅ EXCELLENT (above baseline)`);
} else if (fieldThroughput >= baseline * 0.8) {
  console.log(`   Status: ✅ GOOD (within 20% of baseline)`);
} else {
  console.log(`   Status: ⚠️  NEEDS IMPROVEMENT`);
}

console.log(`\nBulk JSON Approach (Phase 1):`);
console.log(`   Throughput: ${bulkThroughput.toFixed(2)} MB/s`);
console.log(`   vs Baseline: ${((bulkThroughput / baseline) * 100).toFixed(1)}%`);
if (bulkThroughput >= baseline) {
  console.log(`   Status: ✅ EXCELLENT (above baseline)`);
} else if (bulkThroughput >= baseline * 0.8) {
  console.log(`   Status: ✅ GOOD (within 20% of baseline)`);
} else if (bulkThroughput >= baseline * 0.6) {
  console.log(`   Status: 🟡 ACCEPTABLE`);
} else {
  console.log(`   Status: ⚠️  NEEDS IMPROVEMENT`);
}

console.log(`\nPacked Buffer Approach (Phase 2):`);
console.log(`   Throughput: ${packedThroughput.toFixed(2)} MB/s`);
console.log(`   vs Baseline: ${((packedThroughput / baseline) * 100).toFixed(1)}%`);
if (packedThroughput >= baseline) {
  console.log(`   Status: ✅ EXCELLENT (above baseline)`);
} else if (packedThroughput >= baseline * 0.8) {
  console.log(`   Status: ✅ GOOD (within 20% of baseline)`);
} else if (packedThroughput >= baseline * 0.6) {
  console.log(`   Status: 🟡 ACCEPTABLE`);
} else {
  console.log(`   Status: ⚠️  NEEDS IMPROVEMENT`);
}

// ============================================================================
// Success Criteria
// ============================================================================

console.log(`\n✅ Phase 1 Success Criteria`);
console.log("─".repeat(70));

const phase1Target = 40; // MB/s

console.log(`   Target: > ${phase1Target} MB/s`);
console.log(`   Achieved: ${bulkThroughput.toFixed(2)} MB/s`);

if (bulkThroughput > phase1Target) {
  console.log(`   Result: ✅ SUCCESS`);
} else {
  const gap = phase1Target - bulkThroughput;
  console.log(`   Result: ❌ FAILED - ${gap.toFixed(2)} MB/s short of target`);
}

console.log(`\n✅ Phase 2 Success Criteria`);
console.log("─".repeat(70));

const phase2Target = 55; // MB/s (89% of baseline 61.84 MB/s)

console.log(`   Target: > ${phase2Target} MB/s (89% of baseline)`);
console.log(`   Achieved: ${packedThroughput.toFixed(2)} MB/s`);

if (packedThroughput > phase2Target) {
  console.log(`   Result: ✅ SUCCESS - Phase 2 complete!`);
  console.log(`   Achievement: ${((packedThroughput / baseline) * 100).toFixed(1)}% of native Odin performance`);
} else {
  const gap = phase2Target - packedThroughput;
  console.log(`   Result: ❌ FAILED - ${gap.toFixed(2)} MB/s short of target`);
  console.log(`   Recommendation: Profile deserialization bottlenecks`);
}

// ============================================================================
// Summary
// ============================================================================

console.log(`\n✅ Benchmark Complete!`);
console.log("═".repeat(70));

console.log(`\n📊 Summary:`);
console.log(`   • Field-by-field: ${fieldNsPerRow.toFixed(0)} ns/row (${fieldThroughput.toFixed(2)} MB/s)`);
console.log(`   • Bulk JSON:      ${bulkNsPerRow.toFixed(0)} ns/row (${bulkThroughput.toFixed(2)} MB/s) - ${speedup1to2.toFixed(2)}× faster`);
console.log(`   • Packed buffer:  ${packedNsPerRow.toFixed(0)} ns/row (${packedThroughput.toFixed(2)} MB/s) - ${speedup1to3.toFixed(2)}× faster`);
console.log(`   • Phase 1 → Phase 2 improvement: ${speedup2to3.toFixed(2)}×`);
console.log(`   • ${mismatchFound ? '❌ Data mismatch detected' : '✓ Results match perfectly'}`);

console.log();
