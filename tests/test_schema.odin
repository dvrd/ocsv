package tests

import "core:testing"
import "core:fmt"
import ocsv "../src"

// Test basic type validation
@(test)
test_schema_validate_int :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "id", col_type = .Int, required = true},
    })

    // Valid integer
    result := ocsv.validate_row(&schema, []string{"123"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, result.valid, "Valid integer should pass")

    // Invalid integer
    result2 := ocsv.validate_row(&schema, []string{"abc"}, 1)
    defer ocsv.validation_result_destroy(&result2)
    testing.expect(t, !result2.valid, "Invalid integer should fail")
    testing.expect(t, len(result2.errors) > 0, "Should have error")
}

@(test)
test_schema_validate_float :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "price", col_type = .Float, required = true},
    })

    // Valid float
    result := ocsv.validate_row(&schema, []string{"19.99"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, result.valid, "Valid float should pass")

    // Valid integer as float
    result2 := ocsv.validate_row(&schema, []string{"20"}, 1)
    defer ocsv.validation_result_destroy(&result2)
    testing.expect(t, result2.valid, "Integer as float should pass")

    // Invalid float
    result3 := ocsv.validate_row(&schema, []string{"not-a-number"}, 1)
    defer ocsv.validation_result_destroy(&result3)
    testing.expect(t, !result3.valid, "Invalid float should fail")
}

@(test)
test_schema_validate_bool :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "active", col_type = .Bool, required = true},
    })

    valid_bools := []string{"true", "false", "yes", "no", "1", "0", "t", "f", "TRUE", "FALSE"}

    for value in valid_bools {
        result := ocsv.validate_row(&schema, []string{value}, 1)
        defer ocsv.validation_result_destroy(&result)
        testing.expect(t, result.valid, fmt.tprintf("'%s' should be valid bool", value))
    }

    // Invalid bool
    result := ocsv.validate_row(&schema, []string{"maybe"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, !result.valid, "Invalid bool should fail")
}

@(test)
test_schema_required_field :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "name", col_type = .String, required = true, nullable = false},
    })

    // Empty string should fail
    result := ocsv.validate_row(&schema, []string{""}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, !result.valid, "Empty required field should fail")
    testing.expect(t, len(result.errors) > 0, "Should have error")
}

@(test)
test_schema_nullable_field :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "description", col_type = .String, required = false, nullable = true},
    })

    // Empty string should pass
    result := ocsv.validate_row(&schema, []string{""}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, result.valid, "Empty nullable field should pass")
}

@(test)
test_schema_min_max_value :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {
            name = "age",
            col_type = .Int,
            required = true,
            min_value = 0.0,
            max_value = 120.0,
        },
    })

    // Valid value
    result := ocsv.validate_row(&schema, []string{"25"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, result.valid, "Value within range should pass")

    // Below minimum
    result2 := ocsv.validate_row(&schema, []string{"-5"}, 1)
    defer ocsv.validation_result_destroy(&result2)
    testing.expect(t, !result2.valid, "Value below minimum should fail")

    // Above maximum
    result3 := ocsv.validate_row(&schema, []string{"150"}, 1)
    defer ocsv.validation_result_destroy(&result3)
    testing.expect(t, !result3.valid, "Value above maximum should fail")
}

@(test)
test_schema_string_length :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {
            name = "code",
            col_type = .String,
            required = true,
            min_length = 3,
            max_length = 10,
        },
    })

    // Valid length
    result := ocsv.validate_row(&schema, []string{"ABC123"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, result.valid, "String within length range should pass")

    // Too short
    result2 := ocsv.validate_row(&schema, []string{"AB"}, 1)
    defer ocsv.validation_result_destroy(&result2)
    testing.expect(t, !result2.valid, "String below minimum length should fail")

    // Too long
    result3 := ocsv.validate_row(&schema, []string{"ABCDEFGHIJK"}, 1)
    defer ocsv.validation_result_destroy(&result3)
    testing.expect(t, !result3.valid, "String above maximum length should fail")
}

@(test)
test_schema_allowed_values :: proc(t: ^testing.T) {
    allowed := []string{"red", "green", "blue"}
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {
            name = "color",
            col_type = .String,
            required = true,
            allowed_values = allowed,
        },
    })

    // Valid value
    result := ocsv.validate_row(&schema, []string{"red"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, result.valid, "Allowed value should pass")

    // Invalid value
    result2 := ocsv.validate_row(&schema, []string{"yellow"}, 1)
    defer ocsv.validation_result_destroy(&result2)
    testing.expect(t, !result2.valid, "Disallowed value should fail")
}

@(test)
test_schema_custom_validator :: proc(t: ^testing.T) {
    // Custom validator: email must contain @
    email_validator :: proc(value: string, ctx: rawptr) -> (bool, string) {
        for ch in value {
            if ch == '@' {
                return true, ""
            }
        }
        return false, fmt.aprintf("Email must contain @")
    }

    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {
            name = "email",
            col_type = .Custom,
            required = true,
            custom_validator = email_validator,
        },
    })

    // Valid email
    result := ocsv.validate_row(&schema, []string{"user@example.com"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, result.valid, "Valid email should pass")

    // Invalid email
    result2 := ocsv.validate_row(&schema, []string{"invalid-email"}, 1)
    defer ocsv.validation_result_destroy(&result2)
    testing.expect(t, !result2.valid, "Invalid email should fail")
}

@(test)
test_schema_multiple_columns :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "id", col_type = .Int, required = true},
        {name = "name", col_type = .String, required = true},
        {name = "price", col_type = .Float, required = true},
        {name = "active", col_type = .Bool, required = true},
    })

    // Valid row
    result := ocsv.validate_row(&schema, []string{"1", "Product", "19.99", "true"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, result.valid, "Valid row should pass")

    // Invalid row (bad float)
    result2 := ocsv.validate_row(&schema, []string{"1", "Product", "not-a-price", "true"}, 1)
    defer ocsv.validation_result_destroy(&result2)
    testing.expect(t, !result2.valid, "Row with invalid float should fail")
}

@(test)
test_schema_missing_column :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "id", col_type = .Int, required = true},
        {name = "name", col_type = .String, required = true},
    })

    // Row with missing column
    result := ocsv.validate_row(&schema, []string{"1"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, !result.valid, "Row with missing required column should fail")
}

@(test)
test_schema_extra_column :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "id", col_type = .Int, required = true},
    })

    // Row with extra column
    result := ocsv.validate_row(&schema, []string{"1", "extra"}, 1)
    defer ocsv.validation_result_destroy(&result)
    testing.expect(t, !result.valid, "Row with extra column should fail by default")

    // Allow extra columns
    schema.allow_extra_columns = true
    result2 := ocsv.validate_row(&schema, []string{"1", "extra"}, 1)
    defer ocsv.validation_result_destroy(&result2)
    testing.expect(t, result2.valid, "Row with extra column should pass when allowed")
}

@(test)
test_convert_value_int :: proc(t: ^testing.T) {
    value, ok := ocsv.convert_value(.Int, "123")
    testing.expect(t, ok, "Should convert valid integer")

    int_val, is_int := value.(i64)
    testing.expect(t, is_int, "Should be i64 type")
    testing.expect_value(t, int_val, i64(123))

    // Invalid conversion
    _, ok2 := ocsv.convert_value(.Int, "abc")
    testing.expect(t, !ok2, "Should fail on invalid integer")
}

@(test)
test_convert_value_float :: proc(t: ^testing.T) {
    value, ok := ocsv.convert_value(.Float, "19.99")
    testing.expect(t, ok, "Should convert valid float")

    float_val, is_float := value.(f64)
    testing.expect(t, is_float, "Should be f64 type")
    testing.expect(t, float_val > 19.98 && float_val < 20.0, "Should be approximately 19.99")
}

@(test)
test_convert_value_bool :: proc(t: ^testing.T) {
    value, ok := ocsv.convert_value(.Bool, "true")
    testing.expect(t, ok, "Should convert 'true'")

    bool_val, is_bool := value.(bool)
    testing.expect(t, is_bool, "Should be bool type")
    testing.expect(t, bool_val == true, "Should be true")

    value2, ok2 := ocsv.convert_value(.Bool, "0")
    testing.expect(t, ok2, "Should convert '0'")

    bool_val2, is_bool2 := value2.(bool)
    testing.expect(t, is_bool2, "Should be bool type")
    testing.expect(t, bool_val2 == false, "Should be false")
}

@(test)
test_validate_and_convert :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "id", col_type = .Int, required = true},
        {name = "name", col_type = .String, required = true},
        {name = "price", col_type = .Float, required = true},
    }, strict = false, skip_header = true)

    rows := [][]string{
        {"id", "name", "price"},  // Header
        {"1", "Product A", "19.99"},
        {"2", "Product B", "29.99"},
    }

    typed_rows, result := ocsv.validate_and_convert(&schema, rows)
    defer {
        for row in typed_rows {
            delete(row)
        }
        delete(typed_rows)
        ocsv.validation_result_destroy(&result)
    }

    testing.expect(t, result.valid, "Should validate successfully")
    testing.expect_value(t, len(typed_rows), 2) // Header skipped

    // Check first row types
    id_val, is_int := typed_rows[0][0].(i64)
    testing.expect(t, is_int, "ID should be int")
    testing.expect_value(t, id_val, i64(1))

    name_val, is_string := typed_rows[0][1].(string)
    testing.expect(t, is_string, "Name should be string")
    testing.expect_value(t, name_val, "Product A")

    price_val, is_float := typed_rows[0][2].(f64)
    testing.expect(t, is_float, "Price should be float")
    testing.expect(t, price_val > 19.98 && price_val < 20.0, "Price should be approximately 19.99")
}

@(test)
test_schema_strict_mode :: proc(t: ^testing.T) {
    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {name = "id", col_type = .Int, required = true},
        {name = "value", col_type = .Int, required = true},
    }, strict = true)

    rows := [][]string{
        {"1", "100"},
        {"2", "invalid"},  // This should stop validation
        {"3", "300"},
    }

    typed_rows, result := ocsv.validate_and_convert(&schema, rows)
    defer {
        for row in typed_rows {
            delete(row)
        }
        delete(typed_rows)
        ocsv.validation_result_destroy(&result)
    }

    testing.expect(t, !result.valid, "Should fail in strict mode")
    testing.expect(t, len(result.errors) > 0, "Should have errors")
}

@(test)
test_schema_format_error :: proc(t: ^testing.T) {
    err := ocsv.Validation_Error{
        row = 5,
        column = 2,
        column_name = "price",
        value = "invalid",
        error_type = .None,
        message = "Invalid float value",
    }

    formatted := ocsv.format_validation_error(err)
    defer delete(formatted)

    testing.expect(t, len(formatted) > 0, "Formatted error should not be empty")

    // Check that it contains key information
    contains_row := false
    contains_col := false
    contains_name := false

    for i := 0; i < len(formatted); i += 1 {
        if i + 1 < len(formatted) && formatted[i] == '5' {
            contains_row = true
        }
        if i + 1 < len(formatted) && formatted[i] == '2' {
            contains_col = true
        }
        if i + 5 < len(formatted) && formatted[i:i+5] == "price" {
            contains_name = true
        }
    }

    testing.expect(t, contains_row, "Should contain row number")
    testing.expect(t, contains_col, "Should contain column number")
    testing.expect(t, contains_name, "Should contain column name")

    fmt.printfln("Formatted: %s", formatted)
}

@(test)
test_schema_real_world_example :: proc(t: ^testing.T) {
    // Real-world product catalog schema
    allowed_categories := []string{"Electronics", "Books", "Clothing"}

    schema := ocsv.schema_create([]ocsv.Column_Schema{
        {
            name = "sku",
            col_type = .String,
            required = true,
            min_length = 3,
            max_length = 20,
        },
        {
            name = "name",
            col_type = .String,
            required = true,
            min_length = 1,
            max_length = 100,
        },
        {
            name = "category",
            col_type = .String,
            required = true,
            allowed_values = allowed_categories,
        },
        {
            name = "price",
            col_type = .Float,
            required = true,
            min_value = 0.01,
            max_value = 9999.99,
        },
        {
            name = "in_stock",
            col_type = .Bool,
            required = true,
        },
        {
            name = "quantity",
            col_type = .Int,
            required = true,
            min_value = 0,
            max_value = 10000,
        },
    }, strict = false, skip_header = true)

    rows := [][]string{
        {"sku", "name", "category", "price", "in_stock", "quantity"},
        {"ABC-123", "Laptop", "Electronics", "999.99", "true", "50"},
        {"BOOK-456", "Programming in Odin", "Books", "49.99", "yes", "100"},
        {"CLO-789", "T-Shirt", "Clothing", "19.99", "1", "200"},
    }

    typed_rows, result := ocsv.validate_and_convert(&schema, rows)
    defer {
        for row in typed_rows {
            delete(row)
        }
        delete(typed_rows)
        ocsv.validation_result_destroy(&result)
    }

    testing.expect(t, result.valid, "Real-world example should validate")
    testing.expect_value(t, len(typed_rows), 3)
    testing.expect_value(t, result.rows_validated, 3) // Header skipped, not counted

    fmt.printfln("Validated %d rows successfully", len(typed_rows))
}
