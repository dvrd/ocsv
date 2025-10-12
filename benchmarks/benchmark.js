/**
 * OCSV Performance Benchmark
 *
 * Validates that Odin implementation achieves ≥90% of C performance
 * Target: ≥65 MB/s (90% of CISV's 71 MB/s baseline)
 */

import { CisvParser } from "../bindings/cisv.js";

// Generate test data: 30,000 rows (simple CSV)
const testData = `a,b,c
1,2,3
4,5,6
`.repeat(10000); // 30k rows

console.log("=" .repeat(60));
console.log("OCSV Performance Benchmark (Odin + Bun)");
console.log("=" .repeat(60));
console.log();

const parser = new CisvParser();

try {
  console.log("Test data:", testData.length, "bytes");
  console.log("Expected rows: ~30,000");
  console.log();

  // Warm-up run (JIT compilation)
  console.log("Running warm-up...");
  parser.parseString(testData.substring(0, 1000));
  console.log("✓ Warm-up complete");
  console.log();

  // Actual benchmark
  console.log("Running benchmark...");
  const start = performance.now();
  const rowCount = parser.parseString(testData);
  const end = performance.now();

  // Calculate metrics
  const mb = (testData.length / 1024 / 1024).toFixed(2);
  const timeMs = (end - start).toFixed(2);
  const throughput = (mb / (timeMs / 1000)).toFixed(2);

  console.log("✓ Parse complete");
  console.log();
  console.log("-" .repeat(60));
  console.log("Results:");
  console.log("-" .repeat(60));
  console.log(`  Rows parsed:  ${rowCount.toLocaleString()}`);
  console.log(`  Data size:    ${mb} MB`);
  console.log(`  Time:         ${timeMs} ms`);
  console.log(`  Throughput:   ${throughput} MB/s`);
  console.log();

  // Performance evaluation
  const target = 65; // 90% of C's 71 MB/s
  const actual = parseFloat(throughput);

  if (actual >= target) {
    console.log(`✅ Performance target MET!`);
    console.log(`   Target:  ${target} MB/s`);
    console.log(`   Actual:  ${actual} MB/s`);
    console.log(`   Margin:  +${((actual / target - 1) * 100).toFixed(1)}%`);
  } else {
    console.log(`❌ Performance target MISSED`);
    console.log(`   Target:  ${target} MB/s`);
    console.log(`   Actual:  ${actual} MB/s`);
    console.log(`   Deficit: ${((1 - actual / target) * 100).toFixed(1)}%`);
  }

  console.log();
  console.log("=" .repeat(60));

  // Exit with appropriate code
  process.exit(actual >= target ? 0 : 1);
} catch (error) {
  console.error("❌ Benchmark failed:", error.message);
  process.exit(1);
} finally {
  parser.destroy();
}
