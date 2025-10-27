package ocsv

import "base:runtime"
import "core:c"
import "core:strings"
import "core:fmt"
import "core:encoding/endian"

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

// ============================================================================
// Bulk Memory Access FFI Functions (Performance Optimization)
// ============================================================================
// These functions enable zero-copy or low-FFI-call data extraction

// Helper to escape a string for JSON
json_escape_string :: proc(s: string, builder: ^strings.Builder) {
    strings.write_byte(builder, '"')
    for r in s {
        switch r {
        case '"':  strings.write_string(builder, "\\\"")
        case '\\': strings.write_string(builder, "\\\\")
        case '\b': strings.write_string(builder, "\\b")
        case '\f': strings.write_string(builder, "\\f")
        case '\n': strings.write_string(builder, "\\n")
        case '\r': strings.write_string(builder, "\\r")
        case '\t': strings.write_string(builder, "\\t")
        case:
            if r < 0x20 {
                // Control character - use \u escape
                fmt.sbprintf(builder, "\\u%04x", r)
            } else {
                strings.write_rune(builder, r)
            }
        }
    }
    strings.write_byte(builder, '"')
}

// ocsv_rows_to_json serializes all rows to JSON format
// Parameters:
//   parser: pointer to Parser
// Returns: cstring containing JSON array of arrays, or nil on error
// Note: The returned string is owned by the parser and valid until parser_destroy
//
// Example output: [["name","age"],["Alice","30"],["Bob","25"]]
@(export, link_name="ocsv_rows_to_json")
ocsv_rows_to_json :: proc "c" (parser: ^Parser) -> cstring {
    context = runtime.default_context()

    if parser == nil || len(parser.all_rows) == 0 {
        return "[]"
    }

    // Build JSON string manually for performance
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    strings.write_byte(&builder, '[')

    for row, row_idx in parser.all_rows {
        if row_idx > 0 {
            strings.write_byte(&builder, ',')
        }

        strings.write_byte(&builder, '[')

        for field, field_idx in row {
            if field_idx > 0 {
                strings.write_byte(&builder, ',')
            }
            json_escape_string(field, &builder)
        }

        strings.write_byte(&builder, ']')
    }

    strings.write_byte(&builder, ']')

    // Convert to cstring - clone to parser's allocator so it persists
    json_str := strings.to_string(builder)
    json_clone := strings.clone(json_str)

    // Store in parser for memory management
    // We'll add a field to store this, or just return the cstring directly
    // For now, return directly (caller must copy before next call)
    return cstring(raw_data(json_clone))
}

// ocsv_free_json_string frees a JSON string allocated by ocsv_rows_to_json
// Parameters:
//   json_str: cstring returned by ocsv_rows_to_json
@(export, link_name="ocsv_free_json_string")
ocsv_free_json_string :: proc "c" (json_str: cstring) {
    context = runtime.default_context()

    if json_str == nil {
        return
    }

    // Free the cloned string
    delete(cstring_to_string(json_str))
}

// Helper to convert cstring to string
cstring_to_string :: proc(s: cstring) -> string {
    if s == nil {
        return ""
    }
    return string(s)
}

// ============================================================================
// Phase 2: Packed Buffer Serialization (Zero-Copy Performance)
// ============================================================================
// These functions serialize CSV data to a packed binary format for minimal
// FFI overhead and zero-copy deserialization in JavaScript.
//
// Binary Format:
//   Header (24 bytes):
//     0-3:   magic (0x4F435356 "OCSV")
//     4-7:   version (1)
//     8-11:  row_count (u32)
//     12-15: field_count (u32)
//     16-23: total_bytes (u64)
//
//   Row Offsets (row_count × 4 bytes):
//     24+i*4: offset to row i data
//
//   Field Data (variable length):
//     [length: u16][data: UTF-8 bytes]

// calculate_packed_buffer_size calculates total buffer size needed for packed format
// Parameters:
//   rows: array of CSV rows (each row is array of strings)
// Returns: total size in bytes
calculate_packed_buffer_size :: proc(rows: [][]string) -> int {
    size := 24  // Header (24 bytes)
    size += len(rows) * 4  // Row offsets array (4 bytes per row)

    // Calculate field data size
    for row in rows {
        for field in row {
            size += 2           // u16 length prefix per field
            size += len(field)  // UTF-8 bytes
        }
    }

    return size
}

// write_header writes the 24-byte header to the buffer
// Parameters:
//   buffer: dynamic byte array to write to
//   rows: array of CSV rows
//   total_bytes: total buffer size
write_header :: proc(buffer: ^[dynamic]u8, rows: [][]string, total_bytes: int) {
    header: [24]u8

    // Magic: "OCSV" (0x4F435356)
    endian.put_u32(header[0:4], .Little, 0x4F435356)

    // Version: 1
    endian.put_u32(header[4:8], .Little, 1)

    // Row count
    endian.put_u32(header[8:12], .Little, u32(len(rows)))

    // Field count (assume all rows have same number of fields as first row)
    field_count := len(rows) > 0 ? len(rows[0]) : 0
    endian.put_u32(header[12:16], .Little, u32(field_count))

    // Total bytes
    endian.put_u64(header[16:24], .Little, u64(total_bytes))

    append(buffer, ..header[:])
}

// write_row_offsets writes the row offset array to the buffer
// Parameters:
//   buffer: dynamic byte array to write to
//   rows: array of CSV rows
// Returns: array of computed offsets (for reference)
write_row_offsets :: proc(buffer: ^[dynamic]u8, rows: [][]string) -> []u32 {
    offsets := make([]u32, len(rows))

    // Calculate offsets
    // First row starts after header + offset array
    current_offset := 24 + len(rows) * 4

    for row, i in rows {
        offsets[i] = u32(current_offset)

        // Calculate size of this row's data
        for field in row {
            current_offset += 2           // u16 length prefix
            current_offset += len(field)  // UTF-8 bytes
        }
    }

    // Write offsets to buffer
    offset_bytes: [4]u8
    for offset in offsets {
        endian.put_u32(offset_bytes[:], .Little, offset)
        append(buffer, ..offset_bytes[:])
    }

    return offsets
}

// write_field_data writes all field data to the buffer
// Parameters:
//   buffer: dynamic byte array to write to
//   rows: array of CSV rows
write_field_data :: proc(buffer: ^[dynamic]u8, rows: [][]string) {
    len_bytes: [2]u8

    for row in rows {
        for field in row {
            // Write length as u16 little-endian
            field_len := u16(len(field))
            endian.put_u16(len_bytes[:], .Little, field_len)
            append(buffer, ..len_bytes[:])

            // Write UTF-8 bytes
            if len(field) > 0 {
                append(buffer, ..transmute([]u8)field)
            }
        }
    }
}

// pack_rows_to_buffer serializes all rows to packed binary format
// Parameters:
//   parser: pointer to Parser
// Returns: byte slice containing packed data (stored in parser.packed_buffer)
pack_rows_to_buffer :: proc(parser: ^Parser) -> []u8 {
    if len(parser.all_rows) == 0 {
        return nil
    }

    // Calculate total size
    total_size := calculate_packed_buffer_size(parser.all_rows[:])

    // Allocate buffer
    buffer := make([dynamic]u8, 0, total_size)

    // Write header
    write_header(&buffer, parser.all_rows[:], total_size)

    // Write row offsets
    _ = write_row_offsets(&buffer, parser.all_rows[:])  // offsets computed inline

    // Write field data
    write_field_data(&buffer, parser.all_rows[:])

    // Convert to slice and store in parser
    result := buffer[:]
    parser.packed_buffer = result

    return result
}

// ocsv_rows_to_packed_buffer serializes all rows to packed binary format
// Parameters:
//   parser: pointer to Parser
//   out_size: pointer to int where buffer size will be written
// Returns: pointer to packed buffer, or nil on error
// Note: The returned buffer is owned by the parser and valid until parser_destroy
//
// Binary format specification:
//   See comments above for detailed format description
@(export, link_name="ocsv_rows_to_packed_buffer")
ocsv_rows_to_packed_buffer :: proc "c" (parser: ^Parser, out_size: ^c.int) -> ^u8 {
    context = runtime.default_context()

    if parser == nil || out_size == nil {
        return nil
    }

    // Handle empty data
    if len(parser.all_rows) == 0 {
        out_size^ = 0
        return nil
    }

    // Pack rows to buffer
    buffer := pack_rows_to_buffer(parser)

    if len(buffer) == 0 {
        out_size^ = 0
        return nil
    }

    // Return pointer and size
    out_size^ = c.int(len(buffer))
    return raw_data(buffer)
}
