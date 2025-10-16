#!/usr/bin/env bun
/**
 * Generate large CSV test file for benchmarking
 * Usage: bun examples/generate_data.js [rows]
 */

import { writeFileSync } from 'fs';
import { resolve } from 'path';

const rows = parseInt(process.argv[2] || '100000', 10);
const outputPath = resolve('./examples/large_data.csv');

console.log(`Generating CSV with ${rows.toLocaleString()} rows...`);

// Generate header
const header = 'id,name,email,age,city,country,salary,department\n';
let csv = header;

// Generate data rows
const names = ['John', 'Jane', 'Bob', 'Mary', 'David', 'Sarah', 'Michael', 'Emma'];
const cities = ['NYC', 'LA', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego'];
const countries = ['USA', 'Canada', 'UK', 'Germany', 'France', 'Japan', 'Australia', 'Brazil'];
const departments = ['Engineering', 'Sales', 'Marketing', 'HR', 'Finance', 'Operations', 'IT', 'Legal'];

const startTime = performance.now();

for (let i = 0; i < rows; i++) {
  const id = i + 1;
  const name = names[i % names.length];
  const email = `${name.toLowerCase()}${id}@example.com`;
  const age = 25 + (i % 40);
  const city = cities[i % cities.length];
  const country = countries[i % countries.length];
  const salary = 50000 + (i % 100000);
  const department = departments[i % departments.length];

  csv += `${id},${name},${email},${age},${city},${country},${salary},${department}\n`;

  // Progress indicator
  if (i > 0 && i % 100000 === 0) {
    const elapsed = (performance.now() - startTime) / 1000;
    const rate = i / elapsed;
    console.log(`  ${i.toLocaleString()} rows (${rate.toFixed(0)} rows/sec)`);
  }
}

// Write to file
console.log('Writing to file...');
writeFileSync(outputPath, csv);

const endTime = performance.now();
const elapsed = (endTime - startTime) / 1000;
const fileSize = csv.length;
const fileSizeMB = (fileSize / 1024 / 1024).toFixed(2);

console.log(`\n✅ Generated ${rows.toLocaleString()} rows in ${elapsed.toFixed(2)}s`);
console.log(`   File: ${outputPath}`);
console.log(`   Size: ${fileSizeMB} MB`);
console.log(`   Rate: ${(rows / elapsed).toFixed(0)} rows/sec\n`);
