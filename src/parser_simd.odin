package ocsv

import "core:strings"

// Character classification for fast byte checking
// PHASE 3: Lookup table eliminates branches for character classification
Char_Class :: enum u8 {
    Normal      = 0,  // Regular character
    Delimiter   = 1,  // Field separator
    Quote       = 2,  // Quote character
    Newline     = 3,  // Line feed
    CR          = 4,  // Carriage return
}

// build_char_table creates a 256-entry lookup table for fast character classification
build_char_table :: proc(delimiter, quote: byte) -> [256]Char_Class {
    table: [256]Char_Class

    // Initialize all as normal
    for i in 0..<256 {
        table[i] = .Normal
    }

    // Set special characters
    table[delimiter] = .Delimiter
    table[quote] = .Quote
    table['\n'] = .Newline
    table['\r'] = .CR

    return table
}

// bulk_append_no_cr appends bytes from data[start:end] to buffer, skipping carriage returns
// This is a hot path - optimized for cases where \r is rare (most CSVs use LF only)
bulk_append_no_cr :: proc(buffer: ^[dynamic]u8, data: []byte, start, end: int) {
    // Fast path: check if there are any carriage returns in the range
    has_cr := false
    for i in start..<end {
        if data[i] == '\r' {
            has_cr = true
            break
        }
    }

    if !has_cr {
        // No carriage returns - bulk copy (fast path, 95% of cases)
        append(buffer, ..data[start:end])
    } else {
        // Has carriage returns - filter while copying (slow path, 5% of cases)
        for i in start..<end {
            if data[i] != '\r' {
                append(buffer, data[i])
            }
        }
    }
}

// SIMD-optimized CSV parser using NEON (ARM64) and scalar fallback (x86_64)
// Target: 3-5x performance improvement over byte-by-byte parser
//
// Strategy:
// - Use find_any_special_simd() to skip over unquoted field content (16 bytes/cycle)
// - Use find_quote_simd() to skip over quoted field content (16 bytes/cycle)
// - Maintain exact same state machine logic as parse_csv() for RFC 4180 compliance
//
// Performance: Expected 80-150 MB/s vs 27.62 MB/s baseline
//
// Phase 1: Optimizes .In_Field (unquoted fields) and .In_Quoted_Field
// Phase 2: Further optimizations for field boundaries and empty fields

parse_csv_simd :: proc(parser: ^Parser, data: string) -> bool {
    state := Parse_State.Field_Start
    clear(&parser.field_buffer)
    clear_parser_data(parser)
    parser.line_number = 1

    // PHASE 3: Build character classification lookup table (eliminates branches)
    char_table := build_char_table(parser.config.delimiter, parser.config.quote)

    // Convert string to []byte for SIMD operations
    data_bytes := transmute([]byte)data
    i := 0

    for i < len(data_bytes) {
        ch_byte := data_bytes[i]

        // PHASE 3: Fast character classification (O(1) lookup vs multiple branches)
        ch_class := char_table[ch_byte]

        // Fast path: ASCII check (delimiters/quotes are always ASCII)
        ch_is_ascii := ch_byte < 128

        // For UTF-8 multi-byte, we'll decode when needed
        ch := rune(ch_byte)
        if !ch_is_ascii {
            // UTF-8 decode (2-4 byte sequences)
            if ch_byte >= 0xC0 && ch_byte <= 0xDF && i + 1 < len(data_bytes) {
                ch = rune((ch_byte & 0x1F) << 6) | rune(data_bytes[i+1] & 0x3F)
                i += 1
            } else if ch_byte >= 0xE0 && ch_byte <= 0xEF && i + 2 < len(data_bytes) {
                ch = rune((ch_byte & 0x0F) << 12) |
                     rune((data_bytes[i+1] & 0x3F) << 6) |
                     rune(data_bytes[i+2] & 0x3F)
                i += 2
            } else if ch_byte >= 0xF0 && ch_byte <= 0xF7 && i + 3 < len(data_bytes) {
                ch = rune((ch_byte & 0x07) << 18) |
                     rune((data_bytes[i+1] & 0x3F) << 12) |
                     rune((data_bytes[i+2] & 0x3F) << 6) |
                     rune(data_bytes[i+3] & 0x3F)
                i += 3
            }
        }

        switch state {
        case .Field_Start:
            // PHASE 3: Use lookup table for fast character classification
            switch ch_class {
            case .Quote:
                state = .In_Quoted_Field
                i += 1
                continue
            case .Delimiter:
                emit_empty_field(parser)
                i += 1
                continue
            case .Newline:
                if len(parser.current_row) > 0 {
                    emit_empty_field(parser)
                    emit_row(parser)
                } else if i > 0 {
                    emit_row(parser)
                }
                i += 1
                continue
            case .CR:
                i += 1
                continue
            case .Normal:
                // Check for comment character (not in lookup table, as it's optional)
                if parser.config.comment != 0 && ch_is_ascii && ch_byte == parser.config.comment && len(parser.current_row) == 0 {
                    state = .Field_End
                    i += 1
                    continue
                }
                // Start unquoted field - add first char and switch to In_Field
                append_rune_to_buffer(&parser.field_buffer, ch)
                state = .In_Field
                i += 1
                continue
            }

        case .In_Field:
            // SIMD FAST PATH: Find next delimiter or newline
            // This processes 16 bytes per SIMD instruction instead of 1 byte per iteration
            next_pos, found_byte := find_any_special_simd(data_bytes, parser.config.delimiter, '\n', i)

            if next_pos != -1 {
                // PHASE 2 OPTIMIZATION: Bulk copy field content (no byte-by-byte loop)
                bulk_append_no_cr(&parser.field_buffer, data_bytes, i, next_pos)

                // Move to special character and handle it
                i = next_pos
                if found_byte == parser.config.delimiter {
                    emit_field(parser)
                    state = .Field_Start
                    i += 1
                    continue
                } else if found_byte == '\n' {
                    emit_field(parser)
                    emit_row(parser)
                    state = .Field_Start
                    i += 1
                    continue
                }
            } else {
                // No more delimiters/newlines - rest is field content
                // PHASE 2 OPTIMIZATION: Bulk copy remaining data
                bulk_append_no_cr(&parser.field_buffer, data_bytes, i, len(data_bytes))
                // End of data while in field
                emit_field(parser)
                emit_row(parser)
                break
            }

        case .In_Quoted_Field:
            // SIMD FAST PATH: Find next quote character
            // This processes 16 bytes per SIMD instruction
            next_quote := find_quote_simd(data_bytes, parser.config.quote, i)

            if next_quote != -1 {
                // PHASE 2 OPTIMIZATION: Bulk copy quoted field content
                // Note: Quoted fields can contain \r as literal data, so we DON'T filter it
                append(&parser.field_buffer, ..data_bytes[i:next_quote])

                // Move to quote and transition state
                i = next_quote
                state = .Quote_In_Quote
                i += 1
                continue
            } else {
                // No closing quote
                if parser.config.relaxed {
                    // PHASE 2 OPTIMIZATION: Bulk copy remaining data
                    append(&parser.field_buffer, ..data_bytes[i:])
                    emit_field(parser)
                    emit_row(parser)
                    break
                } else {
                    return false  // Error: unterminated quote
                }
            }

        case .Quote_In_Quote:
            // PHASE 3: Use lookup table for fast character classification
            switch ch_class {
            case .Quote:
                // Doubled quote "" = literal quote
                append(&parser.field_buffer, parser.config.quote)
                state = .In_Quoted_Field
                i += 1
                continue
            case .Delimiter:
                // End of quoted field
                emit_field(parser)
                state = .Field_Start
                i += 1
                continue
            case .Newline:
                // End of quoted field and row
                emit_field(parser)
                emit_row(parser)
                state = .Field_Start
                i += 1
                continue
            case .CR:
                i += 1
                continue
            case .Normal:
                // RFC 4180 violation
                if parser.config.relaxed {
                    append(&parser.field_buffer, parser.config.quote)
                    append_rune_to_buffer(&parser.field_buffer, ch)
                    state = .In_Quoted_Field
                    i += 1
                    continue
                } else {
                    return false
                }
            }

        case .Field_End:
            // Comment line - skip to newline
            // PHASE 3: Use lookup table
            if ch_class == .Newline {
                state = .Field_Start
                clear(&parser.field_buffer)
                clear(&parser.current_row)
            }
            i += 1
            continue
        }
    }

    // Handle end of input
    switch state {
    case .In_Field:
        emit_field(parser)
        emit_row(parser)
    case .Quote_In_Quote:
        emit_field(parser)
        emit_row(parser)
    case .In_Quoted_Field:
        if parser.config.relaxed {
            emit_field(parser)
            emit_row(parser)
        } else {
            return false
        }
    case .Field_Start:
        if len(parser.current_row) > 0 {
            emit_empty_field(parser)
            emit_row(parser)
        }
    case .Field_End:
        // Comment line
    }

    return true
}

// parse_csv_auto automatically chooses between SIMD and standard parser
// For now, always use SIMD since it's now properly implemented
parse_csv_auto :: proc(parser: ^Parser, data: string) -> bool {
    when ODIN_ARCH == .arm64 {
        // ARM64: Always use SIMD (NEON is fast)
        return parse_csv_simd(parser, data)
    } else {
        // x86_64/other: Use SIMD for files > 1KB (scalar overhead for tiny files)
        if len(data) >= 1024 {
            return parse_csv_simd(parser, data)
        }
        return parse_csv_scalar(parser, data)
    }
}
