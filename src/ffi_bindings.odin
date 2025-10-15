package ocsv

import "base:runtime"
import "core:c"

// FFI Bindings for Bun
// These functions are exported with C ABI for use with Bun's FFI

// ocsv_parser_create creates a new parser instance
// Returns: pointer to Parser
@(export, link_name="ocsv_parser_create")
ocsv_parser_create :: proc "c" () -> ^Parser {
    context = runtime.default_context()
    return parser_create()
}

// ocsv_parser_destroy destroys a parser instance and frees all memory
// Parameters:
//   parser: pointer to Parser to destroy
@(export, link_name="ocsv_parser_destroy")
ocsv_parser_destroy :: proc "c" (parser: ^Parser) {
    context = runtime.default_context()
    parser_destroy(parser)
}

// ocsv_parse_string parses a CSV string
// Parameters:
//   parser: pointer to Parser
//   data: C string containing CSV data
//   len: length of the data in bytes
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_parse_string")
ocsv_parse_string :: proc "c" (parser: ^Parser, data: cstring, len: c.int) -> c.int {
    // Set up context with allocator
    context = runtime.default_context()

    // Validate inputs
    if parser == nil || data == nil || len < 0 {
        return -1
    }

    // Handle empty string
    if len == 0 {
        return 0
    }

    // Convert cstring to string safely
    data_bytes := transmute([^]u8)data
    data_str := string(data_bytes[:len])

    ok := parse_simple_csv(parser, data_str)
    return ok ? 0 : -1
}

// ocsv_get_row_count returns the number of rows parsed
// Parameters:
//   parser: pointer to Parser
// Returns: number of rows
@(export, link_name="ocsv_get_row_count")
ocsv_get_row_count :: proc "c" (parser: ^Parser) -> c.int {
    context = runtime.default_context()
    return c.int(len(parser.all_rows))
}

// ocsv_get_row gets a specific row by index
// Parameters:
//   parser: pointer to Parser
//   row_index: row index (0-based)
// Returns: pointer to first field in row (array of strings)
// Note: This is a simplified version. Full implementation in PRP-01
@(export, link_name="ocsv_get_row")
ocsv_get_row :: proc "c" (parser: ^Parser, row_index: c.int) -> [^]cstring {
    context = runtime.default_context()

    if row_index < 0 || int(row_index) >= len(parser.all_rows) {
        return nil
    }

    // Note: This is a simplified placeholder
    // Full implementation will properly marshal strings
    return nil
}

// ocsv_get_field_count gets the number of fields in a specific row
// Parameters:
//   parser: pointer to Parser
//   row_index: row index (0-based)
// Returns: number of fields in the row, or -1 if invalid index
@(export, link_name="ocsv_get_field_count")
ocsv_get_field_count :: proc "c" (parser: ^Parser, row_index: c.int) -> c.int {
    context = runtime.default_context()

    if row_index < 0 || int(row_index) >= len(parser.all_rows) {
        return -1
    }

    return c.int(len(parser.all_rows[row_index]))
}

// ocsv_get_field gets a specific field value from a row
// Parameters:
//   parser: pointer to Parser
//   row_index: row index (0-based)
//   field_index: field index (0-based)
// Returns: cstring containing the field value, or nil if invalid indices
@(export, link_name="ocsv_get_field")
ocsv_get_field :: proc "c" (parser: ^Parser, row_index: c.int, field_index: c.int) -> cstring {
    context = runtime.default_context()

    if row_index < 0 || int(row_index) >= len(parser.all_rows) {
        return nil
    }

    row := parser.all_rows[row_index]
    if field_index < 0 || int(field_index) >= len(row) {
        return nil
    }

    // Return the field as cstring
    // Note: This is safe because the strings are managed by the parser
    // and will remain valid until parser_destroy is called
    return cstring(raw_data(row[field_index]))
}

// ============================================================================
// Configuration Setter FFI Functions
// ============================================================================
// These functions allow JavaScript to configure the parser before parsing

// ocsv_set_delimiter sets the field delimiter character
// Parameters:
//   parser: pointer to Parser
//   delimiter: delimiter character (e.g., ',' or '\t')
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_delimiter")
ocsv_set_delimiter :: proc "c" (parser: ^Parser, delimiter: c.uchar) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.delimiter = byte(delimiter)
    return 0
}

// ocsv_set_quote sets the quote character
// Parameters:
//   parser: pointer to Parser
//   quote: quote character (typically '"')
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_quote")
ocsv_set_quote :: proc "c" (parser: ^Parser, quote: c.uchar) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.quote = byte(quote)
    return 0
}

// ocsv_set_escape sets the escape character
// Parameters:
//   parser: pointer to Parser
//   escape: escape character (typically '"')
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_escape")
ocsv_set_escape :: proc "c" (parser: ^Parser, escape: c.uchar) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.escape = byte(escape)
    return 0
}

// ocsv_set_skip_empty_lines enables or disables skipping empty lines
// Parameters:
//   parser: pointer to Parser
//   skip: true to skip empty lines, false to include them
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_skip_empty_lines")
ocsv_set_skip_empty_lines :: proc "c" (parser: ^Parser, skip: c.bool) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.skip_empty_lines = bool(skip)
    return 0
}

// ocsv_set_comment sets the comment character
// Parameters:
//   parser: pointer to Parser
//   comment: comment character (typically '#', use 0 to disable)
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_comment")
ocsv_set_comment :: proc "c" (parser: ^Parser, comment: c.uchar) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.comment = byte(comment)
    return 0
}

// ocsv_set_trim enables or disables trimming whitespace from fields
// Parameters:
//   parser: pointer to Parser
//   trim: true to trim whitespace, false to preserve it
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_trim")
ocsv_set_trim :: proc "c" (parser: ^Parser, trim: c.bool) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.trim = bool(trim)
    return 0
}

// ocsv_set_relaxed enables or disables relaxed parsing mode
// Parameters:
//   parser: pointer to Parser
//   relaxed: true for relaxed mode (allow RFC violations), false for strict
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_relaxed")
ocsv_set_relaxed :: proc "c" (parser: ^Parser, relaxed: c.bool) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.relaxed = bool(relaxed)
    return 0
}

// ocsv_set_max_row_size sets the maximum row size in bytes
// Parameters:
//   parser: pointer to Parser
//   max_size: maximum row size (e.g., 1048576 for 1MB)
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_max_row_size")
ocsv_set_max_row_size :: proc "c" (parser: ^Parser, max_size: c.int) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.max_row_size = int(max_size)
    return 0
}

// ocsv_set_from_line sets the line number to start parsing from
// Parameters:
//   parser: pointer to Parser
//   from_line: line number to start from (0 = start from beginning)
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_from_line")
ocsv_set_from_line :: proc "c" (parser: ^Parser, from_line: c.int) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.from_line = int(from_line)
    return 0
}

// ocsv_set_to_line sets the line number to stop parsing at
// Parameters:
//   parser: pointer to Parser
//   to_line: line number to stop at (-1 = parse to end)
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_to_line")
ocsv_set_to_line :: proc "c" (parser: ^Parser, to_line: c.int) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.to_line = int(to_line)
    return 0
}

// ocsv_set_skip_lines_with_error enables or disables skipping lines with errors
// Parameters:
//   parser: pointer to Parser
//   skip: true to skip lines with errors, false to fail on error
// Returns: 0 on success, -1 on error
@(export, link_name="ocsv_set_skip_lines_with_error")
ocsv_set_skip_lines_with_error :: proc "c" (parser: ^Parser, skip: c.bool) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return -1
    }

    parser.config.skip_lines_with_error = bool(skip)
    return 0
}

// ============================================================================
// Error Getter FFI Functions
// ============================================================================
// These functions allow JavaScript to retrieve error information after parsing

// ocsv_has_error checks if the parser encountered an error
// Parameters:
//   parser: pointer to Parser
// Returns: true if error exists, false otherwise
@(export, link_name="ocsv_has_error")
ocsv_has_error :: proc "c" (parser: ^Parser) -> c.bool {
    context = runtime.default_context()

    if parser == nil {
        return false
    }

    return c.bool(parser.last_error.code != .None)
}

// ocsv_get_error_code returns the error code of the last error
// Parameters:
//   parser: pointer to Parser
// Returns: error code as integer (0 = None, 1 = File_Not_Found, etc.)
@(export, link_name="ocsv_get_error_code")
ocsv_get_error_code :: proc "c" (parser: ^Parser) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return 0
    }

    return c.int(parser.last_error.code)
}

// ocsv_get_error_line returns the line number where the error occurred
// Parameters:
//   parser: pointer to Parser
// Returns: line number (1-indexed), or 0 if no error
@(export, link_name="ocsv_get_error_line")
ocsv_get_error_line :: proc "c" (parser: ^Parser) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return 0
    }

    return c.int(parser.last_error.line)
}

// ocsv_get_error_column returns the column number where the error occurred
// Parameters:
//   parser: pointer to Parser
// Returns: column number (1-indexed), or 0 if no error
@(export, link_name="ocsv_get_error_column")
ocsv_get_error_column :: proc "c" (parser: ^Parser) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return 0
    }

    return c.int(parser.last_error.column)
}

// ocsv_get_error_message returns the error message
// Parameters:
//   parser: pointer to Parser
// Returns: cstring containing error message, or empty string if no error
// Note: The returned string is owned by the parser and valid until parser_destroy
@(export, link_name="ocsv_get_error_message")
ocsv_get_error_message :: proc "c" (parser: ^Parser) -> cstring {
    context = runtime.default_context()

    if parser == nil {
        return ""
    }

    if parser.last_error.code == .None {
        return ""
    }

    return cstring(raw_data(parser.last_error.message))
}

// ocsv_get_error_count returns the total number of errors encountered
// Parameters:
//   parser: pointer to Parser
// Returns: number of errors
@(export, link_name="ocsv_get_error_count")
ocsv_get_error_count :: proc "c" (parser: ^Parser) -> c.int {
    context = runtime.default_context()

    if parser == nil {
        return 0
    }

    return c.int(parser.error_count)
}
