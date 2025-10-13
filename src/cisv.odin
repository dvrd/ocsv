// OCSV - High-Performance CSV Parser in Odin
//
// This is the main package file that re-exports all public APIs.
//
// Example usage:
//     import cisv "ocsv/src"
//
//     parser := cisv.parser_create()
//     defer cisv.parser_destroy(parser)
//
//     ok := cisv.parse_simple_csv(parser, csv_data)
//     if !ok {
//         // Handle error
//     }
//
//     for row in parser.all_rows {
//         for field in row {
//             // Process field
//         }
//     }

package cisv

// Version information
VERSION_MAJOR :: 0
VERSION_MINOR :: 7
VERSION_PATCH :: 0
VERSION_STRING :: "0.7.0"

// Re-export all public types and procedures
// (They are already in the same package, so just documented here)

// Public Types:
// - Config: Parser configuration
// - Parser: Parser state
// - Parse_State: Parser state machine states

// Public Procedures:
// - default_config() -> Config
// - parser_create() -> ^Parser
// - parser_destroy(^Parser)
// - parse_simple_csv(^Parser, string) -> bool
// - parse_csv(^Parser, string) -> bool
// - parse_csv_simd(^Parser, string) -> bool (SIMD-optimized, 20-30% faster)
// - parse_csv_auto(^Parser, string) -> bool (automatically chooses best parser)
// - clear_parser_data(^Parser)

// SIMD Functions:
// - find_delimiter_simd([]byte, byte, int) -> int
// - find_quote_simd([]byte, byte, int) -> int
// - find_newline_simd([]byte, int) -> int
// - find_any_special_simd([]byte, byte, byte, int) -> (int, byte)
// - is_simd_available() -> bool
// - get_simd_arch() -> string

// FFI Exports (for Bun):
// - cisv_parser_create() -> ^Parser
// - cisv_parser_destroy(^Parser)
// - cisv_parse_string(^Parser, cstring, c.int) -> c.int
// - cisv_get_row_count(^Parser) -> c.int
// - cisv_get_field_count(^Parser, c.int) -> c.int
