/**
 * OcsvError - Custom error class for CSV parsing errors
 * Provides detailed error information including line and column numbers
 */
export class OcsvError extends Error {
  /**
   * Create a new OcsvError
   * @param {string} message - Error message
   * @param {number} code - Error code (from Parse_Error enum)
   * @param {number} line - Line number where error occurred (1-indexed)
   * @param {number} column - Column number where error occurred (1-indexed)
   */
  constructor(message, code, line, column) {
    super(message);

    this.name = 'OcsvError';
    this.code = code;
    this.line = line;
    this.column = column;

    // Capture stack trace (V8-specific, available in Node.js/Bun)
    // Use optional chaining for compatibility with other engines (Safari, Firefox)
    Error.captureStackTrace?.(this, OcsvError);
  }

  /**
   * Get a formatted error message with line and column information
   * @returns {string} Formatted error message
   */
  toString() {
    return `${this.name}: ${this.message} at line ${this.line}, column ${this.column}`;
  }

  /**
   * Get error code name from numeric code
   * @returns {string} Error code name
   */
  getCodeName() {
    const codeNames = {
      0: 'None',
      1: 'File_Not_Found',
      2: 'Invalid_UTF8',
      3: 'Unterminated_Quote',
      4: 'Invalid_Character_After_Quote',
      5: 'Max_Row_Size_Exceeded',
      6: 'Max_Field_Size_Exceeded',
      7: 'Inconsistent_Column_Count',
      8: 'Invalid_Escape_Sequence',
      9: 'Empty_Input',
      10: 'Memory_Allocation_Failed',
    };
    return codeNames[this.code] || 'Unknown';
  }
}

/**
 * Parse_Error enum values matching Odin Parse_Error enum
 */
export const ParseErrorCode = {
  None: 0,
  File_Not_Found: 1,
  Invalid_UTF8: 2,
  Unterminated_Quote: 3,
  Invalid_Character_After_Quote: 4,
  Max_Row_Size_Exceeded: 5,
  Max_Field_Size_Exceeded: 6,
  Inconsistent_Column_Count: 7,
  Invalid_Escape_Sequence: 8,
  Empty_Input: 9,
  Memory_Allocation_Failed: 10,
};
