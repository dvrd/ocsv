/**
 * OCSV - High-performance CSV Parser
 *
 * A fast, RFC 4180 compliant CSV parser written in Odin with Bun FFI bindings.
 * Achieves 66.67 MB/s throughput with zero memory leaks.
 *
 * @module ocsv
 */

import { dlopen, FFIType, ptr, toArrayBuffer } from "bun:ffi";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { existsSync } from "fs";
import os from "os";

/**
 * Error codes from the parser
 */
export const ParseErrorCode = {
	NONE: 0,
	INVALID_INPUT: 1,
	UNTERMINATED_QUOTE: 2,
	INVALID_ESCAPE: 3,
	ROW_TOO_LARGE: 4,
	MEMORY_ERROR: 5,
	IO_ERROR: 6,
};

/**
 * Custom error class for OCSV parsing errors
 *
 * @extends Error
 * @example
 * try {
 *   parser.parse(malformedCSV);
 * } catch (err) {
 *   if (err instanceof OcsvError) {
 *     console.error(`Parse error at line ${err.line}, column ${err.column}: ${err.message}`);
 *     console.error(`Error code: ${err.code}`);
 *   }
 * }
 */
export class OcsvError extends Error {
	/**
	 * Create a new OCSV parsing error
	 * @param {string} message - Error message
	 * @param {number} code - Error code from ParseErrorCode
	 * @param {number} line - Line number where error occurred (1-indexed)
	 * @param {number} column - Column number where error occurred (1-indexed)
	 */
	constructor(message, code, line, column) {
		super(message);
		this.name = "OcsvError";
		this.code = code;
		this.line = line;
		this.column = column;
	}
}

/**
 * Lazy row accessor - reads field data on demand
 *
 * Provides efficient access to individual fields without materializing
 * the entire row in memory. Ideal for processing large files where you
 * only need specific columns.
 *
 * @example
 * const result = parseCSV(data, { mode: 'lazy' });
 * const row = result.getRow(100);
 * console.log(row.getField(0));    // Get first field
 * console.log(row.toArray());      // Materialize entire row
 * result.destroy();
 */
export class LazyRow {
	/**
	 * Create a new lazy row accessor (internal use only)
	 * @private
	 * @param {bigint} parser - Pointer to native parser
	 * @param {number} rowIndex - Zero-based row index
	 */
	constructor(parser, rowIndex) {
		this.parser = parser;
		this.rowIndex = rowIndex;
		this._fieldCount = null;
	}

	/**
	 * Get the number of fields in this row
	 * @type {number}
	 */
	get fieldCount() {
		if (this._fieldCount === null) {
			this._fieldCount = lib.symbols.ocsv_get_field_count(this.parser, this.rowIndex);
		}
		return this._fieldCount;
	}

	/**
	 * Get a specific field by index
	 * @param {number} fieldIndex - Zero-based field index
	 * @returns {string|null} Field value, or null if index out of bounds
	 *
	 * @example
	 * const row = result.getRow(5);
	 * const name = row.getField(0);  // First column
	 * const age = row.getField(1);   // Second column
	 */
	getField(fieldIndex) {
		if (fieldIndex < 0 || fieldIndex >= this.fieldCount) {
			return null;
		}
		return lib.symbols.ocsv_get_field(this.parser, this.rowIndex, fieldIndex) || "";
	}

	/**
	 * Materialize the entire row as an array
	 * @returns {string[]} Array of field values
	 *
	 * @example
	 * const row = result.getRow(10);
	 * const fields = row.toArray();
	 * console.log(fields); // ['Alice', '30', 'NYC']
	 */
	toArray() {
		const result = [];
		for (let i = 0; i < this.fieldCount; i++) {
			result.push(this.getField(i));
		}
		return result;
	}

	/**
	 * Convert row to object using provided headers
	 * @param {string[]} headers - Column headers
	 * @returns {Object<string, string>} Object mapping headers to field values
	 *
	 * @example
	 * const headers = ['name', 'age', 'city'];
	 * const row = result.getRow(10);
	 * const obj = row.toObject(headers);
	 * console.log(obj); // { name: 'Alice', age: '30', city: 'NYC' }
	 */
	toObject(headers) {
		const obj = {};
		for (let i = 0; i < headers.length; i++) {
			obj[headers[i]] = this.getField(i);
		}
		return obj;
	}
}

/**
 * Lazy result accessor - provides on-demand row access
 *
 * Returned when using `mode: 'lazy'`. Allows iteration over CSV rows
 * without materializing the entire dataset in memory. Perfect for
 * processing massive files (100M+ rows) with minimal memory footprint.
 *
 * **IMPORTANT:** You MUST call `destroy()` when done to free native memory.
 *
 * @example Basic usage
 * const result = parseCSV(data, { mode: 'lazy' });
 * try {
 *   const row = result.getRow(100);
 *   console.log(row.toArray());
 * } finally {
 *   result.destroy();  // REQUIRED!
 * }
 *
 * @example Iteration
 * const result = parseCSV(data, { mode: 'lazy', hasHeader: true });
 * try {
 *   for (const row of result) {
 *     const obj = row.toObject(result.headers);
 *     console.log(obj);
 *   }
 * } finally {
 *   result.destroy();
 * }
 */
export class LazyResult {
	/**
	 * Create a new lazy result accessor (internal use only)
	 * @private
	 * @param {bigint} parser - Pointer to native parser
	 * @param {number} rowCount - Total number of data rows (excluding header)
	 * @param {string[]|null} headers - Header row if hasHeader was true
	 * @param {ParseOptions} options - Original parse options
	 */
	constructor(parser, rowCount, headers, options) {
		this.parser = parser;
		this.rowCount = rowCount;
		this.headers = headers;
		this.options = options;
		this._destroyed = false;
	}

	/**
	 * Get a specific row by index (lazy access)
	 * @param {number} rowIndex - Zero-based row index (excluding header)
	 * @returns {LazyRow|null} Row accessor, or null if index out of bounds
	 * @throws {Error} If LazyResult has been destroyed
	 *
	 * @example
	 * const result = parseCSV(data, { mode: 'lazy' });
	 * const row = result.getRow(1000);  // Access row 1000 directly
	 * console.log(row.getField(2));     // Get column 2
	 * result.destroy();
	 */
	getRow(rowIndex) {
		if (this._destroyed) {
			throw new Error("LazyResult has been destroyed");
		}
		if (rowIndex < 0 || rowIndex >= this.rowCount) {
			return null;
		}
		// Offset by 1 if we have headers
		const actualRowIndex = this.headers ? rowIndex + 1 : rowIndex;
		return new LazyRow(this.parser, actualRowIndex);
	}

	/**
	 * Iterate over all rows (supports for...of loops)
	 * @generator
	 * @yields {LazyRow} Each row in the dataset
	 *
	 * @example
	 * const result = parseCSV(data, { mode: 'lazy' });
	 * try {
	 *   for (const row of result) {
	 *     console.log(row.toArray());
	 *   }
	 * } finally {
	 *   result.destroy();
	 * }
	 */
	*[Symbol.iterator]() {
		for (let i = 0; i < this.rowCount; i++) {
			yield this.getRow(i);
		}
	}

	/**
	 * Destroy the lazy result and free native memory
	 *
	 * **IMPORTANT:** You MUST call this method when done with lazy results.
	 * Failure to call destroy() will cause memory leaks in native code.
	 *
	 * @example
	 * const result = parseCSV(data, { mode: 'lazy' });
	 * try {
	 *   // Use result...
	 * } finally {
	 *   result.destroy();  // Always destroy in finally block
	 * }
	 */
	destroy() {
		if (!this._destroyed) {
			lib.symbols.ocsv_parser_destroy(this.parser);
			this._destroyed = true;
		}
	}
}

/**
 * Detect the current platform and architecture
 * @returns {string} Platform string in format: platform-arch
 */
function getPlatform() {
	const platform = os.platform();
	const arch = os.arch();

	// Map Node.js platform names to our naming convention
	const platformMap = {
		'darwin': 'darwin',
		'linux': 'linux',
		'win32': 'win32'
	};

	const archMap = {
		'x64': 'x64',
		'arm64': 'arm64'
	};

	return `${platformMap[platform] || platform}-${archMap[arch] || arch}`;
}

/**
 * Get the path to the native library
 * @returns {string} Absolute path to the library
 */
function getLibraryPath() {
	const __dirname = dirname(fileURLToPath(import.meta.url));
	const platform = getPlatform();

	// Determine library name by platform
	let libName;
	if (platform.startsWith('darwin')) {
		libName = 'libocsv.dylib';
	} else if (platform.startsWith('linux')) {
		libName = 'libocsv.so';
	} else if (platform.startsWith('win32')) {
		libName = 'ocsv.dll';
	} else {
		throw new Error(`Unsupported platform: ${platform}`);
	}

	// Try prebuilds directory first
	const prebuiltPath = resolve(__dirname, '..', 'prebuilds', platform, libName);
	if (existsSync(prebuiltPath)) {
		return prebuiltPath;
	}

	// Fall back to root directory (for development)
	const devPath = resolve(__dirname, '..', libName);
	if (existsSync(devPath)) {
		return devPath;
	}

	throw new Error(`Could not find library for platform ${platform}. Tried:\n  ${prebuiltPath}\n  ${devPath}`);
}

// Load the shared library
const libPath = getLibraryPath();
const lib = dlopen(libPath, {
	ocsv_parser_create: {
		returns: FFIType.ptr,
	},
	ocsv_parser_destroy: {
		args: [FFIType.ptr],
		returns: FFIType.void,
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
	// Configuration setters (Phase 1)
	ocsv_set_delimiter: {
		args: [FFIType.ptr, FFIType.u8],
		returns: FFIType.i32,
	},
	ocsv_set_quote: {
		args: [FFIType.ptr, FFIType.u8],
		returns: FFIType.i32,
	},
	ocsv_set_escape: {
		args: [FFIType.ptr, FFIType.u8],
		returns: FFIType.i32,
	},
	ocsv_set_skip_empty_lines: {
		args: [FFIType.ptr, FFIType.bool],
		returns: FFIType.i32,
	},
	ocsv_set_comment: {
		args: [FFIType.ptr, FFIType.u8],
		returns: FFIType.i32,
	},
	ocsv_set_trim: {
		args: [FFIType.ptr, FFIType.bool],
		returns: FFIType.i32,
	},
	ocsv_set_relaxed: {
		args: [FFIType.ptr, FFIType.bool],
		returns: FFIType.i32,
	},
	ocsv_set_max_row_size: {
		args: [FFIType.ptr, FFIType.i32],
		returns: FFIType.i32,
	},
	ocsv_set_from_line: {
		args: [FFIType.ptr, FFIType.i32],
		returns: FFIType.i32,
	},
	ocsv_set_to_line: {
		args: [FFIType.ptr, FFIType.i32],
		returns: FFIType.i32,
	},
	ocsv_set_skip_lines_with_error: {
		args: [FFIType.ptr, FFIType.bool],
		returns: FFIType.i32,
	},
	// Error getters (Phase 1)
	ocsv_has_error: {
		args: [FFIType.ptr],
		returns: FFIType.bool,
	},
	ocsv_get_error_code: {
		args: [FFIType.ptr],
		returns: FFIType.i32,
	},
	ocsv_get_error_line: {
		args: [FFIType.ptr],
		returns: FFIType.i32,
	},
	ocsv_get_error_column: {
		args: [FFIType.ptr],
		returns: FFIType.i32,
	},
	ocsv_get_error_message: {
		args: [FFIType.ptr],
		returns: FFIType.cstring,
	},
	ocsv_get_error_count: {
		args: [FFIType.ptr],
		returns: FFIType.i32,
	},
	// Bulk extraction methods (Phase 1 & 2)
	ocsv_rows_to_json: {
		args: [FFIType.ptr],
		returns: FFIType.cstring,
	},
	ocsv_rows_to_packed_buffer: {
		args: [FFIType.ptr, FFIType.ptr],
		returns: FFIType.ptr,
	},
});

/**
 * Deserialize packed binary buffer to 2D array (internal helper)
 * @private
 * @param {bigint|number} bufferPtr - Pointer to packed buffer
 * @param {number} bufferSize - Size of buffer in bytes
 * @returns {string[][]} 2D array of strings [row][field]
 */
function _deserializePackedBuffer(bufferPtr, bufferSize) {
	// Convert pointer to ArrayBuffer (zero-copy)
	const arrayBuffer = toArrayBuffer(bufferPtr, 0, bufferSize);
	const view = new DataView(arrayBuffer);
	const bytes = new Uint8Array(arrayBuffer);

	// Read header
	const magic = view.getUint32(0, true);
	if (magic !== 0x4F435356) {  // "OCSV"
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
	const rows = new Array(rowCount);
	const decoder = new TextDecoder('utf-8');

	for (let i = 0; i < rowCount; i++) {
		const row = new Array(fieldCount);
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
 * Configuration options for CSV parsing
 * @typedef {Object} ParseOptions
 * @property {string} [delimiter=','] - Field delimiter character
 * @property {string} [quote='"'] - Quote character for escaping
 * @property {string} [escape='"'] - Escape character
 * @property {boolean} [skipEmptyLines=false] - Skip empty lines
 * @property {string} [comment='#'] - Comment line prefix (use empty string to disable)
 * @property {boolean} [trim=false] - Trim whitespace from fields
 * @property {boolean} [relaxed=false] - Enable relaxed parsing mode (allows some RFC violations)
 * @property {number} [maxRowSize=1048576] - Maximum row size in bytes (default: 1MB)
 * @property {number} [fromLine=0] - Start parsing from line N (0 = start from beginning)
 * @property {number} [toLine=-1] - Stop parsing at line N (-1 = parse all lines)
 * @property {boolean} [skipLinesWithError=false] - Skip lines that fail to parse
 * @property {boolean} [hasHeader=false] - Whether the first row is a header
 * @property {string} [mode='auto'] - Parsing mode: 'auto' (default), 'packed', 'bulk', 'field', or 'lazy'
 *   - 'auto': Automatically select best mode based on data size (recommended)
 *   - 'packed': Use packed buffer (fastest, 52 MB/s, best for >1K rows)
 *   - 'bulk': Use bulk JSON (fast, 40 MB/s, good for 100-1K rows)
 *   - 'field': Use field-by-field (slower, 30 MB/s, fine for <100 rows)
 *   - 'lazy': Use lazy evaluation (on-demand row access, requires manual cleanup)
 */

/**
 * Result of CSV parsing
 * @typedef {Object} ParseResult
 * @property {string[]} [headers] - Header row (if hasHeader was true)
 * @property {string[][]} rows - Array of rows, each row is an array of fields
 * @property {number} rowCount - Total number of rows parsed (excluding header)
 */

/**
 * CSV Parser class with automatic memory management
 *
 * @example
 * const parser = new Parser();
 * try {
 *   const result = parser.parse('a,b,c\n1,2,3');
 *   console.log(result.rows); // [['a','b','c'], ['1','2','3']]
 * } finally {
 *   parser.destroy();
 * }
 */
export class Parser {
	/**
	 * Create a new CSV parser
	 */
	constructor() {
		this.parser = lib.symbols.ocsv_parser_create();
		if (!this.parser) {
			throw new Error("Failed to create parser");
		}
	}

	/**
	 * Apply configuration options to the parser (Phase 1)
	 * @private
	 * @param {ParseOptions} options - Configuration options
	 */
	_applyConfig(options) {
		if (options.delimiter !== undefined) {
			const code = options.delimiter.charCodeAt(0);
			lib.symbols.ocsv_set_delimiter(this.parser, code);
		}

		if (options.quote !== undefined) {
			const code = options.quote.charCodeAt(0);
			lib.symbols.ocsv_set_quote(this.parser, code);
		}

		if (options.escape !== undefined) {
			const code = options.escape.charCodeAt(0);
			lib.symbols.ocsv_set_escape(this.parser, code);
		}

		if (options.skipEmptyLines !== undefined) {
			lib.symbols.ocsv_set_skip_empty_lines(this.parser, options.skipEmptyLines);
		}

		if (options.comment !== undefined) {
			// Use charCode 0 to disable comments
			const code = options.comment.length > 0 ? options.comment.charCodeAt(0) : 0;
			lib.symbols.ocsv_set_comment(this.parser, code);
		}

		if (options.trim !== undefined) {
			lib.symbols.ocsv_set_trim(this.parser, options.trim);
		}

		if (options.relaxed !== undefined) {
			lib.symbols.ocsv_set_relaxed(this.parser, options.relaxed);
		}

		if (options.maxRowSize !== undefined) {
			lib.symbols.ocsv_set_max_row_size(this.parser, options.maxRowSize);
		}

		if (options.fromLine !== undefined) {
			lib.symbols.ocsv_set_from_line(this.parser, options.fromLine);
		}

		if (options.toLine !== undefined) {
			lib.symbols.ocsv_set_to_line(this.parser, options.toLine);
		}

		if (options.skipLinesWithError !== undefined) {
			lib.symbols.ocsv_set_skip_lines_with_error(this.parser, options.skipLinesWithError);
		}
	}

	/**
	 * Parse a CSV string and return the data
	 * @param {string} data - CSV data to parse
	 * @param {ParseOptions} [options={}] - Parsing options
	 * @returns {ParseResult} Parsed CSV data
	 * @throws {OcsvError} If parsing fails
	 */
	parse(data, options = {}) {
		// Apply configuration before parsing
		this._applyConfig(options);
		const buffer = Buffer.from(data + '\0');
		const parseResult = lib.symbols.ocsv_parse_string(this.parser, ptr(buffer), data.length);

		// Check for errors after parsing
		if (parseResult !== 0 || lib.symbols.ocsv_has_error(this.parser)) {
			const errorCode = lib.symbols.ocsv_get_error_code(this.parser);
			const errorLine = lib.symbols.ocsv_get_error_line(this.parser);
			const errorColumn = lib.symbols.ocsv_get_error_column(this.parser);
			const errorMessage = lib.symbols.ocsv_get_error_message(this.parser) || "CSV parsing failed";
			throw new OcsvError(errorMessage, errorCode, errorLine, errorColumn);
		}

		const rowCount = lib.symbols.ocsv_get_row_count(this.parser);

		// Determine parsing mode
		const mode = options.mode || 'auto';

		// Handle lazy mode (special case - no auto-selection)
		if (mode === 'lazy') {
			return this._parseLazy(rowCount, options);
		}

		// Auto-select best mode based on row count
		let selectedMode = mode;
		if (mode === 'auto') {
			if (rowCount > 1000) {
				selectedMode = 'packed';  // Best for large files
			} else if (rowCount > 100) {
				selectedMode = 'bulk';    // Good for medium files
			} else {
				selectedMode = 'field';   // Fine for small files
			}
		}

		// Execute selected mode
		switch (selectedMode) {
			case 'packed':
				return this._parsePacked();
			case 'bulk':
				return this._parseBulk();
			case 'field':
				return this._parseEager(rowCount, options);
			default:
				// Fallback to eager mode for unknown modes
				return this._parseEager(rowCount, options);
		}
	}

	/**
	 * Parse in lazy mode - returns LazyResult with on-demand row access
	 * @private
	 * @param {number} rowCount - Total number of rows
	 * @param {ParseOptions} options - Parsing options
	 * @returns {LazyResult} Lazy result accessor
	 */
	_parseLazy(rowCount, options) {
		let headers = null;

		// Handle header row if requested
		if (options.hasHeader && rowCount > 0) {
			// Extract headers eagerly using direct FFI
			// This is a small overhead (~50-100μs) but ensures reliability
			const fieldCount = lib.symbols.ocsv_get_field_count(this.parser, 0);
			headers = new Array(fieldCount);
			for (let i = 0; i < fieldCount; i++) {
				headers[i] = lib.symbols.ocsv_get_field(this.parser, 0, i) || "";
			}

			// Create LazyResult starting from row 1 (data rows only)
			// Note: User will call getRow(0) to access first data row
			return new LazyResult(
				this.parser,
				rowCount - 1,  // Exclude header from count
				headers,
				options
			);
		}

		// No header
		return new LazyResult(
			this.parser,
			rowCount,
			null,
			options
		);
	}

	/**
	 * Parse in eager mode - materializes all rows into arrays
	 * @private
	 * @param {number} rowCount - Total number of rows
	 * @param {ParseOptions} options - Parsing options
	 * @returns {ParseResult} Eager result with all rows
	 */
	_parseEager(rowCount, options) {
		const rows = [];

		for (let i = 0; i < rowCount; i++) {
			const fieldCount = lib.symbols.ocsv_get_field_count(this.parser, i);
			const row = [];

			for (let j = 0; j < fieldCount; j++) {
				// ocsv_get_field returns a cstring which Bun automatically converts to string
				const field = lib.symbols.ocsv_get_field(this.parser, i, j);
				row.push(field || "");
			}

			rows.push(row);
		}

		const result = {
			rows,
			rowCount: options.hasHeader ? rowCount - 1 : rowCount,
		};

		if (options.hasHeader && rows.length > 0) {
			result.headers = rows.shift();
		}

		return result;
	}

	/**
	 * Parse using packed buffer format (Phase 2 - fastest)
	 * @private
	 * @returns {ParseResult} Parsed result with all rows
	 */
	_parsePacked() {
		const sizeBuffer = new Int32Array(1);
		const bufferPtr = lib.symbols.ocsv_rows_to_packed_buffer(this.parser, ptr(sizeBuffer));

		if (!bufferPtr || sizeBuffer[0] <= 0) {
			return { rows: [], rowCount: 0 };
		}

		const rows = _deserializePackedBuffer(bufferPtr, sizeBuffer[0]);
		return {
			rows,
			rowCount: rows.length,
		};
	}

	/**
	 * Parse using bulk JSON serialization (Phase 1 - fast)
	 * @private
	 * @returns {ParseResult} Parsed result with all rows
	 */
	_parseBulk() {
		const jsonStr = lib.symbols.ocsv_rows_to_json(this.parser);

		if (!jsonStr) {
			return { rows: [], rowCount: 0 };
		}

		const rows = JSON.parse(jsonStr);
		return {
			rows,
			rowCount: rows.length,
		};
	}

	/**
	 * Parse a CSV file
	 * @param {string} path - Path to CSV file
	 * @param {ParseOptions} [options={}] - Parsing options
	 * @returns {Promise<ParseResult>} Parsed CSV data
	 */
	async parseFile(path, options = {}) {
		const file = Bun.file(path);
		const text = await file.text();
		return this.parse(text, options);
	}

	/**
	 * Destroy the parser and free all memory
	 * Must be called when done with the parser
	 */
	destroy() {
		if (this.parser) {
			lib.symbols.ocsv_parser_destroy(this.parser);
			this.parser = null;
		}
	}
}

/**
 * Convenience function to parse CSV string
 * Automatically manages parser lifecycle (except in lazy mode)
 *
 * @param {string} data - CSV data
 * @param {ParseOptions} [options={}] - Parsing options
 * @returns {ParseResult | LazyResult} Parsed CSV data
 *
 * @example Eager mode (automatic cleanup)
 * import { parseCSV } from 'ocsv';
 *
 * const result = parseCSV('name,age\nJohn,30\nJane,25', { hasHeader: true });
 * console.log(result.headers); // ['name', 'age']
 * console.log(result.rows);    // [['John', '30'], ['Jane', '25']]
 *
 * @example Lazy mode (manual cleanup required)
 * const result = parseCSV(data, { mode: 'lazy' });
 * try {
 *   const row = result.getRow(5000);
 *   console.log(row.toArray());
 * } finally {
 *   result.destroy();  // MUST call destroy()
 * }
 */
export function parseCSV(data, options = {}) {
	const parser = new Parser();

	// Check for lazy mode
	if (options.mode === 'lazy') {
		// IMPORTANT: Do NOT destroy parser!
		// LazyResult owns it now - user must call result.destroy()
		return parser.parse(data, options);
	}

	// Eager mode: cleanup immediately
	try {
		return parser.parse(data, options);
	} finally {
		parser.destroy();
	}
}

/**
 * Convenience function to parse CSV file
 * Automatically manages parser lifecycle
 *
 * @param {string} path - Path to CSV file
 * @param {ParseOptions} [options={}] - Parsing options
 * @returns {Promise<ParseResult>} Parsed CSV data
 *
 * @example
 * import { parseCSVFile } from 'ocsv';
 *
 * const result = await parseCSVFile('./data.csv', { hasHeader: true });
 * console.log(`Parsed ${result.rowCount} rows`);
 */
export async function parseCSVFile(path, options = {}) {
	const parser = new Parser();
	try {
		return await parser.parseFile(path, options);
	} finally {
		parser.destroy();
	}
}

// Export for backwards compatibility
export { Parser as OCSVParser };

// Export advanced performance functions (Phase 2)
export { parseCSVPacked, parseCSVBulk } from "./simple.ts";
