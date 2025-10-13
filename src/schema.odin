package ocsv

// Schema validation system for CSV parsing
// Provides type checking, conversion, and custom validation rules

import "core:strconv"
import "core:strings"
import "core:fmt"
import "core:time"

// Column_Type represents the expected data type for a column
Column_Type :: enum {
    String,      // Any string (default)
    Int,         // Integer number
    Float,       // Floating-point number
    Bool,        // Boolean (true/false, yes/no, 1/0)
    Date,        // Date in various formats
    Custom,      // Custom validation function
}

// Validation_Rule represents a constraint on column values
Validation_Rule :: enum {
    None,           // No validation
    Required,       // Field cannot be empty
    Min_Value,      // Numeric minimum
    Max_Value,      // Numeric maximum
    Min_Length,     // String minimum length
    Max_Length,     // String maximum length
    Pattern,        // Regex pattern match
    One_Of,         // Value must be in allowed list
    Custom_Rule,    // Custom validation function
}

// Custom_Validator is a user-defined validation function
Custom_Validator :: proc(value: string, ctx: rawptr) -> (ok: bool, error_msg: string)

// Column_Schema defines validation rules for a single column
Column_Schema :: struct {
    name:           string,                  // Column name
    col_type:       Column_Type,             // Expected type
    required:       bool,                    // Is field required?
    nullable:       bool,                    // Can field be empty?
    min_value:      Maybe(f64),              // Minimum numeric value
    max_value:      Maybe(f64),              // Maximum numeric value
    min_length:     int,                     // Minimum string length
    max_length:     int,                     // Maximum string length (0 = unlimited)
    pattern:        string,                  // Regex pattern (not implemented yet)
    allowed_values: []string,                // Allowed values (enum)
    custom_validator: Custom_Validator,      // Custom validation function
    custom_ctx:     rawptr,                  // Context for custom validator
    default_value:  string,                  // Default value if empty
}

// Schema represents validation rules for all columns
Schema :: struct {
    columns:         []Column_Schema,        // Column definitions
    strict:          bool,                   // Strict mode (fail on any validation error)
    skip_header:     bool,                   // First row is header
    allow_extra_columns: bool,               // Allow more columns than defined
}

// Validation_Error represents a validation failure
Validation_Error :: struct {
    row:        int,            // Row number (1-indexed)
    column:     int,            // Column number (1-indexed)
    column_name: string,        // Column name
    value:      string,         // Actual value
    error_type: Validation_Rule, // Type of validation that failed
    message:    string,         // Error message
}

// Validation_Result contains the outcome of schema validation
Validation_Result :: struct {
    valid:      bool,                        // Overall validation result
    errors:     [dynamic]Validation_Error,   // Validation errors
    warnings:   [dynamic]Validation_Error,   // Non-fatal warnings
    rows_validated: int,                     // Number of rows validated
}

// Typed_Value represents a parsed and validated value
Typed_Value :: union {
    string,
    i64,
    f64,
    bool,
    time.Time,
}

// Typed_Row represents a row with typed values
Typed_Row :: []Typed_Value

// schema_create creates a new schema
schema_create :: proc(columns: []Column_Schema, strict: bool = false, skip_header: bool = true) -> Schema {
    return Schema{
        columns = columns,
        strict = strict,
        skip_header = skip_header,
        allow_extra_columns = false,
    }
}

// validate_row validates a single row against the schema
validate_row :: proc(schema: ^Schema, row: []string, row_num: int) -> (result: Validation_Result) {
    result.valid = true
    result.errors = make([dynamic]Validation_Error)
    result.warnings = make([dynamic]Validation_Error)
    result.rows_validated = 1

    // Check column count
    if !schema.allow_extra_columns && len(row) > len(schema.columns) {
        append(&result.errors, Validation_Error{
            row = row_num,
            column = len(schema.columns) + 1,
            column_name = "",
            value = "",
            error_type = .None,
            message = fmt.aprintf("Row has %d columns, expected %d", len(row), len(schema.columns)),
        })
        result.valid = false
        if schema.strict { return }
    }

    // Validate each column
    for col_schema, i in schema.columns {
        if i >= len(row) {
            // Missing column
            if col_schema.required {
                append(&result.errors, Validation_Error{
                    row = row_num,
                    column = i + 1,
                    column_name = col_schema.name,
                    value = "",
                    error_type = .Required,
                    message = fmt.aprintf("Required column '%s' is missing", col_schema.name),
                })
                result.valid = false
                if schema.strict { return }
            }
            continue
        }

        value := row[i]

        // Check if empty
        if len(value) == 0 {
            if col_schema.required && !col_schema.nullable {
                append(&result.errors, Validation_Error{
                    row = row_num,
                    column = i + 1,
                    column_name = col_schema.name,
                    value = value,
                    error_type = .Required,
                    message = fmt.aprintf("Column '%s' cannot be empty", col_schema.name),
                })
                result.valid = false
                if schema.strict { return }
            }
            continue
        }

        // Validate type
        type_valid := validate_type(col_schema.col_type, value)
        if !type_valid {
            append(&result.errors, Validation_Error{
                row = row_num,
                column = i + 1,
                column_name = col_schema.name,
                value = value,
                error_type = .None,
                message = fmt.aprintf("Column '%s' has invalid type. Expected %v, got '%s'",
                    col_schema.name, col_schema.col_type, value),
            })
            result.valid = false
            if schema.strict { return }
            continue
        }

        // Validate min/max for numeric types
        if col_schema.col_type == .Int || col_schema.col_type == .Float {
            num_value, ok := strconv.parse_f64(value)
            if ok {
                if min_val, has_min := col_schema.min_value.?; has_min {
                    if num_value < min_val {
                        append(&result.errors, Validation_Error{
                            row = row_num,
                            column = i + 1,
                            column_name = col_schema.name,
                            value = value,
                            error_type = .Min_Value,
                            message = fmt.aprintf("Column '%s' value %f is less than minimum %f",
                                col_schema.name, num_value, min_val),
                        })
                        result.valid = false
                        if schema.strict { return }
                    }
                }

                if max_val, has_max := col_schema.max_value.?; has_max {
                    if num_value > max_val {
                        append(&result.errors, Validation_Error{
                            row = row_num,
                            column = i + 1,
                            column_name = col_schema.name,
                            value = value,
                            error_type = .Max_Value,
                            message = fmt.aprintf("Column '%s' value %f exceeds maximum %f",
                                col_schema.name, num_value, max_val),
                        })
                        result.valid = false
                        if schema.strict { return }
                    }
                }
            }
        }

        // Validate string length
        if col_schema.col_type == .String {
            if col_schema.min_length > 0 && len(value) < col_schema.min_length {
                append(&result.errors, Validation_Error{
                    row = row_num,
                    column = i + 1,
                    column_name = col_schema.name,
                    value = value,
                    error_type = .Min_Length,
                    message = fmt.aprintf("Column '%s' length %d is less than minimum %d",
                        col_schema.name, len(value), col_schema.min_length),
                })
                result.valid = false
                if schema.strict { return }
            }

            if col_schema.max_length > 0 && len(value) > col_schema.max_length {
                append(&result.errors, Validation_Error{
                    row = row_num,
                    column = i + 1,
                    column_name = col_schema.name,
                    value = value,
                    error_type = .Max_Length,
                    message = fmt.aprintf("Column '%s' length %d exceeds maximum %d",
                        col_schema.name, len(value), col_schema.max_length),
                })
                result.valid = false
                if schema.strict { return }
            }
        }

        // Validate allowed values
        if len(col_schema.allowed_values) > 0 {
            found := false
            for allowed in col_schema.allowed_values {
                if value == allowed {
                    found = true
                    break
                }
            }
            if !found {
                append(&result.errors, Validation_Error{
                    row = row_num,
                    column = i + 1,
                    column_name = col_schema.name,
                    value = value,
                    error_type = .One_Of,
                    message = fmt.aprintf("Column '%s' value '%s' is not in allowed values",
                        col_schema.name, value),
                })
                result.valid = false
                if schema.strict { return }
            }
        }

        // Custom validation
        if col_schema.custom_validator != nil {
            valid, err_msg := col_schema.custom_validator(value, col_schema.custom_ctx)
            if !valid {
                append(&result.errors, Validation_Error{
                    row = row_num,
                    column = i + 1,
                    column_name = col_schema.name,
                    value = value,
                    error_type = .Custom_Rule,
                    message = err_msg,
                })
                result.valid = false
                if schema.strict { return }
            }
        }
    }

    return result
}

// validate_type checks if a string value matches the expected type
validate_type :: proc(col_type: Column_Type, value: string) -> bool {
    switch col_type {
    case .String:
        return true

    case .Int:
        _, ok := strconv.parse_i64(value)
        return ok

    case .Float:
        _, ok := strconv.parse_f64(value)
        return ok

    case .Bool:
        lower := strings.to_lower(value, context.temp_allocator)
        return lower == "true" || lower == "false" ||
               lower == "yes" || lower == "no" ||
               lower == "1" || lower == "0" ||
               lower == "t" || lower == "f"

    case .Date:
        // Simple date validation (YYYY-MM-DD, YYYY/MM/DD, DD/MM/YYYY, MM/DD/YYYY)
        return len(value) >= 8 && len(value) <= 10

    case .Custom:
        return true // Custom validation handles this
    }

    return false
}

// convert_value converts a string to the specified type
convert_value :: proc(col_type: Column_Type, value: string) -> (result: Typed_Value, ok: bool) {
    if len(value) == 0 {
        return "", true // Empty string is valid for all types
    }

    switch col_type {
    case .String:
        return value, true

    case .Int:
        if int_val, parse_ok := strconv.parse_i64(value); parse_ok {
            return int_val, true
        }
        return i64(0), false

    case .Float:
        if float_val, parse_ok := strconv.parse_f64(value); parse_ok {
            return float_val, true
        }
        return f64(0), false

    case .Bool:
        lower := strings.to_lower(value, context.temp_allocator)
        if lower == "true" || lower == "yes" || lower == "1" || lower == "t" {
            return true, true
        }
        if lower == "false" || lower == "no" || lower == "0" || lower == "f" {
            return false, true
        }
        return false, false

    case .Date:
        // For now, return as string (proper date parsing would require more work)
        return value, true

    case .Custom:
        return value, true
    }

    return "", false
}

// validate_and_convert validates rows and converts them to typed values
validate_and_convert :: proc(schema: ^Schema, rows: [][]string) -> (typed_rows: []Typed_Row, result: Validation_Result) {
    result.errors = make([dynamic]Validation_Error)
    result.warnings = make([dynamic]Validation_Error)
    result.valid = true

    start_row := 0
    if schema.skip_header && len(rows) > 0 {
        start_row = 1
    }

    typed_rows = make([]Typed_Row, len(rows) - start_row)

    for row, i in rows[start_row:] {
        row_num := i + start_row + 1

        // Validate row
        row_result := validate_row(schema, row, row_num)
        result.rows_validated += 1

        if !row_result.valid {
            result.valid = false
            for err in row_result.errors {
                append(&result.errors, err)
            }
            if schema.strict {
                delete(row_result.errors)
                delete(row_result.warnings)
                return
            }
        }

        for warn in row_result.warnings {
            append(&result.warnings, warn)
        }

        delete(row_result.errors)
        delete(row_result.warnings)

        // Convert values
        typed_row := make([]Typed_Value, len(schema.columns))
        for col_schema, j in schema.columns {
            if j < len(row) {
                typed_val, conv_ok := convert_value(col_schema.col_type, row[j])
                if conv_ok {
                    typed_row[j] = typed_val
                } else {
                    typed_row[j] = row[j] // Keep as string if conversion fails
                }
            } else {
                typed_row[j] = "" // Missing column
            }
        }

        typed_rows[i] = typed_row
    }

    return typed_rows, result
}

// validation_result_destroy cleans up a validation result
// Set free_messages=true to free error message strings (default: false)
// Only set to true if you're sure all messages were allocated (not string literals)
validation_result_destroy :: proc(result: ^Validation_Result, free_messages: bool = true) {
    if free_messages {
        // Free error messages (but be careful with custom validator string literals!)
        for err in result.errors {
            // Only safe if message was allocated with fmt.aprintf or similar
            if len(err.message) > 0 {
                delete(err.message)
            }
        }
        for warn in result.warnings {
            if len(warn.message) > 0 {
                delete(warn.message)
            }
        }
    }
    delete(result.errors)
    delete(result.warnings)
}

// format_validation_error formats a validation error for display
format_validation_error :: proc(err: Validation_Error) -> string {
    return fmt.aprintf("Row %d, Column %d (%s): %s",
        err.row, err.column, err.column_name, err.message)
}
