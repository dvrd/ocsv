package tests

import "core:testing"
import "core:strings"
import ocsv "../src"

//
// Transform Registry Tests
//

@(test)
test_registry_create_destroy :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    testing.expect(t, registry != nil, "Registry should be created")
    testing.expect(t, len(registry.transforms) > 0, "Registry should have built-in transforms")
}

@(test)
test_register_custom_transform :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    // Register a custom transform
    custom_transform :: proc(field: string, allocator := context.allocator) -> string {
        return strings.clone("custom", allocator)
    }

    ocsv.register_transform(registry, "custom", custom_transform)

    // Verify it's registered
    result := ocsv.apply_transform(registry, "custom", "test")
    defer delete(result)

    testing.expect_value(t, result, "custom")
}

//
// String Transform Tests
//

@(test)
test_transform_trim :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_TRIM, "  hello  ")
    defer delete(result)

    testing.expect_value(t, result, "hello")
}

@(test)
test_transform_trim_left :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_TRIM_LEFT, "  hello  ")
    defer delete(result)

    testing.expect_value(t, result, "hello  ")
}

@(test)
test_transform_trim_right :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_TRIM_RIGHT, "  hello  ")
    defer delete(result)

    testing.expect_value(t, result, "  hello")
}

@(test)
test_transform_uppercase :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_UPPERCASE, "hello")
    defer delete(result)

    testing.expect_value(t, result, "HELLO")
}

@(test)
test_transform_lowercase :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_LOWERCASE, "HELLO")
    defer delete(result)

    testing.expect_value(t, result, "hello")
}

@(test)
test_transform_capitalize :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_CAPITALIZE, "hello world")
    defer delete(result)

    testing.expect_value(t, result, "Hello world")
}

@(test)
test_transform_normalize_space :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_NORMALIZE_SPACE, "hello    world  \n  test")
    defer delete(result)

    testing.expect_value(t, result, "hello world test")
}

@(test)
test_transform_remove_quotes :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    // Double quotes
    result1 := ocsv.apply_transform(registry, ocsv.TRANSFORM_REMOVE_QUOTES, "\"hello\"")
    defer delete(result1)
    testing.expect_value(t, result1, "hello")

    // Single quotes
    result2 := ocsv.apply_transform(registry, ocsv.TRANSFORM_REMOVE_QUOTES, "'hello'")
    defer delete(result2)
    testing.expect_value(t, result2, "hello")

    // No quotes
    result3 := ocsv.apply_transform(registry, ocsv.TRANSFORM_REMOVE_QUOTES, "hello")
    defer delete(result3)
    testing.expect_value(t, result3, "hello")
}

//
// Numeric Transform Tests
//

@(test)
test_transform_parse_float :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    // Valid float
    result1 := ocsv.apply_transform(registry, ocsv.TRANSFORM_PARSE_FLOAT, "123.45")
    defer delete(result1)
    testing.expect_value(t, result1, "123.45")

    // Invalid float
    result2 := ocsv.apply_transform(registry, ocsv.TRANSFORM_PARSE_FLOAT, "not a number")
    defer delete(result2)
    testing.expect_value(t, result2, "0.0")
}

@(test)
test_transform_parse_int :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    // Valid int
    result1 := ocsv.apply_transform(registry, ocsv.TRANSFORM_PARSE_INT, "123")
    defer delete(result1)
    testing.expect_value(t, result1, "123")

    // Invalid int
    result2 := ocsv.apply_transform(registry, ocsv.TRANSFORM_PARSE_INT, "not a number")
    defer delete(result2)
    testing.expect_value(t, result2, "0")
}

@(test)
test_transform_parse_bool :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    // Truthy values
    truthy_values := []string{"true", "True", "TRUE", "yes", "Yes", "1", "t", "y"}
    for value in truthy_values {
        result := ocsv.apply_transform(registry, ocsv.TRANSFORM_PARSE_BOOL, value)
        defer delete(result)
        testing.expect_value(t, result, "true")
    }

    // Falsy values
    falsy_values := []string{"false", "False", "FALSE", "no", "No", "0", "f", "n", ""}
    for value in falsy_values {
        result := ocsv.apply_transform(registry, ocsv.TRANSFORM_PARSE_BOOL, value)
        defer delete(result)
        testing.expect_value(t, result, "false")
    }

    // Unknown defaults to false
    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_PARSE_BOOL, "maybe")
    defer delete(result)
    testing.expect_value(t, result, "false")
}

//
// Date Transform Tests
//

@(test)
test_transform_date_iso8601 :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    // Valid ISO 8601 date
    result1 := ocsv.apply_transform(registry, ocsv.TRANSFORM_DATE_ISO8601, "2024-01-15")
    defer delete(result1)
    testing.expect_value(t, result1, "2024-01-15")

    // Valid ISO 8601 datetime
    result2 := ocsv.apply_transform(registry, ocsv.TRANSFORM_DATE_ISO8601, "2024-01-15T10:30:00")
    defer delete(result2)
    testing.expect_value(t, result2, "2024-01-15T10:30:00")

    // Invalid date
    result3 := ocsv.apply_transform(registry, ocsv.TRANSFORM_DATE_ISO8601, "not a date")
    defer delete(result3)
    testing.expect_value(t, result3, "")
}

//
// Row and Column Transform Tests
//

@(test)
test_apply_transform_to_row :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    row := []string{
        strings.clone("  hello  "),
        strings.clone("world"),
        strings.clone("  test  "),
    }
    defer for field in row do delete(field)

    // Apply trim to first field
    ok := ocsv.apply_transform_to_row(registry, ocsv.TRANSFORM_TRIM, row, 0)
    testing.expect(t, ok, "Transform should succeed")
    testing.expect_value(t, row[0], "hello")
    testing.expect_value(t, row[1], "world") // Unchanged
}

@(test)
test_apply_transform_to_column :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    rows := [][]string{
        {strings.clone("hello"), strings.clone("123")},
        {strings.clone("world"), strings.clone("456")},
        {strings.clone("test"), strings.clone("789")},
    }
    defer {
        for row in rows {
            for field in row do delete(field)
        }
    }

    // Apply uppercase to first column
    ocsv.apply_transform_to_column(registry, ocsv.TRANSFORM_UPPERCASE, rows, 0)

    testing.expect_value(t, rows[0][0], "HELLO")
    testing.expect_value(t, rows[1][0], "WORLD")
    testing.expect_value(t, rows[2][0], "TEST")
    testing.expect_value(t, rows[0][1], "123") // Second column unchanged
}

//
// Pipeline Tests
//

@(test)
test_pipeline_single_transform :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    pipeline := ocsv.pipeline_create()
    defer ocsv.pipeline_destroy(pipeline)

    // Add trim to first field
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_TRIM, 0)

    row := []string{
        strings.clone("  hello  "),
        strings.clone("world"),
    }
    defer for field in row do delete(field)

    ocsv.pipeline_apply_to_row(pipeline, registry, row)

    testing.expect_value(t, row[0], "hello")
    testing.expect_value(t, row[1], "world")
}

@(test)
test_pipeline_multiple_transforms :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    pipeline := ocsv.pipeline_create()
    defer ocsv.pipeline_destroy(pipeline)

    // Add trim then uppercase to first field
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_TRIM, 0)
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_UPPERCASE, 0)

    row := []string{
        strings.clone("  hello  "),
        strings.clone("world"),
    }
    defer for field in row do delete(field)

    ocsv.pipeline_apply_to_row(pipeline, registry, row)

    testing.expect_value(t, row[0], "HELLO")
    testing.expect_value(t, row[1], "world")
}

@(test)
test_pipeline_all_fields :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    pipeline := ocsv.pipeline_create()
    defer ocsv.pipeline_destroy(pipeline)

    // Add trim to all fields (-1 means all fields)
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_TRIM, -1)

    row := []string{
        strings.clone("  hello  "),
        strings.clone("  world  "),
        strings.clone("  test  "),
    }
    defer for field in row do delete(field)

    ocsv.pipeline_apply_to_row(pipeline, registry, row)

    testing.expect_value(t, row[0], "hello")
    testing.expect_value(t, row[1], "world")
    testing.expect_value(t, row[2], "test")
}

@(test)
test_pipeline_apply_to_all_rows :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    pipeline := ocsv.pipeline_create()
    defer ocsv.pipeline_destroy(pipeline)

    // Trim all fields, then uppercase first column
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_TRIM, -1)
    ocsv.pipeline_add_step(pipeline, ocsv.TRANSFORM_UPPERCASE, 0)

    rows := [][]string{
        {strings.clone("  hello  "), strings.clone("  123  ")},
        {strings.clone("  world  "), strings.clone("  456  ")},
    }
    defer {
        for row in rows {
            for field in row do delete(field)
        }
    }

    ocsv.pipeline_apply_to_all(pipeline, registry, rows)

    testing.expect_value(t, rows[0][0], "HELLO")
    testing.expect_value(t, rows[0][1], "123")
    testing.expect_value(t, rows[1][0], "WORLD")
    testing.expect_value(t, rows[1][1], "456")
}

//
// Integration Tests
//

@(test)
test_transform_with_parser :: proc(t: ^testing.T) {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    csv_data := "  Name  ,  Age  \n  Alice  ,  30  \n  Bob  ,  25  \n"
    ok := ocsv.parse_csv(parser, csv_data)
    testing.expect(t, ok, "Parse should succeed")

    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    // Apply trim to all fields in all rows
    for row in parser.all_rows {
        for field, i in row {
            old_value := field
            new_value := ocsv.apply_transform(registry, ocsv.TRANSFORM_TRIM, old_value)
            row[i] = new_value
            delete(old_value)
        }
    }

    testing.expect_value(t, parser.all_rows[0][0], "Name")
    testing.expect_value(t, parser.all_rows[0][1], "Age")
    testing.expect_value(t, parser.all_rows[1][0], "Alice")
    testing.expect_value(t, parser.all_rows[1][1], "30")
}

//
// Edge Case Tests
//

@(test)
test_transform_empty_string :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    result := ocsv.apply_transform(registry, ocsv.TRANSFORM_TRIM, "")
    defer delete(result)

    testing.expect_value(t, result, "")
}

@(test)
test_transform_nonexistent :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    // Should return original field if transform not found
    result := ocsv.apply_transform(registry, "nonexistent", "hello")
    defer delete(result)

    testing.expect_value(t, result, "hello")
}

@(test)
test_pipeline_empty :: proc(t: ^testing.T) {
    registry := ocsv.registry_create()
    defer ocsv.registry_destroy(registry)

    pipeline := ocsv.pipeline_create()
    defer ocsv.pipeline_destroy(pipeline)

    row := []string{strings.clone("hello")}
    defer delete(row[0])

    // Apply empty pipeline (should do nothing)
    ocsv.pipeline_apply_to_row(pipeline, registry, row)

    testing.expect_value(t, row[0], "hello")
}
