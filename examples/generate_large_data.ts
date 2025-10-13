#!/usr/bin/env bun
/**
 * Generate Large CSV Dataset
 *
 * Creates a realistic CSV file with 10,000+ rows for testing parser performance
 */

import { writeFileSync } from "fs";

const ROWS = 10000;

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

console.log(`📊 Generating CSV with ${ROWS.toLocaleString()} rows...`);
const startTime = performance.now();

// Header
let csv = "id,name,email,age,city,department,salary,hire_date,product,quantity,price,total\n";

const startDate = new Date(2020, 0, 1);
const endDate = new Date(2024, 11, 31);

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
}

// Write file
writeFileSync("./large_data.csv", csv);
const endTime = performance.now();

const fileSizeBytes = Buffer.byteLength(csv, 'utf-8');
const fileSizeKB = (fileSizeBytes / 1024).toFixed(2);
const fileSizeMB = (fileSizeBytes / (1024 * 1024)).toFixed(2);

console.log(`✅ Generated ./large_data.csv`);
console.log(`   Rows: ${ROWS.toLocaleString()}`);
console.log(`   Size: ${fileSizeMB} MB (${fileSizeKB} KB)`);
console.log(`   Time: ${(endTime - startTime).toFixed(2)}ms`);
console.log(`\n💡 Use this file to test the parser:`);
console.log(`   bun run test_large_data.ts`);
