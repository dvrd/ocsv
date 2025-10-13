package ocsv

// Error handling and recovery for CSV parsing
// Provides clear error messages with line/column information

import "core:fmt"

// Parse_Error represents the type of parsing error that occurred
Parse_Error :: enum {
    None,                      // No error
    File_Not_Found,           // File could not be read
    Invalid_UTF8,             // Invalid UTF-8 encoding
    Unterminated_Quote,       // Quoted field not properly closed
    Invalid_Character_After_Quote, // Invalid character after closing quote
    Max_Row_Size_Exceeded,    // Row exceeds maximum size
    Max_Field_Size_Exceeded,  // Field exceeds maximum size
    Inconsistent_Column_Count, // Row has different number of columns
    Invalid_Escape_Sequence,  // Invalid escape sequence
    Empty_Input,              // Input data is empty
    Memory_Allocation_Failed, // Failed to allocate memory
}

// Error_Info contains detailed information about a parsing error
Error_Info :: struct {
    code:    Parse_Error,     // Error code
    line:    int,             // Line number where error occurred (1-indexed)
    column:  int,             // Column number where error occurred (1-indexed)
    message: string,          // Human-readable error message
    ctx:     string,          // Context around the error (e.g., problematic text)
}

// error_to_string converts an error code to a human-readable string
error_to_string :: proc(err: Parse_Error) -> string {
    switch err {
    case .None:
        return "No error"
    case .File_Not_Found:
        return "File not found"
    case .Invalid_UTF8:
        return "Invalid UTF-8 encoding"
    case .Unterminated_Quote:
        return "Unterminated quoted field"
    case .Invalid_Character_After_Quote:
        return "Invalid character after closing quote"
    case .Max_Row_Size_Exceeded:
        return "Row size exceeds maximum"
    case .Max_Field_Size_Exceeded:
        return "Field size exceeds maximum"
    case .Inconsistent_Column_Count:
        return "Inconsistent number of columns"
    case .Invalid_Escape_Sequence:
        return "Invalid escape sequence"
    case .Empty_Input:
        return "Empty input data"
    case .Memory_Allocation_Failed:
        return "Memory allocation failed"
    }
    return "Unknown error"
}

// make_error creates an Error_Info with the given parameters
make_error :: proc(code: Parse_Error, line: int, column: int, message: string, ctx: string = "") -> Error_Info {
    return Error_Info{
        code = code,
        line = line,
        column = column,
        message = message,
        ctx = ctx,
    }
}

// format_error formats an error for display to the user
// Note: Returns an allocated string that must be freed by the caller with delete()
format_error :: proc(err: Error_Info, allocator := context.allocator) -> string {
    if err.code == .None {
        return "No error"
    }

    base_msg := fmt.aprintf("Error at line %d, column %d: %s",
                            err.line, err.column, err.message,
                            allocator = allocator)

    if len(err.ctx) > 0 {
        full_msg := fmt.aprintf("%s\nContext: %s", base_msg, err.ctx, allocator = allocator)
        delete(base_msg, allocator)
        return full_msg
    }

    return base_msg
}

// is_error checks if an Error_Info represents an actual error
is_error :: proc(err: Error_Info) -> bool {
    return err.code != .None
}

// Recovery_Strategy determines how to handle errors during parsing
Recovery_Strategy :: enum {
    Fail_Fast,           // Stop parsing at first error
    Skip_Row,            // Skip problematic rows and continue
    Best_Effort,         // Try to parse as much as possible
    Collect_All_Errors,  // Collect all errors without stopping
}

// Parse_Result contains the result of a parsing operation with error information
Parse_Result :: struct {
    success:   bool,                    // Whether parsing succeeded
    error:     Error_Info,              // Primary error (if any)
    warnings:  [dynamic]Error_Info,     // Non-fatal warnings
    rows_parsed: int,                   // Number of rows successfully parsed
    rows_skipped: int,                  // Number of rows skipped due to errors
}

// make_success_result creates a successful parse result
make_success_result :: proc(rows_parsed: int) -> Parse_Result {
    return Parse_Result{
        success = true,
        error = Error_Info{code = .None},
        warnings = make([dynamic]Error_Info),
        rows_parsed = rows_parsed,
        rows_skipped = 0,
    }
}

// make_error_result creates a failed parse result
make_error_result :: proc(err: Error_Info, rows_parsed: int = 0) -> Parse_Result {
    return Parse_Result{
        success = false,
        error = err,
        warnings = make([dynamic]Error_Info),
        rows_parsed = rows_parsed,
        rows_skipped = 0,
    }
}

// add_warning adds a warning to a parse result
add_warning :: proc(result: ^Parse_Result, warning: Error_Info) {
    append(&result.warnings, warning)
}

// parse_result_destroy cleans up a parse result
// Note: This only frees the warnings array. Error messages/ctx are NOT freed
// because they may be string literals. Caller must free dynamically allocated
// error messages manually.
parse_result_destroy :: proc(result: ^Parse_Result) {
    // Only delete the warnings array, not individual error message strings
    // (they might be string literals)
    delete(result.warnings)
}

// Parser_Extended extends Parser with error handling capabilities
Parser_Extended :: struct {
    using base: Parser,                 // Embed standard parser
    recovery_strategy: Recovery_Strategy, // How to handle errors
    last_error: Error_Info,             // Last error encountered
    warnings: [dynamic]Error_Info,      // Collection of warnings
    max_errors: int,                    // Maximum errors before stopping (0 = unlimited)
    error_count: int,                   // Number of errors encountered
}

// parser_extended_create creates a parser with error handling
parser_extended_create :: proc() -> ^Parser_Extended {
    parser := new(Parser_Extended)
    parser.config = default_config()
    parser.state = .Field_Start
    parser.field_buffer = make([dynamic]u8, 0, 1024)
    parser.current_row = make([dynamic]string)
    parser.all_rows = make([dynamic][]string)
    parser.line_number = 1
    parser.recovery_strategy = .Fail_Fast
    parser.last_error = Error_Info{code = .None}
    parser.warnings = make([dynamic]Error_Info)
    parser.max_errors = 0
    parser.error_count = 0
    return parser
}

// parser_extended_destroy frees an extended parser
// Note: Does NOT free parser.warnings, as ownership is transferred to Parse_Result
parser_extended_destroy :: proc(parser: ^Parser_Extended) {
    delete(parser.field_buffer)

    for row in parser.all_rows {
        for field in row {
            delete(field)
        }
        delete(row)
    }
    delete(parser.all_rows)

    for field in parser.current_row {
        delete(field)
    }
    delete(parser.current_row)

    // NOTE: parser.warnings is NOT deleted here because ownership is transferred
    // to Parse_Result when parse_csv_with_errors returns

    free(parser)
}

// record_error records an error in the extended parser
record_error :: proc(parser: ^Parser_Extended, err: Error_Info) -> bool {
    parser.last_error = err
    parser.error_count += 1

    switch parser.recovery_strategy {
    case .Fail_Fast:
        return false // Stop parsing

    case .Skip_Row:
        append(&parser.warnings, err)
        // Clear current row and continue
        for field in parser.current_row {
            delete(field)
        }
        clear(&parser.current_row)
        return true // Continue parsing

    case .Best_Effort:
        append(&parser.warnings, err)
        return true // Continue parsing, keep partial data

    case .Collect_All_Errors:
        append(&parser.warnings, err)
        if parser.max_errors > 0 && parser.error_count >= parser.max_errors {
            return false // Stop after max errors
        }
        return true // Continue parsing
    }

    return false
}

// get_context_around_position extracts context around an error position
get_context_around_position :: proc(data: string, pos: int, context_size: int = 20) -> string {
    start := max(0, pos - context_size)
    end := min(len(data), pos + context_size)

    if start >= len(data) {
        return ""
    }

    ctx_str := data[start:end]

    // Add markers to show error position
    marker_pos := pos - start
    if marker_pos >= 0 && marker_pos < len(ctx_str) {
        return fmt.aprintf("%s <-- HERE --> %s",
                          ctx_str[:marker_pos],
                          ctx_str[marker_pos:])
    }

    return ctx_str
}
