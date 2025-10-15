#!/usr/bin/env bun

import { parseCSV } from './bindings/index.js';

console.log('Testing basic parsing...');
const result1 = parseCSV('a,b,c');
console.log('✅ Basic:', result1.rows);

console.log('\nTesting with delimiter...');
const result2 = parseCSV('a\tb\tc', { delimiter: '\t' });
console.log('✅ Tab delimiter:', result2.rows);

console.log('\nTesting strict mode error...');
try {
  const result3 = parseCSV('"unterminated');
  console.log('❌ Should have errored');
} catch (e) {
  console.log('✅ Caught error:', e.message);
}

console.log('\nDone!');
