/**
 * OCSV - High-performance CSV Parser
 *
 * A fast, RFC 4180 compliant CSV parser written in Odin with Bun FFI bindings.
 * Achieves 66.67 MB/s throughput with zero memory leaks.
 *
 * @module ocsv
 */

import { dlopen, FFIType, ptr } from "bun:ffi";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { existsSync } from "fs";
import os from "os";
import { OcsvError, ParseErrorCode } from "./errors.js";
import { LazyRow, LazyResult } from "./lazy.js";

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
});

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

		// Check for lazy mode
		if (options.mode === 'lazy') {
			return this._parseLazy(rowCount, options);
		}

		// Default: eager mode
		return this._parseEager(rowCount, options);
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
			const headerRow = new LazyRow(this.parser, 0);
			headers = headerRow.toArray();

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

// Export error handling classes (Phase 1)
export { OcsvError, ParseErrorCode };

// Export lib for internal use by lazy.js
export { lib };
