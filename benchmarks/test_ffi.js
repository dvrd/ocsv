/**
 * Simple FFI test to debug the crash
 */

import { dlopen, FFIType, CString, ptr } from "bun:ffi";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const libPath = resolve(__dirname, "../lib/libcisv.so");

console.log("Loading library:", libPath);

const lib = dlopen(libPath, {
  cisv_parser_create: {
    returns: FFIType.ptr,
  },
  cisv_parser_destroy: {
    args: [FFIType.ptr],
    returns: FFIType.void,
  },
  cisv_parse_string: {
    args: [FFIType.ptr, FFIType.cstring, FFIType.i32],
    returns: FFIType.i32,
  },
  cisv_get_row_count: {
    args: [FFIType.ptr],
    returns: FFIType.i32,
  },
});

console.log("Library loaded");

console.log("Creating parser...");
const parser = lib.symbols.cisv_parser_create();
console.log("Parser created:", parser);

if (!parser) {
  console.error("Failed to create parser!");
  process.exit(1);
}

console.log("Testing with very simple data...");
const testData = "a,b,c";
console.log("Test data:", testData);
console.log("Test data length:", testData.length);

try {
  // Convert string to buffer
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(testData + "\0"); // Add null terminator
  console.log("Buffer created, length:", dataBuffer.length);

  console.log("Calling cisv_parse_string with len =", testData.length);
  const result = lib.symbols.cisv_parse_string(parser, dataBuffer, testData.length);
  console.log("Parse result:", result);

  if (result !== 0) {
    console.error("Parse failed with code:", result);
  } else {
    const rowCount = lib.symbols.cisv_get_row_count(parser);
    console.log("Row count:", rowCount);
    console.log("✅ Success!");
  }
} catch (error) {
  console.error("Error during parsing:", error);
} finally {
  console.log("Destroying parser...");
  lib.symbols.cisv_parser_destroy(parser);
  console.log("Done");
}
