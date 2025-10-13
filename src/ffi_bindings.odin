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
