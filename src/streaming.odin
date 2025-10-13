package cisv

import "core:os"
import "core:io"
import "core:fmt"

// Row_Callback is called for each successfully parsed row
// Return false to stop parsing, true to continue
Row_Callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool

// Row_Callback_With_Schema is called for each validated row with typed values
// Return false to stop parsing, true to continue
Row_Callback_With_Schema :: proc(
	typed_row: []Typed_Value,
	row_num: int,
	validation_result: ^Validation_Result,
	user_data: rawptr,
) -> bool

// Error_Callback is called when parsing errors occur
// Return false to stop parsing, true to continue
Error_Callback :: proc(error: Error_Info, row_num: int, user_data: rawptr) -> bool

// Streaming_Config contains configuration for streaming parser
Streaming_Config :: struct {
	parser_config:   Config,                      // Base CSV parsing config
	chunk_size:      int,                         // Bytes to read per chunk (default: 64KB)
	row_callback:    Row_Callback,                // Called for each row
	error_callback:  Error_Callback,              // Called on errors (optional)
	user_data:       rawptr,                      // User data passed to callbacks
	schema:          ^Schema,                     // Optional schema for validation
	schema_callback: Row_Callback_With_Schema,    // Called for validated rows
	max_field_size:  int,                         // Max field size (default: 1MB)
	max_row_size:    int,                         // Max row size (default: 10MB)
}

// Streaming_Parser maintains state for incremental parsing
Streaming_Parser :: struct {
	config:          Streaming_Config,
	state:           Parse_State,
	field_buffer:    [dynamic]u8,
	current_row:     [dynamic]string,
	line_number:     int,
	rows_processed:  int,
	bytes_processed: int,
	stopped:         bool,
	leftover:        [dynamic]u8,  // Incomplete data from previous chunk
}

// default_streaming_config creates a streaming config with sensible defaults
default_streaming_config :: proc(row_callback: Row_Callback) -> Streaming_Config {
	return Streaming_Config{
		parser_config   = default_config(),
		chunk_size      = 64 * 1024,  // 64KB chunks
		row_callback    = row_callback,
		max_field_size  = 1024 * 1024,  // 1MB
		max_row_size    = 10 * 1024 * 1024,  // 10MB
	}
}

// streaming_parser_create creates a new streaming parser
streaming_parser_create :: proc(config: Streaming_Config) -> ^Streaming_Parser {
	parser := new(Streaming_Parser)
	parser.config = config
	parser.state = .Field_Start
	parser.field_buffer = make([dynamic]u8, 0, 1024)
	parser.current_row = make([dynamic]string)
	parser.leftover = make([dynamic]u8, 0, 1024)
	parser.line_number = 1
	return parser
}

// streaming_parser_destroy frees all memory
streaming_parser_destroy :: proc(parser: ^Streaming_Parser) {
	delete(parser.field_buffer)
	delete(parser.leftover)

	// Free current row strings
	for field in parser.current_row {
		delete(field)
	}
	delete(parser.current_row)

	free(parser)
}

// parse_csv_stream parses CSV from a file path using streaming
parse_csv_stream :: proc(
	config: Streaming_Config,
	file_path: string,
) -> (rows_processed: int, ok: bool) {
	parser := streaming_parser_create(config)
	defer streaming_parser_destroy(parser)

	// Open file
	file, err := os.open(file_path)
	if err != 0 {
		if config.error_callback != nil {
			config.error_callback(
				make_error(.File_Not_Found, 0, 0, fmt.aprintf("Failed to open file: %s", file_path)),
				0,
				config.user_data,
			)
		}
		return 0, false
	}
	defer os.close(file)

	// Read and process chunks
	chunk_buffer := make([]byte, config.chunk_size)
	defer delete(chunk_buffer)

	for {
		bytes_read, read_err := os.read(file, chunk_buffer)
		if bytes_read == 0 && read_err != 0 {
			break
		}

		chunk := chunk_buffer[:bytes_read]
		if !streaming_parser_process_chunk(parser, chunk) {
			return parser.rows_processed, false
		}

		if bytes_read < config.chunk_size {
			break // EOF
		}
	}

	// Process any remaining data
	if !streaming_parser_finalize(parser) {
		return parser.rows_processed, false
	}

	return parser.rows_processed, true
}

// streaming_parser_process_chunk processes a chunk of CSV data
streaming_parser_process_chunk :: proc(
	parser: ^Streaming_Parser,
	chunk: []byte,
) -> bool {
	if parser.stopped {
		return false
	}

	// Combine leftover from previous chunk with new chunk
	data: []byte
	combined_buffer: [dynamic]u8
	has_leftover := len(parser.leftover) > 0

	if has_leftover {
		// Combine leftover + new chunk into temporary buffer
		combined_buffer = make([dynamic]u8, len(parser.leftover) + len(chunk))
		defer delete(combined_buffer)
		copy(combined_buffer[:len(parser.leftover)], parser.leftover[:])
		copy(combined_buffer[len(parser.leftover):], chunk)
		data = combined_buffer[:]
		clear(&parser.leftover)  // Clear leftover since we're processing it now
	} else {
		data = chunk
	}

	// Process data character by character
	config := &parser.config.parser_config
	start_offset := 0  // Track where we started processing in this data buffer

	for i := 0; i < len(data); i += 1 {
		ch := rune(data[i])

		// Handle multi-byte UTF-8
		if data[i] >= 0x80 {
			// This is a multi-byte UTF-8 character
			// We need to decode it properly
			bytes_needed := 0
			if data[i] < 0xE0 {
				bytes_needed = 2
			} else if data[i] < 0xF0 {
				bytes_needed = 3
			} else {
				bytes_needed = 4
			}

			// Check if we have all bytes
			if i + bytes_needed > len(data) {
				// Incomplete UTF-8 character at end of chunk
				// Save for next chunk
				clear(&parser.leftover)
				append(&parser.leftover, ..data[i:])
				parser.bytes_processed += i
				return true
			}

			// Decode UTF-8 character
			ch = decode_utf8_rune(data[i:i+bytes_needed])
			i += bytes_needed - 1 // -1 because loop will increment
		}

		// Only compare bytes for ASCII characters
		ch_is_ascii := ch < 128
		ch_byte := byte(ch) if ch_is_ascii else 0xFF

		// Check field size limits
		if len(parser.field_buffer) > parser.config.max_field_size {
			if parser.config.error_callback != nil {
				parser.config.error_callback(
					make_error(.Max_Field_Size_Exceeded, parser.line_number, 0,
						fmt.aprintf("Field exceeds max size (%d bytes)", parser.config.max_field_size)),
					parser.line_number,
					parser.config.user_data,
				)
			}
			parser.stopped = true
			return false
		}

		// State machine (same as parse_csv)
		switch parser.state {
		case .Field_Start:
			if ch_is_ascii && ch_byte == config.quote {
				parser.state = .In_Quoted_Field
			} else if ch_is_ascii && ch_byte == config.delimiter {
				streaming_emit_empty_field(parser)
			} else if ch == '\n' {
				if len(parser.current_row) > 0 || i > 0 {
					if !streaming_emit_row(parser) {
						return false
					}
					start_offset = i + 1
				}
			} else if ch == '\r' {
				continue
			} else if config.comment != 0 && ch_is_ascii && ch_byte == config.comment && len(parser.current_row) == 0 {
				parser.state = .Field_End
			} else {
				append_rune_to_buffer(&parser.field_buffer, ch)
				parser.state = .In_Field
			}

		case .In_Field:
			if ch_is_ascii && ch_byte == config.delimiter {
				streaming_emit_field(parser)
				parser.state = .Field_Start
			} else if ch == '\n' {
				streaming_emit_field(parser)
				if !streaming_emit_row(parser) {
					return false
				}
				start_offset = i + 1
				parser.state = .Field_Start
			} else if ch == '\r' {
				continue
			} else {
				append_rune_to_buffer(&parser.field_buffer, ch)
			}

		case .In_Quoted_Field:
			if ch_is_ascii && ch_byte == config.quote {
				parser.state = .Quote_In_Quote
			} else {
				append_rune_to_buffer(&parser.field_buffer, ch)
			}

		case .Quote_In_Quote:
			if ch_is_ascii && ch_byte == config.quote {
				append(&parser.field_buffer, config.quote)
				parser.state = .In_Quoted_Field
			} else if ch_is_ascii && ch_byte == config.delimiter {
				streaming_emit_field(parser)
				parser.state = .Field_Start
			} else if ch == '\n' {
				streaming_emit_field(parser)
				if !streaming_emit_row(parser) {
					return false
				}
				start_offset = i + 1
				parser.state = .Field_Start
			} else if ch == '\r' {
				continue
			} else {
				if config.relaxed {
					append(&parser.field_buffer, config.quote)
					append_rune_to_buffer(&parser.field_buffer, ch)
					parser.state = .In_Quoted_Field
				} else {
					if parser.config.error_callback != nil {
						parser.config.error_callback(
							make_error(.Invalid_Character_After_Quote, parser.line_number, 0,
								fmt.aprintf("Invalid character after quote")),
							parser.line_number,
							parser.config.user_data,
						)
					}
					parser.stopped = true
					return false
				}
			}

		case .Field_End:
			if ch == '\n' {
				parser.state = .Field_Start
				clear(&parser.field_buffer)
				clear(&parser.current_row)
			}
		}
	}

	// Save any incomplete data for next chunk
	// If we're in the middle of a field (not at Field_Start), or if we have
	// a partial row, save remaining data for next chunk
	// Note: start_offset tracks where the last complete row ended
	if parser.state != .Field_Start && start_offset < len(data) {
		// We're in the middle of parsing - save remaining data
		append(&parser.leftover, ..data[start_offset:])
	} else if len(parser.current_row) > 0 && parser.state == .Field_Start {
		// We have started a row but haven't finished it yet
		// This shouldn't normally happen, but save the field buffer just in case
		if len(parser.field_buffer) > 0 {
			// We have a partial field - this is unusual but handle it
			append(&parser.leftover, ..parser.field_buffer[:])
		}
	}

	parser.bytes_processed += len(chunk)
	return true
}

// streaming_parser_finalize processes any remaining data at EOF
streaming_parser_finalize :: proc(parser: ^Streaming_Parser) -> bool {
	if parser.stopped {
		return false
	}

	// Handle end of input (same logic as parse_csv)
	switch parser.state {
	case .In_Field:
		streaming_emit_field(parser)
		if !streaming_emit_row(parser) {
			return false
		}
	case .Quote_In_Quote:
		streaming_emit_field(parser)
		if !streaming_emit_row(parser) {
			return false
		}
	case .In_Quoted_Field:
		if parser.config.parser_config.relaxed {
			streaming_emit_field(parser)
			if !streaming_emit_row(parser) {
				return false
			}
		} else {
			if parser.config.error_callback != nil {
				parser.config.error_callback(
					make_error(.Unterminated_Quote, parser.line_number, 0,
						fmt.aprintf("Unterminated quote at end of file")),
					parser.line_number,
					parser.config.user_data,
				)
			}
			return false
		}
	case .Field_Start:
		if len(parser.current_row) > 0 {
			streaming_emit_empty_field(parser)
			if !streaming_emit_row(parser) {
				return false
			}
		}
	case .Field_End:
		// Comment line, do nothing
	}

	return true
}

// Helper procedures for streaming parser

streaming_emit_field :: proc(parser: ^Streaming_Parser) {
	field := string(parser.field_buffer[:])
	field_copy := fmt.aprintf("%s", field)  // Allocate a copy
	append(&parser.current_row, field_copy)
	clear(&parser.field_buffer)
}

streaming_emit_empty_field :: proc(parser: ^Streaming_Parser) {
	append(&parser.current_row, "")
}

streaming_emit_row :: proc(parser: ^Streaming_Parser) -> bool {
	// Check row size limit
	row_size := 0
	for field in parser.current_row {
		row_size += len(field)
	}

	if row_size > parser.config.max_row_size {
		if parser.config.error_callback != nil {
			parser.config.error_callback(
				make_error(.Max_Row_Size_Exceeded, parser.line_number, 0,
					fmt.aprintf("Row exceeds max size (%d bytes)", parser.config.max_row_size)),
				parser.line_number,
				parser.config.user_data,
			)
		}
		parser.stopped = true
		return false
	}

	// Skip header if configured
	if parser.config.schema != nil && parser.config.schema.skip_header && parser.rows_processed == 0 {
		// Free header row
		for field in parser.current_row {
			delete(field)
		}
		clear(&parser.current_row)
		parser.line_number += 1
		parser.rows_processed += 1
		return true
	}

	// Validate with schema if provided
	if parser.config.schema != nil && parser.config.schema_callback != nil {
		result := validate_row(parser.config.schema, parser.current_row[:], parser.line_number)

		// Convert to typed values if validation passed
		if result.valid {
			// Convert each field to typed value
			typed_row := make([]Typed_Value, len(parser.config.schema.columns))
			for col_schema, j in parser.config.schema.columns {
				if j < len(parser.current_row) {
					typed_val, conv_ok := convert_value(col_schema.col_type, parser.current_row[j])
					if conv_ok {
						typed_row[j] = typed_val
					} else {
						typed_row[j] = parser.current_row[j] // Keep as string if conversion fails
					}
				} else {
					typed_row[j] = "" // Missing column
				}
			}

			// Call schema callback
			continue_parsing := parser.config.schema_callback(
				typed_row,
				parser.line_number,
				&result,
				parser.config.user_data,
			)

			delete(typed_row)
			validation_result_destroy(&result)

			if !continue_parsing {
				parser.stopped = true
				// Free row
				for field in parser.current_row {
					delete(field)
				}
				clear(&parser.current_row)
				return false
			}
		} else {
			// Validation failed - call error callback if available
			// Even if validation fails, we may want to continue (depending on strict mode)
			validation_result_destroy(&result)
		}
	} else if parser.config.row_callback != nil {
		// Call regular row callback
		continue_parsing := parser.config.row_callback(
			parser.current_row[:],
			parser.line_number,
			parser.config.user_data,
		)

		if !continue_parsing {
			parser.stopped = true
			// Free row
			for field in parser.current_row {
				delete(field)
			}
			clear(&parser.current_row)
			return false
		}
	}

	// Free row fields
	for field in parser.current_row {
		delete(field)
	}
	clear(&parser.current_row)

	parser.line_number += 1
	parser.rows_processed += 1
	return true
}

// decode_utf8_rune decodes a UTF-8 character from bytes
decode_utf8_rune :: proc(bytes: []byte) -> rune {
	if len(bytes) == 0 do return 0

	if bytes[0] < 0x80 {
		return rune(bytes[0])
	} else if bytes[0] < 0xE0 && len(bytes) >= 2 {
		return rune((u32(bytes[0] & 0x1F) << 6) | u32(bytes[1] & 0x3F))
	} else if bytes[0] < 0xF0 && len(bytes) >= 3 {
		return rune((u32(bytes[0] & 0x0F) << 12) | (u32(bytes[1] & 0x3F) << 6) | u32(bytes[2] & 0x3F))
	} else if len(bytes) >= 4 {
		return rune((u32(bytes[0] & 0x07) << 18) | (u32(bytes[1] & 0x3F) << 12) | (u32(bytes[2] & 0x3F) << 6) | u32(bytes[3] & 0x3F))
	}

	return 0
}
