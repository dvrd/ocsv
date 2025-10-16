/**
 * OCSV - High-performance CSV Parser
 * TypeScript Type Definitions
 */

/**
 * Configuration options for CSV parsing
 */
export interface ParseOptions {
	/**
	 * Field delimiter character
	 * @default ','
	 */
	delimiter?: string;

	/**
	 * Quote character for escaping
	 * @default '"'
	 */
	quote?: string;

	/**
	 * Escape character
	 * @default '"'
	 */
	escape?: string;

	/**
	 * Skip empty lines
	 * @default false
	 */
	skipEmptyLines?: boolean;

	/**
	 * Comment line prefix (use empty string to disable)
	 * @default '#'
	 */
	comment?: string;

	/**
	 * Trim whitespace from fields
	 * @default false
	 */
	trim?: boolean;

	/**
	 * Enable relaxed parsing mode (allows some RFC violations)
	 * @default false
	 */
	relaxed?: boolean;

	/**
	 * Maximum row size in bytes
	 * @default 1048576 (1MB)
	 */
	maxRowSize?: number;

	/**
	 * Start parsing from line N (0 = start from beginning)
	 * @default 0
	 */
	fromLine?: number;

	/**
	 * Stop parsing at line N (-1 = parse all lines)
	 * @default -1
	 */
	toLine?: number;

	/**
	 * Skip lines that fail to parse
	 * @default false
	 */
	skipLinesWithError?: boolean;

	/**
	 * Whether the first row is a header
	 * @default false
	 */
	hasHeader?: boolean;

	/**
	 * Access mode for parsed data
	 * - 'eager': Materialize all rows into arrays (default, backwards compatible)
	 * - 'lazy': On-demand row access with minimal memory (requires manual cleanup)
	 * @default 'eager'
	 */
	mode?: 'eager' | 'lazy';
}

/**
 * Lazy row accessor - fields loaded on-demand from native memory
 *
 * @example
 * ```typescript
 * const row = result.getRow(100);
 * console.log(row.get(0));      // Access field 0
 * console.log([...row]);        // Iterate all fields
 * console.log(row.toArray());   // Materialize to array
 * ```
 */
export class LazyRow implements Iterable<string> {
	/** Number of fields in this row */
	readonly length: number;

	/**
	 * Access a field by index
	 * @param fieldIndex - 0-based field index
	 * @returns Field value as string
	 * @throws {RangeError} If index out of bounds
	 */
	get(fieldIndex: number): string;

	/** Iterate over all fields */
	[Symbol.iterator](): Iterator<string>;

	/** Materialize all fields to array */
	toArray(): string[];

	/** Map over fields */
	map<T>(fn: (field: string, index: number) => T): T[];

	/** Filter fields */
	filter(fn: (field: string, index: number) => boolean): string[];

	/** Slice fields */
	slice(start?: number, end?: number): string[];
}

/**
 * Lazy result accessor - rows loaded on-demand from native memory
 *
 * CRITICAL: Must call destroy() when done to free native memory
 *
 * @example
 * ```typescript
 * const result = parseCSV(data, { mode: 'lazy' });
 * try {
 *   for (const row of result) {
 *     console.log(row.toArray());
 *   }
 * } finally {
 *   result.destroy();  // MUST cleanup
 * }
 * ```
 */
export class LazyResult implements Iterable<LazyRow> {
	/** Total number of data rows (excluding header) */
	readonly rowCount: number;

	/** Header row if hasHeader option was true */
	readonly headers?: string[];

	/**
	 * Access a row by index
	 * @param index - 0-based row index
	 * @returns Lazy row accessor
	 * @throws {RangeError} If index out of bounds
	 * @throws {Error} If result has been destroyed
	 */
	getRow(index: number): LazyRow;

	/** Iterate over all rows */
	[Symbol.iterator](): Iterator<LazyRow>;

	/**
	 * Iterate over a range of rows (lazy)
	 * @param start - Start index (inclusive)
	 * @param end - End index (exclusive)
	 * @returns Generator yielding LazyRow objects
	 */
	slice(start?: number, end?: number): Generator<LazyRow, void, undefined>;

	/**
	 * Materialize all rows to arrays
	 * WARNING: May consume large amounts of memory
	 */
	toArray(): string[][];

	/**
	 * Free native memory
	 * MUST be called when done with lazy result
	 */
	destroy(): void;
}

/**
 * Eager mode result (default)
 */
export interface ParseResult {
	/**
	 * Header row (only present if hasHeader option was true)
	 */
	headers?: string[];

	/**
	 * Array of rows, each row is an array of field values
	 */
	rows: string[][];

	/**
	 * Total number of data rows parsed (excluding header)
	 */
	rowCount: number;
}

/**
 * Parse error codes matching Odin Parse_Error enum
 */
export enum ParseErrorCode {
	None = 0,
	File_Not_Found = 1,
	Invalid_UTF8 = 2,
	Unterminated_Quote = 3,
	Invalid_Character_After_Quote = 4,
	Max_Row_Size_Exceeded = 5,
	Max_Field_Size_Exceeded = 6,
	Inconsistent_Column_Count = 7,
	Invalid_Escape_Sequence = 8,
	Empty_Input = 9,
	Memory_Allocation_Failed = 10,
}

/**
 * Custom error class for CSV parsing errors
 * Provides detailed error information including line and column numbers
 */
export class OcsvError extends Error {
	/** Error code from ParseErrorCode enum */
	code: number;

	/** Line number where error occurred (1-indexed) */
	line: number;

	/** Column number where error occurred (1-indexed) */
	column: number;

	/**
	 * Create a new OcsvError
	 * @param message - Error message
	 * @param code - Error code from ParseErrorCode enum
	 * @param line - Line number where error occurred
	 * @param column - Column number where error occurred
	 */
	constructor(message: string, code: number, line: number, column: number);

	/**
	 * Get a formatted error message with line and column information
	 */
	toString(): string;

	/**
	 * Get error code name from numeric code
	 */
	getCodeName(): string;
}

/**
 * CSV Parser class with automatic memory management
 *
 * @example
 * ```typescript
 * const parser = new Parser();
 * try {
 *   const result = parser.parse('a,b,c\n1,2,3');
 *   console.log(result.rows); // [['a','b','c'], ['1','2','3']]
 * } finally {
 *   parser.destroy();
 * }
 * ```
 */
export class Parser {
	/**
	 * Create a new CSV parser
	 */
	constructor();

	/**
	 * Parse a CSV string in eager mode (default)
	 * @param data - CSV data to parse
	 * @param options - Parsing options (mode defaults to 'eager')
	 * @returns Parsed CSV data with all rows materialized
	 * @throws {OcsvError} If parsing fails with detailed error information
	 */
	parse(data: string, options?: ParseOptions & { mode?: 'eager' }): ParseResult;

	/**
	 * Parse a CSV string in lazy mode
	 * @param data - CSV data to parse
	 * @param options - Parsing options with mode='lazy'
	 * @returns Lazy result accessor (requires manual destroy)
	 * @throws {OcsvError} If parsing fails with detailed error information
	 */
	parse(data: string, options: ParseOptions & { mode: 'lazy' }): LazyResult;

	/**
	 * Parse a CSV file
	 * @param path - Path to CSV file
	 * @param options - Parsing options
	 * @returns Promise resolving to parsed CSV data
	 */
	parseFile(path: string, options?: ParseOptions): Promise<ParseResult>;

	/**
	 * Destroy the parser and free all memory
	 * Must be called when done with the parser
	 */
	destroy(): void;
}

/**
 * Convenience function to parse CSV string
 * Automatically manages parser lifecycle (except in lazy mode)
 *
 * @param data - CSV data
 * @param options - Parsing options
 * @returns Parsed CSV data
 *
 * @example Eager mode (automatic cleanup)
 * ```typescript
 * import { parseCSV } from 'ocsv';
 *
 * const result = parseCSV('name,age\nJohn,30\nJane,25', { hasHeader: true });
 * console.log(result.headers); // ['name', 'age']
 * console.log(result.rows);    // [['John', '30'], ['Jane', '25']]
 * ```
 *
 * @example Lazy mode (manual cleanup required)
 * ```typescript
 * const result = parseCSV(data, { mode: 'lazy' });
 * try {
 *   const row = result.getRow(5000);
 *   console.log(row.toArray());
 * } finally {
 *   result.destroy();  // MUST call destroy()
 * }
 * ```
 */
export function parseCSV(data: string, options?: ParseOptions & { mode?: 'eager' }): ParseResult;

/**
 * Convenience function to parse CSV string in lazy mode
 *
 * @param data - CSV data
 * @param options - Parsing options with mode='lazy'
 * @returns Lazy result accessor (requires manual destroy)
 */
export function parseCSV(data: string, options: ParseOptions & { mode: 'lazy' }): LazyResult;

/**
 * Convenience function to parse CSV file
 * Automatically manages parser lifecycle
 *
 * @param path - Path to CSV file
 * @param options - Parsing options
 * @returns Promise resolving to parsed CSV data
 *
 * @example
 * ```typescript
 * import { parseCSVFile } from 'ocsv';
 *
 * const result = await parseCSVFile('./data.csv', { hasHeader: true });
 * console.log(`Parsed ${result.rowCount} rows`);
 * ```
 */
export function parseCSVFile(
	path: string,
	options?: ParseOptions
): Promise<ParseResult>;

/**
 * Alias for Parser class (backwards compatibility)
 * @deprecated Use Parser instead
 */
export { Parser as OCSVParser };
