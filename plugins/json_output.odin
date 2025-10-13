package ocsv_plugins

// JSON Output Plugin Example
// Demonstrates how to create a custom output plugin for OCSV

import "core:strings"
import ocsv "../src"

// write_json converts parsed CSV data to JSON array format
// Output format: [["field1","field2"],["value1","value2"],...]
//
// This is a simplified JSON output that creates a 2D array.
// For production use, consider:
// - Adding options for object-based JSON (with headers as keys)
// - Proper JSON escaping for special characters
// - Pretty printing options
// - Streaming output for large datasets
write_json :: proc(parser: ^ocsv.Parser, allocator := context.allocator) -> string {
    builder := strings.builder_make(allocator)

    // Start JSON array
    strings.write_string(&builder, "[")

    // Iterate through all rows
    for row, row_idx in parser.all_rows {
        // Add comma separator between rows
        if row_idx > 0 {
            strings.write_string(&builder, ",")
        }

        // Start row array
        strings.write_string(&builder, "[")

        // Iterate through fields in row
        for field, field_idx in row {
            // Add comma separator between fields
            if field_idx > 0 {
                strings.write_string(&builder, ",")
            }

            // Write field as quoted string
            strings.write_string(&builder, "\"")
            // TODO: Proper JSON escaping for ", \, /, \b, \f, \n, \r, \t
            // For now, just write the field directly
            strings.write_string(&builder, field)
            strings.write_string(&builder, "\"")
        }

        // End row array
        strings.write_string(&builder, "]")
    }

    // End JSON array
    strings.write_string(&builder, "]")

    return strings.to_string(builder)
}

// write_json_objects converts parsed CSV to JSON array of objects
// First row is treated as headers, subsequent rows as data
// Output format: [{"col1":"val1","col2":"val2"},...]
write_json_objects :: proc(parser: ^ocsv.Parser, allocator := context.allocator) -> string {
    if len(parser.all_rows) == 0 {
        return "[]"
    }

    builder := strings.builder_make(allocator)

    // Get headers from first row
    headers := parser.all_rows[0]

    // Start JSON array
    strings.write_string(&builder, "[")

    // Iterate through data rows (skip header row)
    for row_idx := 1; row_idx < len(parser.all_rows); row_idx += 1 {
        row := parser.all_rows[row_idx]

        // Add comma separator between objects
        if row_idx > 1 {
            strings.write_string(&builder, ",")
        }

        // Start object
        strings.write_string(&builder, "{")

        // Iterate through fields
        field_count := min(len(headers), len(row))
        for field_idx := 0; field_idx < field_count; field_idx += 1 {
            // Add comma separator between properties
            if field_idx > 0 {
                strings.write_string(&builder, ",")
            }

            // Write property: "header":"value"
            strings.write_string(&builder, "\"")
            strings.write_string(&builder, headers[field_idx])
            strings.write_string(&builder, "\":\"")
            strings.write_string(&builder, row[field_idx])
            strings.write_string(&builder, "\"")
        }

        // End object
        strings.write_string(&builder, "}")
    }

    // End JSON array
    strings.write_string(&builder, "]")

    return strings.to_string(builder)
}

// JSON_Output_Plugin is the plugin definition for array-based JSON
// Register this with plugin_registry_create() to use it
JSON_Output_Plugin :: ocsv.Output_Plugin{
    name = "json",
    description = "Outputs parsed CSV data as JSON array (2D array format)",
    write = write_json,
    // No init/cleanup needed for this simple plugin
    init = nil,
    cleanup = nil,
}

// JSON_Objects_Output_Plugin is the plugin definition for object-based JSON
// Uses first row as headers, outputs array of objects
JSON_Objects_Output_Plugin :: ocsv.Output_Plugin{
    name = "json_objects",
    description = "Outputs parsed CSV data as JSON array of objects (first row = headers)",
    write = write_json_objects,
    // No init/cleanup needed for this simple plugin
    init = nil,
    cleanup = nil,
}

// Example usage:
// ```odin
// registry := ocsv.plugin_registry_create()
// defer ocsv.plugin_registry_destroy(registry)
//
// // Register plugins
// ocsv.plugin_register_output(registry, JSON_Output_Plugin)
// ocsv.plugin_register_output(registry, JSON_Objects_Output_Plugin)
//
// // Parse some CSV
// parser := ocsv.parser_create()
// defer ocsv.parser_destroy(parser)
// ocsv.parse_csv(parser, "name,age\nAlice,30\nBob,25")
//
// // Use array format
// output1, _ := ocsv.plugin_get_output(registry, "json")
// json1 := output1.write(parser)
// // json1 = [["name","age"],["Alice","30"],["Bob","25"]]
//
// // Use object format
// output2, _ := ocsv.plugin_get_output(registry, "json_objects")
// json2 := output2.write(parser)
// // json2 = [{"name":"Alice","age":"30"},{"name":"Bob","age":"25"}]
// ```
