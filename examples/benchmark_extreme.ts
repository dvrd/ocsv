#!/usr/bin/env bun
/**
 * Extreme Dataset Benchmark
 *
 * Comprehensive benchmarking suite for OCSV parser with extreme datasets (10M+ rows)
 * Tests parser performance, memory efficiency, and scalability
 *
 * Usage:
 *   bun run benchmark_extreme.ts
 *
 * This will run a suite of benchmarks with progressively larger datasets:
 * - 100K rows   (~14 MB)
 * - 1M rows     (~140 MB)
 * - 5M rows     (~700 MB)
 * - 10M rows    (~1.4 GB)
 */

import { dlopen, FFIType, suffix } from "bun:ffi";
import { writeFileSync, existsSync, statSync, unlinkSync } from "fs";

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
});

interface BenchmarkResult {
  rows: number;
  fileSizeMB: number;
  generateTimeMs: number;
  readTimeMs: number;
  parseTimeMs: number;
  totalTimeMs: number;
  throughputMBps: number;
  rowsPerSec: number;
}

/**
 * Generate a CSV file with specified number of rows
 */
function generateCSV(rows: number, filename: string): BenchmarkResult {
  console.log(`\n📊 Generating ${rows.toLocaleString()} rows...`);
  const genStart = performance.now();

  // Generate CSV data in chunks to avoid memory issues
  const CHUNK_SIZE = 50000;
  let csv = "id,name,email,age,city,department,salary\n";

  // Write header
  writeFileSync(filename, csv);
  csv = "";

  const names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry"];
  const cities = ["NYC", "LA", "Chicago", "Houston", "Phoenix", "Philly", "Austin", "Dallas"];
  const depts = ["Eng", "Sales", "Marketing", "HR", "Finance", "Ops", "IT"];

  for (let i = 1; i <= rows; i++) {
    const name = names[i % names.length];
    const email = `${name.toLowerCase()}${i}@test.com`;
    const age = 25 + (i % 40);
    const city = cities[i % cities.length];
    const dept = depts[i % depts.length];
    const salary = 50000 + (i % 100000);

    csv += `${i},${name},${email},${age},${city},${dept},${salary}\n`;

    if (i % CHUNK_SIZE === 0) {
      const fs = await import("fs");
      fs.appendFileSync(filename, csv);
      csv = "";
      process.stdout.write(`\r   Progress: ${((i / rows) * 100).toFixed(1)}%`);
    }
  }

  // Write remaining
  if (csv.length > 0) {
    const fs = await import("fs");
    fs.appendFileSync(filename, csv);
  }

  const genEnd = performance.now();
  const generateTimeMs = genEnd - genStart;

  const stats = statSync(filename);
  const fileSizeMB = stats.size / (1024 * 1024);

  process.stdout.write(`\r   ✅ Generated ${fileSizeMB.toFixed(2)} MB in ${generateTimeMs.toFixed(0)}ms\n`);

  return {
    rows,
    fileSizeMB,
    generateTimeMs,
    readTimeMs: 0,
    parseTimeMs: 0,
    totalTimeMs: 0,
    throughputMBps: 0,
    rowsPerSec: 0,
  };
}

/**
 * Benchmark CSV parsing
 */
function benchmarkParse(filename: string, result: BenchmarkResult): BenchmarkResult {
  console.log(`⚡ Parsing...`);

  // Read file
  const readStart = performance.now();
  const csvData = Bun.file(filename);
  const text = await csvData.text();
  const readEnd = performance.now();
  result.readTimeMs = readEnd - readStart;

  console.log(`   Read: ${result.readTimeMs.toFixed(2)}ms`);

  // Parse
  const parser = lib.symbols.ocsv_parser_create();

  try {
    const buffer = Buffer.from(text);
    const parseStart = performance.now();
    const parseResult = lib.symbols.ocsv_parse_string(parser, buffer, buffer.length);
    const parseEnd = performance.now();
    result.parseTimeMs = parseEnd - parseStart;

    if (parseResult !== 0) {
      throw new Error("Parse failed");
    }

    const rowCount = lib.symbols.ocsv_get_row_count(parser);
    result.rows = rowCount - 1; // Exclude header

    // Calculate metrics
    result.totalTimeMs = result.readTimeMs + result.parseTimeMs;
    result.throughputMBps = result.fileSizeMB / (result.parseTimeMs / 1000);
    result.rowsPerSec = Math.floor((rowCount - 1) / (result.parseTimeMs / 1000));

    console.log(`   Parse: ${result.parseTimeMs.toFixed(2)}ms`);
    console.log(`   ✅ ${result.throughputMBps.toFixed(2)} MB/s, ${result.rowsPerSec.toLocaleString()} rows/sec`);

    return result;
  } finally {
    lib.symbols.ocsv_parser_destroy(parser);
  }
}

/**
 * Run benchmark suite
 */
async function runBenchmarkSuite() {
  console.log("🚀 OCSV - Extreme Dataset Benchmark Suite\n");
  console.log("═".repeat(70));

  const testSizes = [
    { rows: 100000, name: "100K" },
    { rows: 1000000, name: "1M" },
    { rows: 5000000, name: "5M" },
    { rows: 10000000, name: "10M" },
  ];

  const results: BenchmarkResult[] = [];

  for (const test of testSizes) {
    console.log(`\n${"═".repeat(70)}`);
    console.log(`📈 Benchmark: ${test.name} rows (${test.rows.toLocaleString()})`);
    console.log("─".repeat(70));

    const filename = `./benchmark_${test.name.toLowerCase()}.csv`;

    try {
      // Generate
      let result = generateCSV(test.rows, filename);

      // Benchmark
      result = benchmarkParse(filename, result);

      results.push(result);

      // Cleanup
      if (existsSync(filename)) {
        unlinkSync(filename);
      }
    } catch (error) {
      console.error(`❌ Error in ${test.name} benchmark:`, error);
    }
  }

  // Summary
  console.log(`\n${"═".repeat(70)}`);
  console.log("📊 BENCHMARK SUMMARY");
  console.log("═".repeat(70));
  console.log();
  console.log("Size      Rows          File Size   Parse Time   Throughput    Rows/sec");
  console.log("─".repeat(70));

  for (const result of results) {
    const size = result.rows >= 1000000 ? `${(result.rows / 1000000).toFixed(0)}M` : `${(result.rows / 1000).toFixed(0)}K`;
    console.log(
      `${size.padEnd(9)} ${result.rows.toLocaleString().padEnd(13)} ${result.fileSizeMB.toFixed(2).padStart(7)} MB  ` +
      `${result.parseTimeMs.toFixed(2).padStart(8)} ms  ${result.throughputMBps.toFixed(2).padStart(10)} MB/s  ` +
      `${result.rowsPerSec.toLocaleString().padStart(10)}`
    );
  }

  console.log("─".repeat(70));

  // Performance analysis
  console.log("\n📈 Performance Analysis:");

  if (results.length >= 2) {
    // Check scalability
    const throughputs = results.map((r) => r.throughputMBps);
    const avgThroughput = throughputs.reduce((a, b) => a + b, 0) / throughputs.length;
    const minThroughput = Math.min(...throughputs);
    const maxThroughput = Math.max(...throughputs);
    const variance = ((maxThroughput - minThroughput) / avgThroughput) * 100;

    console.log(`   Average throughput: ${avgThroughput.toFixed(2)} MB/s`);
    console.log(`   Range: ${minThroughput.toFixed(2)} - ${maxThroughput.toFixed(2)} MB/s`);
    console.log(`   Variance: ${variance.toFixed(1)}%`);

    if (variance < 10) {
      console.log(`   ✅ Excellent scalability (< 10% variance)`);
    } else if (variance < 20) {
      console.log(`   ✓ Good scalability (< 20% variance)`);
    } else {
      console.log(`   ⚠️  Performance degrades with size (${variance.toFixed(1)}% variance)`);
    }

    // Check if meeting baseline
    const baseline = 61.84; // MB/s
    const meetsBaseline = avgThroughput >= baseline * 0.9; // Within 10% of baseline
    console.log(`\n   Baseline: ${baseline} MB/s`);
    console.log(`   ${meetsBaseline ? "✅" : "⚠️"} Average: ${avgThroughput.toFixed(2)} MB/s (${((avgThroughput / baseline) * 100).toFixed(1)}%)`);
  }

  console.log("\n✅ Benchmark suite complete!");
  console.log("═".repeat(70));
}

// Run the suite
await runBenchmarkSuite();
