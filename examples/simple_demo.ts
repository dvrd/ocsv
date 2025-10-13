#!/usr/bin/env bun
/**
 * Simple OCSV Demo with Bun FFI
 *
 * This example demonstrates basic CSV parsing verification.
 * Note: The current FFI API is optimized for Odin usage.
 * For full field access from TypeScript, consider using the Odin CLI
 * or contributing enhanced FFI bindings.
 */

import { dlopen, FFIType, suffix } from "bun:ffi";
import { readFileSync } from "fs";

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

console.log("🚀 OCSV - Simple CSV Parser Demo\n");

// Read the sample CSV file
const csvData = readFileSync("./sample_data.csv", "utf-8");
console.log("📄 Input CSV (first 5 lines):");
const lines = csvData.split('\n').slice(0, 5);
lines.forEach((line, i) => console.log(`  ${i + 1}: ${line}`));
console.log("  ...");
console.log("─".repeat(60));

// Parse the CSV
const parser = lib.symbols.ocsv_parser_create();

try {
  const startTime = performance.now();
  const buffer = Buffer.from(csvData);
  const result = lib.symbols.ocsv_parse_string(parser, buffer, buffer.length);
  const endTime = performance.now();

  if (result !== 0) {
    throw new Error("Failed to parse CSV");
  }

  // Get statistics
  const rowCount = lib.symbols.ocsv_get_row_count(parser);

  console.log("\n✅ CSV Parsed Successfully!");
  console.log("─".repeat(60));
  console.log(`Total rows: ${rowCount}`);
  console.log(`Parsing time: ${(endTime - startTime).toFixed(3)}ms`);

  // Show field counts for each row
  console.log("\n📊 Row Structure:");
  for (let i = 0; i < Math.min(rowCount, 5); i++) {
    const fieldCount = lib.symbols.ocsv_get_field_count(parser, i);
    console.log(`  Row ${i + 1}: ${fieldCount} fields`);
  }
  if (rowCount > 5) {
    console.log(`  ... (${rowCount - 5} more rows)`);
  }

  console.log("\n💡 Note:");
  console.log("  The current FFI bindings provide parsing verification.");
  console.log("  For full data access, use:");
  console.log("    • Odin programs (see tests/ for examples)");
  console.log("    • Enhanced FFI bindings (contribution welcome!)");
  console.log("    • Command-line tools built with Odin");

  console.log("\n🎯 What This Demo Shows:");
  console.log("  ✓ OCSV library loads correctly");
  console.log("  ✓ Parser creation and cleanup");
  console.log("  ✓ CSV parsing succeeds");
  console.log("  ✓ Row and field count extraction");
  console.log("  ✓ Fast parsing performance");

} finally {
  lib.symbols.ocsv_parser_destroy(parser);
}

console.log("\n✅ Demo complete!");
