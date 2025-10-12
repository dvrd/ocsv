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
VERSION_MINOR :: 1
VERSION_PATCH :: 0
VERSION_STRING :: "0.1.0"

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

// FFI Exports (for Bun):
// - cisv_parser_create() -> ^Parser
// - cisv_parser_destroy(^Parser)
// - cisv_parse_string(^Parser, cstring, c.int) -> c.int
// - cisv_get_row_count(^Parser) -> c.int
// - cisv_get_field_count(^Parser, c.int) -> c.int
