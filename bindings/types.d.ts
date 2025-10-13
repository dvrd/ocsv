/**
 * OCSV - TypeScript Type Definitions
 */

/**
 * Main CSV parser class
 */
export class OcsvParser {
  /**
   * Create a new CSV parser
   */
  constructor();

  /**
   * Parse a CSV string
   * @param data - CSV data to parse
   * @returns Number of rows parsed
   * @throws Error if parsing fails
   */
  parseString(data: string): number;

  /**
   * Get the number of rows parsed
   * @returns Number of rows
   */
  getRowCount(): number;

  /**
   * Get the number of fields in a specific row
   * @param rowIndex - Row index (0-based)
   * @returns Number of fields in the row
   */
  getFieldCount(rowIndex: number): number;

  /**
   * Parse a file
   * @param path - Path to CSV file
   * @returns Promise resolving to number of rows parsed
   */
  parseFile(path: string): Promise<number>;

  /**
   * Destroy the parser and free all memory
   * Must be called when done with the parser
   */
  destroy(): void;
}

/**
 * Convenience function to parse CSV string
 * @param data - CSV data
 * @returns Number of rows parsed
 */
export function parseCSV(data: string): number;

/**
 * Convenience function to parse CSV file
 * @param path - Path to CSV file
 * @returns Promise resolving to number of rows parsed
 */
export function parseCSVFile(path: string): Promise<number>;
