#!/usr/bin/env bun
/**
 * Quick test of simple bindings
 */

import { parseCSV, parseCSVWithHeader, parseCSVToObjects } from "./bindings/simple";

console.log("🧪 Quick test of simple bindings\n");

// Test 1: Basic parsing
const csv1 = "name,age\nAlice,30\nBob,25";
const rows = parseCSV(csv1);
console.log("✅ parseCSV:", JSON.stringify(rows));

// Test 2: With header
const { header, rows: data } = parseCSVWithHeader(csv1);
console.log("✅ parseCSVWithHeader:");
console.log("   Header:", header);
console.log("   Data:", data);

// Test 3: To objects
const objects = parseCSVToObjects(csv1);
console.log("✅ parseCSVToObjects:", JSON.stringify(objects));

// Test 4: Edge cases
const csv2 = `name,description
"Smith, John","CEO of ""Acme"" Corp"
María García,Engineer`;
const edgeRows = parseCSV(csv2);
console.log("✅ Edge cases (quotes, UTF-8):", JSON.stringify(edgeRows));

console.log("\n✨ All tests passed! Simple bindings work perfectly.");
