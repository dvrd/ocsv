package ocsv

// Transform system for CSV field transformations
// Provides built-in transforms and a registry system for custom transforms

import "core:strings"
import "core:strconv"
import "core:time"
import "core:unicode"
import "core:unicode/utf8"
import "core:mem"

// Transform_Func is a procedure that transforms a field value
// Takes a field string and returns the transformed string
// The allocator parameter allows custom memory management
Transform_Func :: #type proc(field: string, allocator := context.allocator) -> string

// Transform_Registry manages a collection of named transforms
Transform_Registry :: struct {
    transforms: map[string]Transform_Func,
    allocator:  mem.Allocator,
}

// Built-in transform names
TRANSFORM_TRIM           :: "trim"
TRANSFORM_TRIM_LEFT      :: "trim_left"
TRANSFORM_TRIM_RIGHT     :: "trim_right"
TRANSFORM_UPPERCASE      :: "uppercase"
TRANSFORM_LOWERCASE      :: "lowercase"
TRANSFORM_CAPITALIZE     :: "capitalize"
TRANSFORM_NORMALIZE_SPACE :: "normalize_space"
TRANSFORM_REMOVE_QUOTES  :: "remove_quotes"
TRANSFORM_PARSE_FLOAT    :: "parse_float"
TRANSFORM_PARSE_INT      :: "parse_int"
TRANSFORM_PARSE_BOOL     :: "parse_bool"
TRANSFORM_DATE_ISO8601   :: "date_iso8601"

// registry_create creates a new transform registry with built-in transforms
registry_create :: proc(allocator := context.allocator) -> ^Transform_Registry {
    registry := new(Transform_Registry, allocator)
    registry.allocator = allocator
    registry.transforms = make(map[string]Transform_Func, 16, allocator)

    // Register built-in transforms
    register_builtin_transforms(registry)

    return registry
}

// registry_destroy frees the registry and its resources
registry_destroy :: proc(registry: ^Transform_Registry) {
    if registry == nil do return

    delete(registry.transforms)
    free(registry, registry.allocator)
}

// register_transform adds a custom transform to the registry
register_transform :: proc(registry: ^Transform_Registry, name: string, fn: Transform_Func) {
    registry.transforms[name] = fn
}

// apply_transform applies a named transform to a field
// Returns the original field if the transform is not found
apply_transform :: proc(registry: ^Transform_Registry, name: string, field: string, allocator := context.allocator) -> string {
    if fn, ok := registry.transforms[name]; ok {
        return fn(field, allocator)
    }
    return strings.clone(field, allocator)
}

// register_builtin_transforms registers all built-in transforms
register_builtin_transforms :: proc(registry: ^Transform_Registry) {
    register_transform(registry, TRANSFORM_TRIM, transform_trim)
    register_transform(registry, TRANSFORM_TRIM_LEFT, transform_trim_left)
    register_transform(registry, TRANSFORM_TRIM_RIGHT, transform_trim_right)
    register_transform(registry, TRANSFORM_UPPERCASE, transform_uppercase)
    register_transform(registry, TRANSFORM_LOWERCASE, transform_lowercase)
    register_transform(registry, TRANSFORM_CAPITALIZE, transform_capitalize)
    register_transform(registry, TRANSFORM_NORMALIZE_SPACE, transform_normalize_space)
    register_transform(registry, TRANSFORM_REMOVE_QUOTES, transform_remove_quotes)
    register_transform(registry, TRANSFORM_PARSE_FLOAT, transform_parse_float)
    register_transform(registry, TRANSFORM_PARSE_INT, transform_parse_int)
    register_transform(registry, TRANSFORM_PARSE_BOOL, transform_parse_bool)
    register_transform(registry, TRANSFORM_DATE_ISO8601, transform_date_iso8601)
}

//
// Built-in String Transforms
//

// transform_trim removes leading and trailing whitespace
transform_trim :: proc(field: string, allocator := context.allocator) -> string {
    trimmed := strings.trim_space(field)
    return strings.clone(trimmed, allocator)
}

// transform_trim_left removes leading whitespace
transform_trim_left :: proc(field: string, allocator := context.allocator) -> string {
    trimmed := strings.trim_left_space(field)
    return strings.clone(trimmed, allocator)
}

// transform_trim_right removes trailing whitespace
transform_trim_right :: proc(field: string, allocator := context.allocator) -> string {
    trimmed := strings.trim_right_space(field)
    return strings.clone(trimmed, allocator)
}

// transform_uppercase converts to uppercase
transform_uppercase :: proc(field: string, allocator := context.allocator) -> string {
    return strings.to_upper(field, allocator)
}

// transform_lowercase converts to lowercase
transform_lowercase :: proc(field: string, allocator := context.allocator) -> string {
    return strings.to_lower(field, allocator)
}

// transform_capitalize capitalizes the first letter
transform_capitalize :: proc(field: string, allocator := context.allocator) -> string {
    if len(field) == 0 do return strings.clone("", allocator)

    builder := strings.builder_make(allocator)
    defer strings.builder_destroy(&builder)

    first := true
    for r in field {
        if first {
            strings.write_rune(&builder, unicode.to_upper(r))
            first = false
        } else {
            strings.write_rune(&builder, unicode.to_lower(r))
        }
    }

    return strings.clone(strings.to_string(builder), allocator)
}

// transform_normalize_space normalizes whitespace (collapses multiple spaces to one)
transform_normalize_space :: proc(field: string, allocator := context.allocator) -> string {
    builder := strings.builder_make(allocator)
    defer strings.builder_destroy(&builder)

    prev_space := false
    for r in field {
        is_space := unicode.is_white_space(r)
        if is_space {
            if !prev_space {
                strings.write_rune(&builder, ' ')
                prev_space = true
            }
        } else {
            strings.write_rune(&builder, r)
            prev_space = false
        }
    }

    result := strings.to_string(builder)
    return strings.clone(strings.trim_space(result), allocator)
}

// transform_remove_quotes removes surrounding quotes
transform_remove_quotes :: proc(field: string, allocator := context.allocator) -> string {
    trimmed := strings.trim_space(field)

    if len(trimmed) >= 2 {
        first := trimmed[0]
        last := trimmed[len(trimmed)-1]

        if (first == '"' && last == '"') || (first == '\'' && last == '\'') {
            return strings.clone(trimmed[1:len(trimmed)-1], allocator)
        }
    }

    return strings.clone(trimmed, allocator)
}

//
// Built-in Numeric Transforms
//

// transform_parse_float converts to float and back to string (validates numeric)
transform_parse_float :: proc(field: string, allocator := context.allocator) -> string {
    trimmed := strings.trim_space(field)

    if value, ok := strconv.parse_f64(trimmed); ok {
        return strings.clone(trimmed, allocator)
    }

    // Return "0.0" for invalid values
    return strings.clone("0.0", allocator)
}

// transform_parse_int converts to int and back to string (validates integer)
transform_parse_int :: proc(field: string, allocator := context.allocator) -> string {
    trimmed := strings.trim_space(field)

    if value, ok := strconv.parse_i64(trimmed); ok {
        return strings.clone(trimmed, allocator)
    }

    // Return "0" for invalid values
    return strings.clone("0", allocator)
}

// transform_parse_bool converts to boolean string ("true" or "false")
transform_parse_bool :: proc(field: string, allocator := context.allocator) -> string {
    trimmed := strings.trim_space(field)
    lower := strings.to_lower(trimmed, context.temp_allocator)

    // Check for truthy values
    if lower == "true" || lower == "yes" || lower == "1" || lower == "t" || lower == "y" {
        return strings.clone("true", allocator)
    }

    // Check for falsy values
    if lower == "false" || lower == "no" || lower == "0" || lower == "f" || lower == "n" || lower == "" {
        return strings.clone("false", allocator)
    }

    // Unknown values default to false
    return strings.clone("false", allocator)
}

//
// Built-in Date Transforms
//

// transform_date_iso8601 validates and normalizes ISO 8601 date format
// Accepts: YYYY-MM-DD, YYYY-MM-DDTHH:MM:SS, etc.
// Returns: Normalized ISO 8601 format or original if invalid
transform_date_iso8601 :: proc(field: string, allocator := context.allocator) -> string {
    trimmed := strings.trim_space(field)

    // Simple validation: check if it starts with YYYY-MM-DD pattern
    if len(trimmed) >= 10 {
        // Check basic format: digits-digits-digits
        if trimmed[4] == '-' && trimmed[7] == '-' {
            // Basic validation passed, return as-is
            return strings.clone(trimmed, allocator)
        }
    }

    // Invalid date format, return empty string
    return strings.clone("", allocator)
}

//
// Transform Application Helpers
//

// apply_transform_to_row applies a transform to a specific field in a row
apply_transform_to_row :: proc(
    registry: ^Transform_Registry,
    transform_name: string,
    row: []string,
    field_index: int,
    allocator := context.allocator,
) -> bool {
    if field_index < 0 || field_index >= len(row) do return false

    old_value := row[field_index]
    new_value := apply_transform(registry, transform_name, old_value, allocator)

    // Free old value and replace
    delete(old_value)
    row[field_index] = new_value

    return true
}

// apply_transform_to_column applies a transform to all fields in a column
apply_transform_to_column :: proc(
    registry: ^Transform_Registry,
    transform_name: string,
    rows: [][]string,
    field_index: int,
    allocator := context.allocator,
) {
    for row in rows {
        if field_index < len(row) {
            apply_transform_to_row(registry, transform_name, row, field_index, allocator)
        }
    }
}

// Transform_Pipeline represents a series of transforms to apply
Transform_Pipeline :: struct {
    steps: [dynamic]Transform_Step,
}

// Transform_Step is a single step in a transform pipeline
Transform_Step :: struct {
    transform_name: string,
    field_index:    int,  // -1 means apply to all fields
}

// pipeline_create creates a new transform pipeline
pipeline_create :: proc(allocator := context.allocator) -> ^Transform_Pipeline {
    pipeline := new(Transform_Pipeline, allocator)
    pipeline.steps = make([dynamic]Transform_Step, allocator)
    return pipeline
}

// pipeline_destroy frees the pipeline
pipeline_destroy :: proc(pipeline: ^Transform_Pipeline) {
    if pipeline == nil do return
    delete(pipeline.steps)
    free(pipeline)
}

// pipeline_add_step adds a transform step to the pipeline
pipeline_add_step :: proc(pipeline: ^Transform_Pipeline, transform_name: string, field_index: int) {
    append(&pipeline.steps, Transform_Step{transform_name, field_index})
}

// pipeline_apply_to_row applies all pipeline steps to a row
pipeline_apply_to_row :: proc(
    pipeline: ^Transform_Pipeline,
    registry: ^Transform_Registry,
    row: []string,
    allocator := context.allocator,
) {
    for step in pipeline.steps {
        if step.field_index == -1 {
            // Apply to all fields
            for i in 0..<len(row) {
                apply_transform_to_row(registry, step.transform_name, row, i, allocator)
            }
        } else {
            // Apply to specific field
            apply_transform_to_row(registry, step.transform_name, row, step.field_index, allocator)
        }
    }
}

// pipeline_apply_to_all applies all pipeline steps to all rows
pipeline_apply_to_all :: proc(
    pipeline: ^Transform_Pipeline,
    registry: ^Transform_Registry,
    rows: [][]string,
    allocator := context.allocator,
) {
    for row in rows {
        pipeline_apply_to_row(pipeline, registry, row, allocator)
    }
}
