package cisv

import "core:strings"
import "core:fmt"

// Error-aware CSV parser with detailed error reporting and recovery strategies

// parse_csv_with_errors parses CSV with detailed error information
parse_csv_with_errors :: proc(parser: ^Parser_Extended, data: string) -> Parse_Result {
    if len(data) == 0 {
        return make_error_result(make_error(.Empty_Input, 0, 0, "Input data is empty"))
    }

    state := Parse_State.Field_Start
    clear(&parser.field_buffer)
    clear_parser_data(&parser.base)
    parser.line_number = 1
    parser.error_count = 0
    clear(&parser.warnings)

    pos := 0
    column := 1
    row_start_pos := 0

    for pos < len(data) {
        ch := rune(data[pos])
        ch_is_ascii := ch < 128
        ch_byte := byte(ch) if ch_is_ascii else 0xFF

        switch state {
        case .Field_Start:
            if ch_is_ascii && ch_byte == parser.config.quote {
                state = .In_Quoted_Field
                pos += 1
                column += 1

            } else if ch_is_ascii && ch_byte == parser.config.delimiter {
                emit_empty_field(&parser.base)
                pos += 1
                column += 1

            } else if ch == '\n' {
                if len(parser.current_row) > 0 || pos > row_start_pos {
                    emit_row(&parser.base)
                }
                pos += 1
                parser.line_number += 1
                column = 1
                row_start_pos = pos

            } else if ch == '\r' {
                pos += 1
                column += 1
                continue

            } else if parser.config.comment != 0 && ch_is_ascii && ch_byte == parser.config.comment && len(parser.current_row) == 0 {
                // Skip comment line
                for pos < len(data) && data[pos] != '\n' {
                    pos += 1
                }
                if pos < len(data) {
                    pos += 1 // Skip newline
                    parser.line_number += 1
                    column = 1
                    row_start_pos = pos
                }
                state = .Field_Start

            } else {
                append_rune_to_buffer(&parser.field_buffer, ch)
                state = .In_Field
                pos += 1
                column += 1
            }

        case .In_Field:
            if ch_is_ascii && ch_byte == parser.config.delimiter {
                emit_field(&parser.base)
                state = .Field_Start
                pos += 1
                column += 1

            } else if ch == '\n' {
                emit_field(&parser.base)
                emit_row(&parser.base)
                state = .Field_Start
                pos += 1
                parser.line_number += 1
                column = 1
                row_start_pos = pos

            } else if ch == '\r' {
                pos += 1
                column += 1
                continue

            } else {
                append_rune_to_buffer(&parser.field_buffer, ch)
                pos += 1
                column += 1
            }

        case .In_Quoted_Field:
            if ch_is_ascii && ch_byte == parser.config.quote {
                state = .Quote_In_Quote
                pos += 1
                column += 1

            } else {
                append_rune_to_buffer(&parser.field_buffer, ch)
                if ch == '\n' {
                    parser.line_number += 1
                    column = 1
                } else {
                    column += 1
                }
                pos += 1
            }

        case .Quote_In_Quote:
            if ch_is_ascii && ch_byte == parser.config.quote {
                // "" sequence = literal quote
                append(&parser.field_buffer, parser.config.quote)
                state = .In_Quoted_Field
                pos += 1
                column += 1

            } else if ch_is_ascii && ch_byte == parser.config.delimiter {
                emit_field(&parser.base)
                state = .Field_Start
                pos += 1
                column += 1

            } else if ch == '\n' {
                emit_field(&parser.base)
                emit_row(&parser.base)
                state = .Field_Start
                pos += 1
                parser.line_number += 1
                column = 1
                row_start_pos = pos

            } else if ch == '\r' {
                pos += 1
                column += 1
                continue

            } else {
                // Invalid character after quote
                if parser.config.relaxed {
                    // Relaxed mode: treat quote as literal
                    append(&parser.field_buffer, parser.config.quote)
                    append_rune_to_buffer(&parser.field_buffer, ch)
                    state = .In_Quoted_Field
                    pos += 1
                    column += 1

                    // Add warning
                    warning := make_error(
                        .Invalid_Character_After_Quote,
                        parser.line_number,
                        column,
                        "Invalid character after closing quote (relaxed mode)",
                        get_context_around_position(data, pos, 10),
                    )
                    add_warning(&Parse_Result{warnings = parser.warnings}, warning)
                } else {
                    // Strict mode: error
                    err := make_error(
                        .Invalid_Character_After_Quote,
                        parser.line_number,
                        column,
                        fmt.aprintf("Invalid character '%c' after closing quote", ch),
                        get_context_around_position(data, pos, 20),
                    )

                    if !record_error(parser, err) {
                        // Cannot recover, return error
                        return make_error_result(err, len(parser.all_rows))
                    }

                    // Try to recover
                    pos += 1
                    column += 1
                    state = .Field_Start
                }
            }

        case .Field_End:
            // Skip to end of line (comment handling)
            if ch == '\n' {
                state = .Field_Start
                pos += 1
                parser.line_number += 1
                column = 1
                row_start_pos = pos
                clear(&parser.field_buffer)
                clear(&parser.current_row)
            } else {
                pos += 1
                column += 1
            }
        }

        // Check for field size limit
        if parser.config.max_row_size > 0 && len(parser.field_buffer) > parser.config.max_row_size {
            err := make_error(
                .Max_Field_Size_Exceeded,
                parser.line_number,
                column,
                fmt.aprintf("Field size %d exceeds maximum %d", len(parser.field_buffer), parser.config.max_row_size),
                "",
            )

            if !record_error(parser, err) {
                return make_error_result(err, len(parser.all_rows))
            }

            // Skip rest of field
            clear(&parser.field_buffer)
        }
    }

    // Handle end of input
    switch state {
    case .In_Field:
        emit_field(&parser.base)
        emit_row(&parser.base)

    case .Quote_In_Quote:
        emit_field(&parser.base)
        emit_row(&parser.base)

    case .In_Quoted_Field:
        // Unterminated quote
        if parser.config.relaxed {
            emit_field(&parser.base)
            emit_row(&parser.base)

            warning := make_error(
                .Unterminated_Quote,
                parser.line_number,
                column,
                "Unterminated quoted field at end of file (relaxed mode)",
                "",
            )
            add_warning(&Parse_Result{warnings = parser.warnings}, warning)
        } else {
            err := make_error(
                .Unterminated_Quote,
                parser.line_number,
                column,
                "Unterminated quoted field at end of file",
                "",
            )
            return make_error_result(err, len(parser.all_rows))
        }

    case .Field_Start:
        if len(parser.current_row) > 0 {
            emit_empty_field(&parser.base)
            emit_row(&parser.base)
        }

    case .Field_End:
        // Comment line, do nothing
    }

    // Create success result
    result := make_success_result(len(parser.all_rows))
    result.warnings = parser.warnings
    return result
}

// parse_csv_safe is a convenience wrapper that returns both result and data
parse_csv_safe :: proc(data: string, config: Config, recovery: Recovery_Strategy = .Fail_Fast) -> (rows: [][]string, result: Parse_Result) {
    parser := parser_extended_create()
    defer parser_extended_destroy(parser)

    parser.config = config
    parser.recovery_strategy = recovery

    result = parse_csv_with_errors(parser, data)

    if result.success || len(parser.all_rows) > 0 {
        // Copy rows to return
        rows = make([][]string, len(parser.all_rows))
        for row, i in parser.all_rows {
            rows[i] = make([]string, len(row))
            for field, j in row {
                rows[i][j] = strings.clone(field)
            }
        }
    }

    return rows, result
}

// Validation functions

// validate_column_consistency checks if all rows have the same number of columns
validate_column_consistency :: proc(parser: ^Parser, strict: bool = false) -> (ok: bool, err: Error_Info) {
    if len(parser.all_rows) == 0 {
        return true, Error_Info{code = .None}
    }

    expected_columns := len(parser.all_rows[0])

    for row, i in parser.all_rows {
        if len(row) != expected_columns {
            if strict {
                return false, make_error(
                    .Inconsistent_Column_Count,
                    i + 1,
                    0,
                    fmt.aprintf("Row %d has %d columns, expected %d", i + 1, len(row), expected_columns),
                    "",
                )
            }
        }
    }

    return true, Error_Info{code = .None}
}

// check_utf8_validity validates UTF-8 encoding of input
check_utf8_validity :: proc(data: string) -> (ok: bool, err: Error_Info) {
    // Odin strings are already UTF-8, but we can check for invalid sequences
    for r, i in data {
        if r == 0xFFFD { // Unicode replacement character (indicates invalid UTF-8)
            return false, make_error(
                .Invalid_UTF8,
                0, // Would need to track line
                i,
                "Invalid UTF-8 sequence detected",
                get_context_around_position(data, i, 20),
            )
        }
    }
    return true, Error_Info{code = .None}
}
