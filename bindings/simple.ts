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

import { dlopen, FFIType, suffix, toArrayBuffer, ptr } from "bun:ffi";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

// Get library path relative to this file
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Determine prebuilds directory based on platform and architecture
const getPrebuildPath = (): string => {
  const platform = process.platform;
  const arch = process.arch;

  let prebuildDir: string;
  let libName: string;

  if (platform === "darwin") {
    prebuildDir = arch === "arm64" ? "darwin-arm64" : "darwin-x64";
    libName = "libocsv.dylib";
  } else if (platform === "linux") {
    prebuildDir = "linux-x64";
    libName = "libocsv.so";
  } else if (platform === "win32") {
    prebuildDir = "win32-x64";
    libName = "ocsv.dll";
  } else {
    throw new Error(`Unsupported platform: ${platform}`);
  }

  return join(__dirname, "..", "prebuilds", prebuildDir, libName);
};

const libPath = getPrebuildPath();

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
  // Bulk memory access for performance
  ocsv_rows_to_json: {
    args: [FFIType.ptr],
    returns: FFIType.cstring,
  },
  ocsv_free_json_string: {
    args: [FFIType.cstring],
  },
  // Phase 2: Packed buffer (zero-copy)
  ocsv_rows_to_packed_buffer: {
    args: [FFIType.ptr, FFIType.ptr],
    returns: FFIType.ptr,
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

/**
 * Parse CSV using bulk JSON serialization (high performance)
 *
 * This function minimizes FFI overhead by serializing all rows to JSON
 * in one FFI call, then parsing in JavaScript. Significantly faster than
 * field-by-field extraction for large datasets.
 *
 * @param csvData - CSV string to parse
 * @returns 2D array of strings [row][field]
 *
 * @example
 * const rows = parseCSVBulk("name,age\nAlice,30\nBob,25")
 * // [["name", "age"], ["Alice", "30"], ["Bob", "25"]]
 */
export function parseCSVBulk(csvData: string): string[][] {
  const parser = ffi.ocsv_parser_create();

  try {
    // Parse CSV
    const buffer = Buffer.from(csvData);
    const result = ffi.ocsv_parse_string(parser, buffer, buffer.length);

    if (result !== 0) {
      throw new Error("Failed to parse CSV");
    }

    // Get all rows as JSON (ONE FFI call instead of N×M calls)
    const jsonStr = ffi.ocsv_rows_to_json(parser);

    if (!jsonStr) {
      return [];
    }

    // Parse JSON in JavaScript
    // Note: jsonStr is automatically converted to JavaScript string by Bun FFI
    // The memory is managed by the Odin parser and will be freed when parser_destroy is called
    const rows = JSON.parse(jsonStr);

    return rows;
  } finally {
    ffi.ocsv_parser_destroy(parser);
  }
}

/**
 * Deserialize packed binary buffer to 2D array (internal helper)
 *
 * @param bufferPtr - Pointer to packed buffer
 * @param bufferSize - Size of buffer in bytes
 * @returns 2D array of strings [row][field]
 *
 * Binary format:
 *   Header (24 bytes):
 *     0-3:   magic (0x4F435356 "OCSV")
 *     4-7:   version (1)
 *     8-11:  row_count (u32)
 *     12-15: field_count (u32)
 *     16-23: total_bytes (u64)
 *
 *   Row Offsets (row_count × 4 bytes):
 *     24+i*4: offset to row i data
 *
 *   Field Data (variable length):
 *     [length: u16][data: UTF-8 bytes]
 */
function deserializePackedBuffer(bufferPtr: number | bigint, bufferSize: number): string[][] {
  // Convert pointer to ArrayBuffer (zero-copy)
  const arrayBuffer = toArrayBuffer(bufferPtr, 0, bufferSize);
  const view = new DataView(arrayBuffer);
  const bytes = new Uint8Array(arrayBuffer);

  // Read header
  const magic = view.getUint32(0, true);
  if (magic !== 0x4F435356) {
    throw new Error(`Invalid magic number: 0x${magic.toString(16)}`);
  }

  const version = view.getUint32(4, true);
  if (version !== 1) {
    throw new Error(`Unsupported version: ${version}`);
  }

  const rowCount = view.getUint32(8, true);
  const fieldCount = view.getUint32(12, true);
  const totalBytes = view.getBigUint64(16, true);

  // Validate buffer size
  if (BigInt(bufferSize) !== totalBytes) {
    throw new Error(`Buffer size mismatch: expected ${totalBytes}, got ${bufferSize}`);
  }

  // Read row offsets
  const rowOffsets = new Uint32Array(rowCount);
  for (let i = 0; i < rowCount; i++) {
    rowOffsets[i] = view.getUint32(24 + i * 4, true);
  }

  // Deserialize rows
  const rows: string[][] = new Array(rowCount);
  const decoder = new TextDecoder('utf-8');

  for (let i = 0; i < rowCount; i++) {
    const row: string[] = new Array(fieldCount);
    let offset = rowOffsets[i];

    for (let j = 0; j < fieldCount; j++) {
      // Read field length (u16)
      const length = view.getUint16(offset, true);
      offset += 2;

      // Zero-copy string extraction
      if (length > 0) {
        const fieldBytes = bytes.subarray(offset, offset + length);
        row[j] = decoder.decode(fieldBytes);
        offset += length;
      } else {
        row[j] = "";
      }
    }

    rows[i] = row;
  }

  return rows;
}

/**
 * Parse CSV data using packed buffer (zero-copy, highest performance)
 *
 * This is the fastest parsing method, using binary serialization and zero-copy
 * deserialization for minimal FFI overhead.
 *
 * @param csvData - CSV string to parse
 * @returns 2D array of strings [row][field]
 *
 * @example
 * const rows = parseCSVPacked("name,age\nAlice,30\nBob,25")
 * // [["name", "age"], ["Alice", "30"], ["Bob", "25"]]
 */
export function parseCSVPacked(csvData: string): string[][] {
  const parser = ffi.ocsv_parser_create();

  try {
    // Parse CSV
    const buffer = Buffer.from(csvData);
    const result = ffi.ocsv_parse_string(parser, buffer, buffer.length);

    if (result !== 0) {
      throw new Error("Failed to parse CSV");
    }

    // Get packed buffer (ONE FFI call)
    const sizeBuffer = new Int32Array(1);
    const bufferPtr = ffi.ocsv_rows_to_packed_buffer(parser, ptr(sizeBuffer));

    if (!bufferPtr || sizeBuffer[0] <= 0) {
      return [];
    }

    // Deserialize in JavaScript (zero-copy)
    return deserializePackedBuffer(bufferPtr, sizeBuffer[0]);
  } finally {
    ffi.ocsv_parser_destroy(parser);
  }
}
