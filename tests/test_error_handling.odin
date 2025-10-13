package tests

import "core:testing"
import "core:fmt"
import ocsv "../src"

// Test basic error detection
@(test)
test_error_unterminated_quote :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.config.relaxed = false

    csv_data := `"unterminated quote`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, !result.success, "Parse should fail")
    testing.expect_value(t, result.error.code, ocsv.Parse_Error.Unterminated_Quote)
    testing.expect(t, result.error.line > 0, "Error should have line number")

    err_msg := ocsv.format_error(result.error)
    defer delete(err_msg)
    fmt.printfln("Error: %s", err_msg)
}

@(test)
test_error_unterminated_quote_relaxed :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.config.relaxed = true

    csv_data := `"unterminated quote`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, result.success, "Parse should succeed in relaxed mode")
    testing.expect(t, len(result.warnings) > 0, "Should have warning")
    testing.expect_value(t, result.warnings[0].code, ocsv.Parse_Error.Unterminated_Quote)
}

@(test)
test_error_invalid_character_after_quote :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.config.relaxed = false

    csv_data := `"quoted"x,field2`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, !result.success, "Parse should fail")
    testing.expect_value(t, result.error.code, ocsv.Parse_Error.Invalid_Character_After_Quote)

    err_msg := ocsv.format_error(result.error)
    defer delete(err_msg)
    fmt.printfln("Error: %s", err_msg)
}

@(test)
test_error_invalid_character_after_quote_relaxed :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.config.relaxed = true

    csv_data := `"quoted"x,field2`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, result.success, "Parse should succeed in relaxed mode")
    testing.expect(t, len(result.warnings) > 0, "Should have warning")
}

@(test)
test_error_empty_input :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    result := ocsv.parse_csv_with_errors(parser, "")
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, !result.success, "Parse should fail on empty input")
    testing.expect_value(t, result.error.code, ocsv.Parse_Error.Empty_Input)
}

@(test)
test_error_column_consistency :: proc(t: ^testing.T) {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    csv_data := "a,b,c\n1,2,3\n4,5\n6,7,8"

    ok := ocsv.parse_csv(parser, csv_data)
    testing.expect(t, ok, "Parse should succeed")

    consistent, err := ocsv.validate_column_consistency(parser, true)

    testing.expect(t, !consistent, "Should detect inconsistent columns")
    testing.expect_value(t, err.code, ocsv.Parse_Error.Inconsistent_Column_Count)

    err_msg := ocsv.format_error(err)
    defer delete(err_msg)
    fmt.printfln("Validation error: %s", err_msg)
}

// Test recovery strategies
@(test)
test_recovery_fail_fast :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.recovery_strategy = .Fail_Fast
    parser.config.relaxed = false

    csv_data := `"ok","good"
"bad,broken`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, !result.success, "Should fail fast")
    testing.expect_value(t, result.rows_parsed, 1) // Only first row parsed
}

@(test)
test_recovery_skip_row :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.recovery_strategy = .Skip_Row
    parser.config.relaxed = false

    csv_data := `good1,good2
"broken
good3,good4`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, result.success || len(result.warnings) > 0, "Should skip bad rows")
    // Should have parsed some rows despite errors
}

@(test)
test_recovery_best_effort :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.recovery_strategy = .Best_Effort
    parser.config.relaxed = true

    csv_data := `good1,good2
"partially broken,
good3,good4`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, result.success, "Best effort should succeed")
    testing.expect(t, len(parser.all_rows) > 0, "Should have parsed some data")
}

// Test parse_csv_safe convenience function
@(test)
test_parse_csv_safe :: proc(t: ^testing.T) {
    csv_data := `name,age,city
Alice,30,NYC
Bob,25,SF`

    config := ocsv.default_config()
    rows, result := ocsv.parse_csv_safe(csv_data, config)
    defer {
        for row in rows {
            for field in row {
                delete(field)
            }
            delete(row)
        }
        delete(rows)
        ocsv.parse_result_destroy(&result)
    }

    testing.expect(t, result.success, "Parse should succeed")
    testing.expect_value(t, len(rows), 3)
    testing.expect_value(t, rows[0][0], "name")
    testing.expect_value(t, rows[1][0], "Alice")
}

@(test)
test_parse_csv_safe_with_error :: proc(t: ^testing.T) {
    csv_data := `"unterminated`

    config := ocsv.default_config()
    rows, result := ocsv.parse_csv_safe(csv_data, config, .Fail_Fast)
    defer {
        for row in rows {
            for field in row {
                delete(field)
            }
            delete(row)
        }
        delete(rows)
        ocsv.parse_result_destroy(&result)
    }

    testing.expect(t, !result.success, "Parse should fail")
    testing.expect(t, ocsv.is_error(result.error), "Should have error")

    err_msg := ocsv.format_error(result.error)
    defer delete(err_msg)
    fmt.printfln("Error message: %s", err_msg)
}

@(test)
test_parse_csv_safe_relaxed :: proc(t: ^testing.T) {
    csv_data := `"unterminated`

    config := ocsv.default_config()
    config.relaxed = true

    rows, result := ocsv.parse_csv_safe(csv_data, config, .Best_Effort)
    defer {
        for row in rows {
            for field in row {
                delete(field)
            }
            delete(row)
        }
        delete(rows)
        ocsv.parse_result_destroy(&result)
    }

    testing.expect(t, result.success, "Parse should succeed in relaxed mode")
    testing.expect(t, len(result.warnings) > 0, "Should have warnings")
}

// Test error formatting
@(test)
test_error_formatting :: proc(t: ^testing.T) {
    err := ocsv.make_error(
        ocsv.Parse_Error.Invalid_UTF8,
        10,
        25,
        "Invalid UTF-8 sequence at position 25",
        "...some context...",
    )

    formatted := ocsv.format_error(err)
    defer delete(formatted)

    testing.expect(t, len(formatted) > 0, "Formatted error should not be empty")

    fmt.printfln("Formatted error:\n%s", formatted)

    // Check that error contains key information
    testing.expect(t, contains_substring(formatted, "line 10"), "Should include line number")
    testing.expect(t, contains_substring(formatted, "column 25"), "Should include column number")
    testing.expect(t, contains_substring(formatted, "context"), "Should include context")
}

@(test)
test_error_to_string :: proc(t: ^testing.T) {
    test_cases := []ocsv.Parse_Error{
        .None,
        .File_Not_Found,
        .Invalid_UTF8,
        .Unterminated_Quote,
        .Max_Row_Size_Exceeded,
    }

    for code in test_cases {
        str := ocsv.error_to_string(code)
        testing.expect(t, len(str) > 0, "Error string should not be empty")
        fmt.printfln("%v -> %s", code, str)
    }
}

@(test)
test_error_context_extraction :: proc(t: ^testing.T) {
    data := "This is a test string with an error in the middle of it"
    error_pos := 25 // Position of "error"

    ctx_str := ocsv.get_context_around_position(data, error_pos, 10)

    testing.expect(t, len(ctx_str) > 0, "Context should not be empty")

    fmt.printfln("Context: %s", ctx_str)
}

// Helper function
contains_substring :: proc(haystack: string, needle: string) -> bool {
    for i := 0; i <= len(haystack) - len(needle); i += 1 {
        if haystack[i:i+len(needle)] == needle {
            return true
        }
    }
    return false
}

// Test multiple errors collection
@(test)
test_collect_all_errors :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.recovery_strategy = .Collect_All_Errors
    parser.config.relaxed = false
    parser.max_errors = 10

    // CSV with multiple errors
    csv_data := `"ok1","ok2"
"bad1
"ok3","ok4"
"bad2
"ok5","ok6"`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, len(result.warnings) > 0, "Should have collected errors")

    fmt.printfln("Collected %d errors:", len(result.warnings))
    for warning, i in result.warnings {
        err_msg := ocsv.format_error(warning)
        defer delete(err_msg)
        fmt.printfln("  %d: %s", i+1, err_msg)
    }
}

@(test)
test_max_errors_limit :: proc(t: ^testing.T) {
    parser := ocsv.parser_extended_create()
    defer ocsv.parser_extended_destroy(parser)

    parser.recovery_strategy = .Collect_All_Errors
    parser.config.relaxed = false
    parser.max_errors = 2

    // CSV with many errors
    csv_data := `"bad1
"bad2
"bad3
"bad4
"bad5"`

    result := ocsv.parse_csv_with_errors(parser, csv_data)
    defer ocsv.parse_result_destroy(&result)

    testing.expect(t, parser.error_count <= parser.max_errors, "Should stop at max errors")
}
