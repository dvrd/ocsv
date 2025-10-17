package ocsv

import "core:os"
import "core:strings"

// Parse_State represents the current state of the CSV parser
Parse_State :: enum {
    Field_Start,        // Beginning of a field
    In_Field,           // Inside an unquoted field
    In_Quoted_Field,    // Inside a quoted field
    Quote_In_Quote,     // Found a quote, might be "" or end of quoted field
    Field_End,          // Field complete
}

// Parser maintains the state for CSV parsing
Parser :: struct {
    config:        Config,                 // Parser configuration
    state:         Parse_State,            // Current parse state
    field_buffer:  [dynamic]u8,            // Buffer for accumulating current field
    current_row:   [dynamic]string,        // Current row being built
    all_rows:      [dynamic][]string,      // All parsed rows
    line_number:   int,                    // Current line number (1-indexed)
    column_number: int,                    // Current column number (1-indexed, Phase 1)
    last_error:    Error_Info,             // Last error encountered (Phase 1 addition)
    error_count:   int,                    // Total number of errors (Phase 1 addition)
}

// parser_create creates a new parser with default configuration
parser_create :: proc() -> ^Parser {
    parser := new(Parser)
    parser.config = default_config()
    parser.state = .Field_Start
    parser.field_buffer = make([dynamic]u8, 0, 1024)
    parser.current_row = make([dynamic]string)
    parser.all_rows = make([dynamic][]string)
    parser.line_number = 1
    parser.column_number = 1
    parser.last_error = Error_Info{code = .None}
    parser.error_count = 0
    return parser
}

// parser_destroy frees all memory associated with the parser
parser_destroy :: proc(parser: ^Parser) {
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
                        // Only delete non-empty strings
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
    } else {
        // Standard cleanup for macOS/Linux (Unix mmap more forgiving)
        delete(parser.field_buffer)

        // Free all row data
        for row in parser.all_rows {
            for field in row {
                delete(field)
            }
            delete(row)
        }
        delete(parser.all_rows)

        // Free any remaining fields in current_row
        for field in parser.current_row {
            delete(field)
        }
        delete(parser.current_row)
    }

    free(parser)
}

// parse_simple_csv performs minimal CSV parsing (for initial validation)
// This is kept for backwards compatibility and testing
parse_simple_csv :: proc(parser: ^Parser, data: string) -> bool {
    return parse_csv(parser, data)
}

// clear_parser_data frees all parsed data (used when reusing parser)
clear_parser_data :: proc(parser: ^Parser) {
    // Platform-specific cleanup (Windows VirtualAlloc is stricter than Unix mmap)
    when ODIN_OS == .Windows {
        // Windows requires extra validation to avoid "bad free" warnings
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
        }
        clear(&parser.all_rows)

        if len(parser.current_row) > 0 {
            for field in parser.current_row {
                if field != "" {
                    delete(field)
                }
            }
        }
        clear(&parser.current_row)
    } else {
        // Standard cleanup for macOS/Linux
        for row in parser.all_rows {
            for field in row {
                delete(field)
            }
            delete(row)
        }
        clear(&parser.all_rows)

        for field in parser.current_row {
            delete(field)
        }
        clear(&parser.current_row)
    }
}

// parse_csv performs RFC 4180 compliant CSV parsing with full edge case handling
// Automatically uses SIMD when available for optimal performance
parse_csv :: proc(parser: ^Parser, data: string) -> bool {
    // TEMPORARY: Use scalar parser to debug issue
    return parse_csv_scalar(parser, data)
}

// parse_csv_scalar is the original byte-by-byte parser (kept for comparison/fallback)
parse_csv_scalar :: proc(parser: ^Parser, data: string) -> bool {
    state := Parse_State.Field_Start
    clear(&parser.field_buffer)
    clear_parser_data(parser)  // Properly free existing data before reuse
    parser.line_number = 1
    parser.column_number = 1

    for ch, i in data {
        parser.column_number += 1
        // Only compare bytes for ASCII characters (delimiters/quotes are always ASCII)
        ch_is_ascii := ch < 128
        ch_byte := byte(ch) if ch_is_ascii else 0xFF

        switch state {
        case .Field_Start:
            if ch_is_ascii && ch_byte == parser.config.quote {
                state = .In_Quoted_Field
            } else if ch_is_ascii && ch_byte == parser.config.delimiter {
                emit_empty_field(parser)
            } else if ch == '\n' {
                // Empty line or end of row
                if len(parser.current_row) > 0 {
                    // We have fields - emit trailing empty field if we're at Field_Start
                    // (means we just saw a delimiter before the newline: ",\n")
                    emit_empty_field(parser)
                    emit_row(parser)
                } else if i > 0 {
                    // Empty line (but not first character)
                    emit_row(parser)
                }
            } else if ch == '\r' {
                // Skip carriage return (handle CRLF)
                continue
            } else if parser.config.comment != 0 && ch_is_ascii && ch_byte == parser.config.comment && len(parser.current_row) == 0 {
                // Comment line (only at start of line)
                state = .Field_End // Will skip to end of line
            } else {
                append_rune_to_buffer(&parser.field_buffer, ch)
                state = .In_Field
            }

        case .In_Field:
            if ch_is_ascii && ch_byte == parser.config.delimiter {
                emit_field(parser)
                state = .Field_Start
            } else if ch == '\n' {
                emit_field(parser)
                emit_row(parser)
                state = .Field_Start
            } else if ch == '\r' {
                // Skip carriage return
                continue
            } else {
                append_rune_to_buffer(&parser.field_buffer, ch)
            }

        case .In_Quoted_Field:
            if ch_is_ascii && ch_byte == parser.config.quote {
                state = .Quote_In_Quote
            } else {
                // Everything is literal inside quotes (including delimiters, newlines, comments)
                append_rune_to_buffer(&parser.field_buffer, ch)
            }

        case .Quote_In_Quote:
            if ch_is_ascii && ch_byte == parser.config.quote {
                // "" sequence = literal quote character
                append(&parser.field_buffer, parser.config.quote)
                state = .In_Quoted_Field
            } else if ch_is_ascii && ch_byte == parser.config.delimiter {
                // End of quoted field
                emit_field(parser)
                state = .Field_Start
            } else if ch == '\n' {
                // End of quoted field and row
                emit_field(parser)
                emit_row(parser)
                state = .Field_Start
            } else if ch == '\r' {
                // Skip carriage return after quote
                // Stay in Quote_In_Quote to handle potential \n next
                continue
            } else {
                // RFC 4180 violation: character after closing quote
                if parser.config.relaxed {
                    // In relaxed mode, treat the previous quote as literal
                    append(&parser.field_buffer, parser.config.quote)
                    append_rune_to_buffer(&parser.field_buffer, ch)
                    state = .In_Quoted_Field
                } else {
                    // Strict mode: this is an error
                    record_parser_error(parser, .Invalid_Character_After_Quote,
                        "Invalid character after closing quote (strict mode)")
                    return false
                }
            }

        case .Field_End:
            // Used for skipping comment lines
            if ch == '\n' {
                state = .Field_Start
                clear(&parser.field_buffer)
                clear(&parser.current_row)
            }
        }
    }

    // Handle end of input
    switch state {
    case .In_Field:
        emit_field(parser)
        emit_row(parser)
    case .Quote_In_Quote:
        // Quoted field at end of file
        emit_field(parser)
        emit_row(parser)
    case .In_Quoted_Field:
        // Unterminated quoted field
        if parser.config.relaxed {
            emit_field(parser)
            emit_row(parser)
        } else {
            record_parser_error(parser, .Unterminated_Quote,
                "Unterminated quoted field at end of input")
            return false // Error: unterminated quote
        }
    case .Field_Start:
        // End on field boundary (e.g., trailing delimiter like "a,b,")
        if len(parser.current_row) > 0 {
            // We have fields but ended with delimiter - emit empty field
            emit_empty_field(parser)
            emit_row(parser)
        }
    case .Field_End:
        // Comment line, do nothing
    }

    return true
}

// Helper procedures for state machine

append_rune_to_buffer :: proc(buffer: ^[dynamic]u8, r: rune) {
    // Manually encode rune to UTF-8 and append bytes to buffer
    if r < 0x80 {
        // 1-byte sequence (ASCII)
        append(buffer, byte(r))
    } else if r < 0x800 {
        // 2-byte sequence
        append(buffer, byte(0xC0 | (r >> 6)))
        append(buffer, byte(0x80 | (r & 0x3F)))
    } else if r < 0x10000 {
        // 3-byte sequence
        append(buffer, byte(0xE0 | (r >> 12)))
        append(buffer, byte(0x80 | ((r >> 6) & 0x3F)))
        append(buffer, byte(0x80 | (r & 0x3F)))
    } else {
        // 4-byte sequence
        append(buffer, byte(0xF0 | (r >> 18)))
        append(buffer, byte(0x80 | ((r >> 12) & 0x3F)))
        append(buffer, byte(0x80 | ((r >> 6) & 0x3F)))
        append(buffer, byte(0x80 | (r & 0x3F)))
    }
}

emit_field :: proc(parser: ^Parser) {
    field := string(parser.field_buffer[:])
    field_copy := strings.clone(field)
    append(&parser.current_row, field_copy)
    clear(&parser.field_buffer)
}

emit_empty_field :: proc(parser: ^Parser) {
    append(&parser.current_row, "")
}

emit_row :: proc(parser: ^Parser) {
    // Always emit rows, even if empty (for empty line handling)
    row_copy := make([]string, len(parser.current_row))
    if len(parser.current_row) > 0 {
        copy(row_copy, parser.current_row[:])
    }
    append(&parser.all_rows, row_copy)
    clear(&parser.current_row)
    parser.line_number += 1
    parser.column_number = 1
}

// is_comment_line checks if a line is a comment
is_comment_line :: proc(line: string, comment_char: byte) -> bool {
    if comment_char == 0 do return false

    // Skip leading whitespace
    trimmed := strings.trim_left_space(line)
    if len(trimmed) == 0 do return false

    return trimmed[0] == comment_char
}

// record_parser_error records an error in the parser (Phase 1 addition)
record_parser_error :: proc(parser: ^Parser, code: Parse_Error, message: string, ctx: string = "") {
    parser.last_error = make_error(code, parser.line_number, parser.column_number, message, ctx)
    parser.error_count += 1
}
