#!/usr/bin/env bun

/**
 * Phase 1 Integration Test
 * Tests new config options and error handling
 */

import { parseCSV, Parser, OcsvError, ParseErrorCode } from './bindings/index.js';

console.log('🧪 Phase 1 Integration Tests\n');

// Test 1: Basic parsing with custom delimiter
console.log('Test 1: Custom delimiter (tab)');
try {
  const result = parseCSV('a\tb\tc\n1\t2\t3', { delimiter: '\t' });
  console.log('✅ Parsed with tab delimiter:', result.rows);
  console.assert(result.rows.length === 2, 'Should have 2 rows');
  console.assert(result.rows[0][0] === 'a', 'First field should be "a"');
} catch (e) {
  console.log('❌ Test 1 failed:', e.message);
}

// Test 2: Relaxed mode
console.log('\nTest 2: Relaxed mode (should accept RFC violations)');
try {
  const result = parseCSV('"quoted"extra', { relaxed: true });
  console.log('✅ Relaxed mode accepted RFC violation:', result.rows);
} catch (e) {
  console.log('❌ Test 2 failed:', e.message);
}

// Test 3: Strict mode error (unterminated quote)
console.log('\nTest 3: Strict mode error handling');
try {
  const result = parseCSV('"unterminated', { relaxed: false });
  console.log('❌ Should have thrown error for unterminated quote');
} catch (e) {
  if (e instanceof OcsvError) {
    console.log('✅ Caught OcsvError:', e.message);
    console.log('  Error code:', e.code, `(${e.getCodeName()})`);
    console.log('  Line:', e.line, 'Column:', e.column);
    console.assert(e.code === ParseErrorCode.Unterminated_Quote, 'Should be unterminated quote error');
  } else {
    console.log('❌ Wrong error type:', e);
  }
}

// Test 4: RFC violation error
console.log('\nTest 4: RFC violation error (character after quote)');
try {
  const result = parseCSV('"quoted"x', { relaxed: false });
  console.log('❌ Should have thrown error for RFC violation');
} catch (e) {
  if (e instanceof OcsvError) {
    console.log('✅ Caught OcsvError:', e.message);
    console.log('  Error code:', e.code, `(${e.getCodeName()})`);
    console.log('  Line:', e.line, 'Column:', e.column);
    console.assert(e.code === ParseErrorCode.Invalid_Character_After_Quote, 'Should be invalid character error');
  } else {
    console.log('❌ Wrong error type:', e);
  }
}

// Test 5: Multiple config options
console.log('\nTest 5: Multiple config options');
try {
  const csv = `# This is a comment
  a  ,  b  ,  c
  1  ,  2  ,  3  `;
  const result = parseCSV(csv, {
    trim: true,
    comment: '#',
    skipEmptyLines: true
  });
  console.log('✅ Multiple options applied:', result.rows);
  console.assert(result.rows.length === 2, 'Should have 2 rows (comment skipped)');
  console.assert(result.rows[0][0] === 'a', 'Should be trimmed to "a"');
} catch (e) {
  console.log('❌ Test 5 failed:', e.message, e);
}

// Test 6: Line range
console.log('\nTest 6: Line range (fromLine/toLine)');
try {
  const csv = 'a,b,c\n1,2,3\n4,5,6\n7,8,9';
  const result = parseCSV(csv, { fromLine: 1, toLine: 2 });
  console.log('✅ Parsed lines 1-2:', result.rows);
  console.assert(result.rows.length === 2, 'Should have 2 rows');
} catch (e) {
  console.log('❌ Test 6 failed:', e.message, e);
}

// Test 7: Backwards compatibility
console.log('\nTest 7: Backwards compatibility (no options)');
try {
  const result = parseCSV('a,b,c\n1,2,3');
  console.log('✅ Basic parsing still works:', result.rows);
  console.assert(result.rows.length === 2, 'Should have 2 rows');
} catch (e) {
  console.log('❌ Test 7 failed:', e.message);
}

console.log('\n✨ Phase 1 tests complete!');
