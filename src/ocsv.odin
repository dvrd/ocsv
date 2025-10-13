// OCSV - High-Performance CSV Parser in Odin
//
// This is the main package file that re-exports all public APIs.
//
// Example usage:
//     import ocsv "ocsv/src"
//
//     parser := ocsv.parser_create()
//     defer ocsv.parser_destroy(parser)
//
//     ok := ocsv.parse_simple_csv(parser, csv_data)
//     if !ok {
//         // Handle error
//     }
//
//     for row in parser.all_rows {
//         for field in row {
//             // Process field
//         }
//     }

package ocsv

// Version information
VERSION_MAJOR :: 0
VERSION_MINOR :: 10
VERSION_PATCH :: 0
VERSION_STRING :: "0.10.0"

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
// - ocsv_parser_create() -> ^Parser
// - ocsv_parser_destroy(^Parser)
// - ocsv_parse_string(^Parser, cstring, c.int) -> c.int
// - ocsv_get_row_count(^Parser) -> c.int
// - ocsv_get_field_count(^Parser, c.int) -> c.int

// Transform System (PRP-09):
// - Transform_Func: proc(string, allocator) -> string
// - Transform_Registry: Transform registry
// - Transform_Pipeline: Transform pipeline
// - registry_create() -> ^Transform_Registry
// - registry_destroy(^Transform_Registry)
// - register_transform(^Transform_Registry, string, Transform_Func)
// - apply_transform(^Transform_Registry, string, string, allocator) -> string
// - apply_transform_to_row(^Transform_Registry, string, []string, int, allocator) -> bool
// - apply_transform_to_column(^Transform_Registry, string, [][]string, int, allocator)
// - pipeline_create() -> ^Transform_Pipeline
// - pipeline_destroy(^Transform_Pipeline)
// - pipeline_add_step(^Transform_Pipeline, string, int)
// - pipeline_apply_to_row(^Transform_Pipeline, ^Transform_Registry, []string, allocator)
// - pipeline_apply_to_all(^Transform_Pipeline, ^Transform_Registry, [][]string, allocator)
//
// Built-in Transforms:
// - TRANSFORM_TRIM, TRANSFORM_TRIM_LEFT, TRANSFORM_TRIM_RIGHT
// - TRANSFORM_UPPERCASE, TRANSFORM_LOWERCASE, TRANSFORM_CAPITALIZE
// - TRANSFORM_NORMALIZE_SPACE, TRANSFORM_REMOVE_QUOTES
// - TRANSFORM_PARSE_FLOAT, TRANSFORM_PARSE_INT, TRANSFORM_PARSE_BOOL
// - TRANSFORM_DATE_ISO8601

// Parallel Processing (PRP-10):
// - Parallel_Config: Configuration for parallel parsing
// - parse_parallel(string, Parallel_Config, allocator) -> (^Parser, bool)
// - get_optimal_thread_count(int) -> int
// - find_safe_chunks(string, int) -> []Chunk
// - find_next_row_boundary(string, int) -> int
