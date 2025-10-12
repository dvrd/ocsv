/**
 * OCSV - Bun FFI Bindings
 *
 * JavaScript wrapper for the OCSV Odin library.
 * Provides a clean JavaScript API for CSV parsing.
 */

import { dlopen, FFIType } from "bun:ffi";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

// Determine library path
const __dirname = dirname(fileURLToPath(import.meta.url));
const libPath = resolve(__dirname, "../lib/libcisv.so");

// Load the shared library
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
  cisv_get_field_count: {
    args: [FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
});

/**
 * CisvParser class - Main CSV parser interface
 */
export class CisvParser {
  /**
   * Create a new CSV parser
   */
  constructor() {
    this.parser = lib.symbols.cisv_parser_create();
    if (!this.parser) {
      throw new Error("Failed to create parser");
    }
  }

  /**
   * Parse a CSV string
   * @param {string} data - CSV data to parse
   * @returns {number} Number of rows parsed
   * @throws {Error} If parsing fails
   */
  parseString(data) {
    // Convert string to buffer for FFI
    const encoder = new TextEncoder();
    const dataBuffer = encoder.encode(data + "\0");

    const result = lib.symbols.cisv_parse_string(
      this.parser,
      dataBuffer,
      data.length
    );

    if (result !== 0) {
      throw new Error("CSV parsing failed");
    }

    return this.getRowCount();
  }

  /**
   * Get the number of rows parsed
   * @returns {number} Number of rows
   */
  getRowCount() {
    return lib.symbols.cisv_get_row_count(this.parser);
  }

  /**
   * Get the number of fields in a specific row
   * @param {number} rowIndex - Row index (0-based)
   * @returns {number} Number of fields in the row
   */
  getFieldCount(rowIndex) {
    return lib.symbols.cisv_get_field_count(this.parser, rowIndex);
  }

  /**
   * Destroy the parser and free all memory
   * Must be called when done with the parser
   */
  destroy() {
    if (this.parser) {
      lib.symbols.cisv_parser_destroy(this.parser);
      this.parser = null;
    }
  }

  /**
   * Parse a file
   * @param {string} path - Path to CSV file
   * @returns {Promise<number>} Number of rows parsed
   */
  async parseFile(path) {
    const file = Bun.file(path);
    const text = await file.text();
    return this.parseString(text);
  }
}

/**
 * Convenience function to parse CSV string
 * @param {string} data - CSV data
 * @returns {number} Number of rows parsed
 */
export function parseCSV(data) {
  const parser = new CisvParser();
  try {
    return parser.parseString(data);
  } finally {
    parser.destroy();
  }
}

/**
 * Convenience function to parse CSV file
 * @param {string} path - Path to CSV file
 * @returns {Promise<number>} Number of rows parsed
 */
export async function parseCSVFile(path) {
  const parser = new CisvParser();
  try {
    return await parser.parseFile(path);
  } finally {
    parser.destroy();
  }
}
