#!/usr/bin/env bun
/**
 * Generate Large CSV Dataset
 *
 * Creates a realistic CSV file with configurable number of rows for testing parser performance
 *
 * Usage:
 *   bun run generate_large_data.ts [rows] [output_file]
 *
 * Examples:
 *   bun run generate_large_data.ts                    # 10K rows (default)
 *   bun run generate_large_data.ts 100000             # 100K rows
 *   bun run generate_large_data.ts 1000000            # 1M rows
 *   bun run generate_large_data.ts 10000000           # 10M rows
 *   bun run generate_large_data.ts 10000000 huge.csv  # 10M rows to custom file
 */

import { writeFileSync } from "fs";

// Parse command line arguments
const args = process.argv.slice(2);
const ROWS = args[0] ? parseInt(args[0], 10) : 10000;
const OUTPUT_FILE = args[1] || "./large_data.csv";

// Validate row count
if (isNaN(ROWS) || ROWS < 1) {
  console.error("❌ Error: Row count must be a positive number");
  console.log("\nUsage: bun run generate_large_data.ts [rows] [output_file]");
  console.log("Example: bun run generate_large_data.ts 10000000");
  process.exit(1);
}

// Sample data for realistic generation
const firstNames = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda", "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Sarah", "Christopher", "Karen"];
const lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin"];
const cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose", "Austin", "Jacksonville", "Fort Worth", "Columbus", "Charlotte", "San Francisco", "Indianapolis", "Seattle", "Denver", "Boston"];
const departments = ["Engineering", "Sales", "Marketing", "HR", "Finance", "Operations", "IT", "Customer Support", "Product", "Legal"];
const products = ["Laptop Pro 15\"", "Desktop Workstation", "Wireless Mouse", "Mechanical Keyboard", "USB-C Hub", "Monitor 27\"", "Webcam HD", "Headphones", "SSD 1TB", "RAM 16GB"];

function randomItem<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomInt(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomFloat(min: number, max: number, decimals: number = 2): number {
  return parseFloat((Math.random() * (max - min) + min).toFixed(decimals));
}

function randomDate(start: Date, end: Date): string {
  const date = new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
  return date.toISOString().split('T')[0];
}

// Display generation info
const sizeEstimate = (ROWS * 140) / (1024 * 1024); // ~140 bytes per row
console.log(`📊 Generating CSV with ${ROWS.toLocaleString()} rows...`);
console.log(`   Estimated size: ~${sizeEstimate.toFixed(2)} MB`);
console.log(`   Output: ${OUTPUT_FILE}`);
if (ROWS >= 1000000) {
  console.log(`   ⏳ This may take a minute for ${ROWS >= 10000000 ? '10M+' : '1M+'} rows...`);
}
console.log();

const startTime = performance.now();

// Header
let csv = "id,name,email,age,city,department,salary,hire_date,product,quantity,price,total\n";

const startDate = new Date(2020, 0, 1);
const endDate = new Date(2024, 11, 31);

// For very large files (>1M rows), use chunked writing to avoid memory issues
const CHUNK_SIZE = 100000;
const useChunking = ROWS > 1000000;

if (useChunking) {
  // Write header first
  writeFileSync(OUTPUT_FILE, csv);
  csv = ""; // Clear buffer
}

// Generate rows
for (let i = 1; i <= ROWS; i++) {
  const firstName = randomItem(firstNames);
  const lastName = randomItem(lastNames);
  const name = `${firstName} ${lastName}`;
  const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}@company.com`;
  const age = randomInt(22, 65);
  const city = randomItem(cities);
  const department = randomItem(departments);
  const salary = randomFloat(40000, 180000, 2);
  const hireDate = randomDate(startDate, endDate);
  const product = randomItem(products);
  const quantity = randomInt(1, 100);
  const price = randomFloat(10, 5000, 2);
  const total = parseFloat((quantity * price).toFixed(2));

  // Add some rows with quoted fields (commas in names, special characters)
  let rowName = name;
  if (i % 7 === 0) {
    rowName = `"${lastName}, ${firstName}"`; // Quoted field with comma
  }

  let rowCity = city;
  if (i % 13 === 0) {
    rowCity = `"${city}, USA"`; // Quoted field with comma
  }

  csv += `${i},${rowName},${email},${age},${rowCity},${department},${salary},${hireDate},${product},${quantity},${price},${total}\n`;

  // For large files, write in chunks to avoid memory issues
  if (useChunking && i % CHUNK_SIZE === 0) {
    const fs = await import("fs");
    fs.appendFileSync(OUTPUT_FILE, csv);
    csv = ""; // Clear buffer

    // Progress indicator
    const progress = ((i / ROWS) * 100).toFixed(1);
    process.stdout.write(`\r   Progress: ${progress}% (${i.toLocaleString()} / ${ROWS.toLocaleString()} rows)`);
  }
}

// Write remaining data
if (useChunking && csv.length > 0) {
  const fs = await import("fs");
  fs.appendFileSync(OUTPUT_FILE, csv);
  process.stdout.write(`\r   Progress: 100.0% (${ROWS.toLocaleString()} / ${ROWS.toLocaleString()} rows)\n`);
} else if (!useChunking) {
  writeFileSync(OUTPUT_FILE, csv);
}

const endTime = performance.now();
const generationTime = endTime - startTime;

// Calculate file size
const fs = await import("fs");
const stats = fs.statSync(OUTPUT_FILE);
const fileSizeBytes = stats.size;
const fileSizeKB = (fileSizeBytes / 1024).toFixed(2);
const fileSizeMB = (fileSizeBytes / (1024 * 1024)).toFixed(2);

console.log();
console.log(`✅ Generated ${OUTPUT_FILE}`);
console.log(`   Rows: ${ROWS.toLocaleString()} (+ 1 header)`);
console.log(`   Size: ${fileSizeMB} MB (${fileSizeKB} KB, ${fileSizeBytes.toLocaleString()} bytes)`);
console.log(`   Time: ${generationTime.toFixed(2)}ms (${(generationTime / 1000).toFixed(2)}s)`);
console.log(`   Speed: ${(ROWS / (generationTime / 1000)).toFixed(0)} rows/sec`);
console.log();
console.log(`💡 Test the parser with this file:`);
console.log(`   bun run test_large_data.ts ${OUTPUT_FILE}`);
