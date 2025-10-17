package ocsv

// Error handling and recovery for CSV parsing
// Provides clear error messages with line/column information

import "core:fmt"
import "core:strings"

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
// IMPORTANT: Always clones strings (even empty ones) so all Error_Info strings are owned and can be freed
make_error :: proc(code: Parse_Error, line: int, column: int, message: string, ctx: string = "") -> Error_Info {
    return Error_Info{
        code = code,
        line = line,
        column = column,
        message = strings.clone(message),  // Always clone to ensure consistent ownership
        ctx = strings.clone(ctx),          // Always clone, even if empty, for consistent ownership
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

// error_info_destroy frees the strings owned by an Error_Info
// Call this after creating Error_Info with make_error to prevent leaks
error_info_destroy :: proc(err: ^Error_Info) {
    delete(err.message)
    delete(err.ctx)
    err.message = ""
    err.ctx = ""
    err.code = .None
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
// Clones the error strings so Parse_Result owns them independently
make_error_result :: proc(err: Error_Info, rows_parsed: int = 0) -> Parse_Result {
    // Clone error to ensure Parse_Result owns its strings independently
    err_copy := err
    err_copy.message = strings.clone(err.message)
    err_copy.ctx = strings.clone(err.ctx)

    return Parse_Result{
        success = false,
        error = err_copy,
        warnings = make([dynamic]Error_Info),
        rows_parsed = rows_parsed,
        rows_skipped = 0,
    }
}

// add_warning adds a warning to a parse result
add_warning :: proc(result: ^Parse_Result, warning: Error_Info) {
    append(&result.warnings, warning)
}

parse_result_destroy :: proc(result: ^Parse_Result) {
    // Free Error_Info strings in warnings array
    for warning in result.warnings {
        delete(warning.message)
        delete(warning.ctx)
    }
    delete(result.warnings)

    // Free primary error strings (always allocated by make_error)
    delete(result.error.message)
    delete(result.error.ctx)
}

// Parser_Extended extends Parser with error handling capabilities
// Note: last_error and error_count are now in base Parser (Phase 1)
Parser_Extended :: struct {
    using base: Parser,                 // Embed standard parser (includes last_error, error_count)
    recovery_strategy: Recovery_Strategy, // How to handle errors
    warnings: [dynamic]Error_Info,      // Collection of warnings
    max_errors: int,                    // Maximum errors before stopping (0 = unlimited)
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
    parser.column_number = 1
    parser.recovery_strategy = .Fail_Fast
    parser.last_error = Error_Info{code = .None}
    parser.warnings = make([dynamic]Error_Info)
    parser.max_errors = 0
    parser.error_count = 0
    return parser
}

parser_extended_destroy :: proc(parser: ^Parser_Extended) {
    if parser == nil do return

    // Platform-specific cleanup (Windows VirtualAlloc is stricter than Unix mmap)
    when ODIN_OS == .Windows {
        // Windows requires extra validation to avoid "bad free" warnings
        if len(parser.field_buffer) > 0 {
            delete(parser.field_buffer)
        }

        // Free all row data with additional checks
        if len(parser.all_rows) > 0 {
            for row in parser.all_rows {
                if len(row) > 0 {
                    for field in row {
                        if field != "" {
                            delete(field)
                        }
                    }
                    delete(row)
                }
            }
            delete(parser.all_rows)
        }

        // Free any remaining fields in current_row
        if len(parser.current_row) > 0 {
            for field in parser.current_row {
                if field != "" {
                    delete(field)
                }
            }
            delete(parser.current_row)
        }

        // Free Error_Info strings in warnings array
        if len(parser.warnings) > 0 {
            for warning in parser.warnings {
                delete(warning.message)
                delete(warning.ctx)
            }
            delete(parser.warnings)
        }
    } else {
        // Standard cleanup for macOS/Linux
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

        // Free Error_Info strings in warnings array
        for warning in parser.warnings {
            delete(warning.message)
            delete(warning.ctx)
        }
        delete(parser.warnings)
    }

    // Free last_error strings (from base Parser)
    // Note: These are independent from warnings array and Parse_Result
    // because record_error and make_error_result clone strings
    delete(parser.last_error.message)
    delete(parser.last_error.ctx)

    free(parser)
}

// record_error records an error in the extended parser
// Takes ownership of err strings in last_error
record_error :: proc(parser: ^Parser_Extended, err: Error_Info) -> bool {
    // Store in last_error - takes ownership of err strings
    parser.last_error = err
    parser.error_count += 1

    switch parser.recovery_strategy {
    case .Fail_Fast:
        return false // Stop parsing

    case .Skip_Row:
        // Clone strings when appending to warnings (independent ownership)
        err_copy := err
        err_copy.message = strings.clone(err.message)
        err_copy.ctx = strings.clone(err.ctx)
        append(&parser.warnings, err_copy)
        // Clear current row and continue
        for field in parser.current_row {
            delete(field)
        }
        clear(&parser.current_row)
        return true // Continue parsing

    case .Best_Effort:
        // Clone strings when appending to warnings (independent ownership)
        err_copy := err
        err_copy.message = strings.clone(err.message)
        err_copy.ctx = strings.clone(err.ctx)
        append(&parser.warnings, err_copy)
        return true // Continue parsing, keep partial data

    case .Collect_All_Errors:
        // Clone strings when appending to warnings (independent ownership)
        err_copy := err
        err_copy.message = strings.clone(err.message)
        err_copy.ctx = strings.clone(err.ctx)
        append(&parser.warnings, err_copy)
        if parser.max_errors > 0 && parser.error_count >= parser.max_errors {
            return false // Stop after max errors
        }
        return true // Continue parsing
    }

    return false
}

// get_context_around_position extracts context around an error position
// Returns a non-allocated substring - caller does NOT need to delete
get_context_around_position :: proc(data: string, pos: int, context_size: int = 20) -> string {
    start := max(0, pos - context_size)
    end := min(len(data), pos + context_size)

    if start >= len(data) {
        return ""
    }

    // Just return the context substring without markers to avoid allocation
    return data[start:end]
}
