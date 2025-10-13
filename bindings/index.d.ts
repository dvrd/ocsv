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
	 * Comment line prefix
	 * @default '#'
	 */
	comment?: string;

	/**
	 * Whether the first row is a header
	 * @default false
	 */
	hasHeader?: boolean;

	/**
	 * Enable relaxed parsing mode (allows some RFC violations)
	 * @default false
	 */
	relaxed?: boolean;
}

/**
 * Result of CSV parsing
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
	 * Parse a CSV string and return the data
	 * @param data - CSV data to parse
	 * @param options - Parsing options
	 * @returns Parsed CSV data
	 * @throws Error if parsing fails
	 */
	parse(data: string, options?: ParseOptions): ParseResult;

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
 * Automatically manages parser lifecycle
 *
 * @param data - CSV data
 * @param options - Parsing options
 * @returns Parsed CSV data
 *
 * @example
 * ```typescript
 * import { parseCSV } from 'ocsv';
 *
 * const result = parseCSV('name,age\nJohn,30\nJane,25', { hasHeader: true });
 * console.log(result.headers); // ['name', 'age']
 * console.log(result.rows);    // [['John', '30'], ['Jane', '25']]
 * ```
 */
export function parseCSV(data: string, options?: ParseOptions): ParseResult;

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
