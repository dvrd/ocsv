/**
 * OCSV - Minimal FFI Bindings
 *
 * Ultra-simple bindings with zero abstraction between JavaScript and Odin FFI.
 * No classes, no wrappers - just direct function calls.
 *
 * Usage:
 *   import { parseCSV } from './bindings/simple.ts'
 *   const rows = parseCSV(csvData)
 */

import { dlopen, FFIType, suffix } from "bun:ffi";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

// Get library path relative to this file
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const libPath = join(__dirname, "..", `libocsv.${suffix}`);

// Load OCSV library
const lib = dlopen(libPath, {
  ocsv_parser_create: {
    returns: FFIType.ptr,
  },
  ocsv_parser_destroy: {
    args: [FFIType.ptr],
  },
  ocsv_parse_string: {
    args: [FFIType.ptr, FFIType.cstring, FFIType.i32],
    returns: FFIType.i32,
  },
  ocsv_get_row_count: {
    args: [FFIType.ptr],
    returns: FFIType.i32,
  },
  ocsv_get_field_count: {
    args: [FFIType.ptr, FFIType.i32],
    returns: FFIType.i32,
  },
  ocsv_get_field: {
    args: [FFIType.ptr, FFIType.i32, FFIType.i32],
    returns: FFIType.cstring,
  },
});

// Direct FFI exports (for advanced users)
export const ffi = lib.symbols;

/**
 * Parse CSV data and return all rows as a 2D array
 *
 * @param csvData - CSV string to parse
 * @returns 2D array of strings [row][field]
 *
 * @example
 * const rows = parseCSV("name,age\nAlice,30\nBob,25")
 * // [["name", "age"], ["Alice", "30"], ["Bob", "25"]]
 */
export function parseCSV(csvData: string): string[][] {
  const parser = ffi.ocsv_parser_create();

  try {
    // Parse
    const buffer = Buffer.from(csvData);
    const result = ffi.ocsv_parse_string(parser, buffer, buffer.length);

    if (result !== 0) {
      throw new Error("Failed to parse CSV");
    }

    // Get dimensions
    const rowCount = ffi.ocsv_get_row_count(parser);
    const rows: string[][] = [];

    // Extract all rows and fields
    for (let i = 0; i < rowCount; i++) {
      const fieldCount = ffi.ocsv_get_field_count(parser, i);
      const row: string[] = [];

      for (let j = 0; j < fieldCount; j++) {
        const field = ffi.ocsv_get_field(parser, i, j);
        row.push(field || "");
      }

      rows.push(row);
    }

    return rows;
  } finally {
    ffi.ocsv_parser_destroy(parser);
  }
}

/**
 * Parse CSV and return with separate header and rows
 *
 * @param csvData - CSV string to parse
 * @returns { header: string[], rows: string[][] }
 *
 * @example
 * const { header, rows } = parseCSVWithHeader("name,age\nAlice,30")
 * // header: ["name", "age"]
 * // rows: [["Alice", "30"]]
 */
export function parseCSVWithHeader(csvData: string): { header: string[]; rows: string[][] } {
  const allRows = parseCSV(csvData);

  if (allRows.length === 0) {
    return { header: [], rows: [] };
  }

  return {
    header: allRows[0],
    rows: allRows.slice(1),
  };
}

/**
 * Parse CSV and return as array of objects using first row as keys
 *
 * @param csvData - CSV string to parse
 * @returns Array of objects { [columnName]: value }
 *
 * @example
 * const records = parseCSVToObjects("name,age\nAlice,30\nBob,25")
 * // [{ name: "Alice", age: "30" }, { name: "Bob", age: "25" }]
 */
export function parseCSVToObjects(csvData: string): Record<string, string>[] {
  const { header, rows } = parseCSVWithHeader(csvData);

  return rows.map(row => {
    const obj: Record<string, string> = {};
    header.forEach((key, i) => {
      obj[key] = row[i] || "";
    });
    return obj;
  });
}

/**
 * Get CSV dimensions without extracting all data
 *
 * @param csvData - CSV string to parse
 * @returns { rows: number, avgFields: number }
 *
 * @example
 * const { rows, avgFields } = getCSVDimensions(csvData)
 * console.log(`CSV has ${rows} rows with ~${avgFields} fields each`)
 */
export function getCSVDimensions(csvData: string): { rows: number; avgFields: number } {
  const parser = ffi.ocsv_parser_create();

  try {
    const buffer = Buffer.from(csvData);
    const result = ffi.ocsv_parse_string(parser, buffer, buffer.length);

    if (result !== 0) {
      throw new Error("Failed to parse CSV");
    }

    const rowCount = ffi.ocsv_get_row_count(parser);

    if (rowCount === 0) {
      return { rows: 0, avgFields: 0 };
    }

    // Sample some rows to get average field count
    const samples = Math.min(10, rowCount);
    let totalFields = 0;

    for (let i = 0; i < samples; i++) {
      const idx = Math.floor((i / samples) * rowCount);
      totalFields += ffi.ocsv_get_field_count(parser, idx);
    }

    return {
      rows: rowCount,
      avgFields: Math.round(totalFields / samples),
    };
  } finally {
    ffi.ocsv_parser_destroy(parser);
  }
}

/**
 * Parse CSV and get specific row by index
 *
 * @param csvData - CSV string to parse
 * @param rowIndex - Row index (0-based)
 * @returns Array of field values or null if index out of bounds
 *
 * @example
 * const row = getRow(csvData, 5)  // Get 6th row
 */
export function getRow(csvData: string, rowIndex: number): string[] | null {
  const parser = ffi.ocsv_parser_create();

  try {
    const buffer = Buffer.from(csvData);
    const result = ffi.ocsv_parse_string(parser, buffer, buffer.length);

    if (result !== 0) {
      throw new Error("Failed to parse CSV");
    }

    const rowCount = ffi.ocsv_get_row_count(parser);

    if (rowIndex < 0 || rowIndex >= rowCount) {
      return null;
    }

    const fieldCount = ffi.ocsv_get_field_count(parser, rowIndex);
    const row: string[] = [];

    for (let j = 0; j < fieldCount; j++) {
      const field = ffi.ocsv_get_field(parser, rowIndex, j);
      row.push(field || "");
    }

    return row;
  } finally {
    ffi.ocsv_parser_destroy(parser);
  }
}

/**
 * Parse CSV and get specific field value
 *
 * @param csvData - CSV string to parse
 * @param rowIndex - Row index (0-based)
 * @param fieldIndex - Field index (0-based)
 * @returns Field value or null if indices out of bounds
 *
 * @example
 * const value = getField(csvData, 1, 2)  // Row 1, Column 2
 */
export function getField(csvData: string, rowIndex: number, fieldIndex: number): string | null {
  const parser = ffi.ocsv_parser_create();

  try {
    const buffer = Buffer.from(csvData);
    const result = ffi.ocsv_parse_string(parser, buffer, buffer.length);

    if (result !== 0) {
      throw new Error("Failed to parse CSV");
    }

    const rowCount = ffi.ocsv_get_row_count(parser);

    if (rowIndex < 0 || rowIndex >= rowCount) {
      return null;
    }

    const fieldCount = ffi.ocsv_get_field_count(parser, rowIndex);

    if (fieldIndex < 0 || fieldIndex >= fieldCount) {
      return null;
    }

    return ffi.ocsv_get_field(parser, rowIndex, fieldIndex) || "";
  } finally {
    ffi.ocsv_parser_destroy(parser);
  }
}
