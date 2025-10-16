import { parseCSV } from "ocsv";
import { readFileSync } from "fs";
import { join } from "path";

console.log("OCSV Large File Benchmark Test");
console.log("================================\n");

// Path to the large CSV file (1.2 GB, ~10M rows)
const filePath = join(__dirname, "../examples/large_data.csv");

console.log(`File: ${filePath}`);
console.log("Starting parse...\n");

const startTime = performance.now();
const startMem = process.memoryUsage().heapUsed / 1024 / 1024;

try {
  // Read the file
  const csvData = readFileSync(filePath, "utf-8");
  const fileSize = csvData.length;

  console.log(`File size: ${(fileSize / 1024 / 1024).toFixed(2)} MB`);
  console.log(`File size: ${(fileSize / 1024 / 1024 / 1024).toFixed(2)} GB\n`);

  // Parse the CSV
  const parseStart = performance.now();
  const result = parseCSV(csvData);
  const parseEnd = performance.now();

  const parseTime = (parseEnd - parseStart) / 1000; // seconds
  const totalTime = (parseEnd - startTime) / 1000; // seconds

  // Calculate throughput
  const throughputMBps = (fileSize / 1024 / 1024) / parseTime;
  const rowsPerSec = result.rowCount / parseTime;

  // Memory usage
  const endMem = process.memoryUsage().heapUsed / 1024 / 1024;
  const memUsed = endMem - startMem;

  console.log("Parse Results:");
  console.log("==============");
  console.log(`Total rows: ${result.rowCount.toLocaleString()}`);
  console.log(`Columns per row: ${result.rows[0]?.length || 0}`);
  console.log(`Parse time: ${parseTime.toFixed(2)}s`);
  console.log(`Total time (incl. read): ${totalTime.toFixed(2)}s`);
  console.log(`Throughput: ${throughputMBps.toFixed(2)} MB/s`);
  console.log(`Rows/sec: ${rowsPerSec.toLocaleString(undefined, {maximumFractionDigits: 0})}`);
  console.log(`Memory used: ${memUsed.toFixed(2)} MB`);

  // Show sample data
  console.log("\nSample rows (first 5):");
  for (let i = 0; i < Math.min(5, result.rows.length); i++) {
    console.log(`Row ${i + 1}:`, result.rows[i]);
  }

  console.log("\nSample rows (last 5):");
  for (let i = Math.max(0, result.rows.length - 5); i < result.rows.length; i++) {
    console.log(`Row ${i + 1}:`, result.rows[i]);
  }

} catch (error) {
  console.error("Error parsing CSV:", error);
  process.exit(1);
}

console.log("\nTest completed successfully!");
