package tests

import "core:testing"
import "core:fmt"
import "core:strings"
import "core:os"
import cisv "../src"

// ============================================================================
// Integration Tests
// ============================================================================
// These tests validate end-to-end workflows and common usage patterns

// Test: Complete workflow from parse to data access
@(test)
test_integration_basic_workflow :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Basic Workflow ===\n")

    // Step 1: Create parser
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    // Step 2: Parse CSV data
    csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\n"
    ok := cisv.parse_csv(parser, csv_data)
    testing.expect(t, ok, "Parse should succeed")

    // Step 3: Access results
    testing.expect_value(t, len(parser.all_rows), 3)

    // Header row
    testing.expect_value(t, parser.all_rows[0][0], "name")
    testing.expect_value(t, parser.all_rows[0][1], "age")
    testing.expect_value(t, parser.all_rows[0][2], "city")

    // Data rows
    testing.expect_value(t, parser.all_rows[1][0], "Alice")
    testing.expect_value(t, parser.all_rows[1][1], "30")
    testing.expect_value(t, parser.all_rows[1][2], "NYC")

    testing.expect_value(t, parser.all_rows[2][0], "Bob")
    testing.expect_value(t, parser.all_rows[2][1], "25")
    testing.expect_value(t, parser.all_rows[2][2], "SF")

    fmt.printf("✅ Successfully parsed and accessed all data\n")
}

// Test: Multiple parse operations with same parser (reuse)
@(test)
test_integration_parser_reuse :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Parser Reuse ===\n")

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    // First parse
    csv1 := "a,b\n1,2\n"
    ok1 := cisv.parse_csv(parser, csv1)
    testing.expect(t, ok1)
    row_count_1 := len(parser.all_rows)

    // Second parse (should clear previous results)
    csv2 := "x,y,z\n10,20,30\n"
    ok2 := cisv.parse_csv(parser, csv2)
    testing.expect(t, ok2)
    row_count_2 := len(parser.all_rows)

    testing.expect_value(t, row_count_1, 2)
    testing.expect_value(t, row_count_2, 2)

    // Verify second parse results
    testing.expect_value(t, parser.all_rows[0][0], "x")
    testing.expect_value(t, len(parser.all_rows[0]), 3)

    fmt.printf("✅ Parser successfully reused for multiple parses\n")
}

// Test: Custom configuration (delimiter + quote)
@(test)
test_integration_custom_config :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Custom Configuration ===\n")

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    // Configure for TSV with single quotes
    parser.config.delimiter = '\t'
    parser.config.quote = '\''

    csv_data := "name\tvalue\n'quoted\ttab'\t100\n"
    ok := cisv.parse_csv(parser, csv_data)
    testing.expect(t, ok)

    testing.expect_value(t, len(parser.all_rows), 2)
    testing.expect_value(t, parser.all_rows[1][0], "quoted\ttab")
    testing.expect_value(t, parser.all_rows[1][1], "100")

    fmt.printf("✅ Custom configuration works correctly\n")
}

// Test: Comment filtering
@(test)
test_integration_comments :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Comment Filtering ===\n")

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    parser.config.comment = '#'

    csv_data := `# This is a comment
name,value
# Another comment
data1,100
data2,200
# Final comment`

    ok := cisv.parse_csv(parser, csv_data)
    testing.expect(t, ok)

    // Should only have header + 2 data rows (3 comment lines filtered)
    testing.expect_value(t, len(parser.all_rows), 3)
    testing.expect_value(t, parser.all_rows[0][0], "name")
    testing.expect_value(t, parser.all_rows[1][0], "data1")
    testing.expect_value(t, parser.all_rows[2][0], "data2")

    fmt.printf("✅ Comments successfully filtered\n")
}

// Test: Relaxed mode vs strict mode
@(test)
test_integration_strict_vs_relaxed :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Strict vs Relaxed Mode ===\n")

    // Malformed CSV: quote followed by non-delimiter
    malformed := `"quoted"extra,value`

    // Strict mode should fail
    {
        parser := cisv.parser_create()
        defer cisv.parser_destroy(parser)

        parser.config.relaxed = false
        ok := cisv.parse_csv(parser, malformed)
        testing.expect(t, !ok, "Strict mode should reject malformed CSV")
        fmt.printf("✅ Strict mode correctly rejected malformed CSV\n")
    }

    // Relaxed mode should succeed
    {
        parser := cisv.parser_create()
        defer cisv.parser_destroy(parser)

        parser.config.relaxed = true
        ok := cisv.parse_csv(parser, malformed)
        testing.expect(t, ok, "Relaxed mode should accept malformed CSV")
        fmt.printf("✅ Relaxed mode accepted malformed CSV\n")
    }
}

// Test: Empty and whitespace handling
@(test)
test_integration_empty_whitespace :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Empty and Whitespace ===\n")

    test_cases := []struct{
        input: string,
        expected_rows: int,
        description: string,
    }{
        {"", 0, "empty string"},
        {"\n", 0, "single newline"},
        {"\n\n", 1, "multiple newlines"},
        {"   ", 1, "spaces only"},
        {"a,b\n", 1, "single row with newline"},
        {"a,b", 1, "single row without newline"},
        {"a,b\n\n", 2, "row followed by empty line"},
    }

    for test_case in test_cases {
        parser := cisv.parser_create()

        ok := cisv.parse_csv(parser, test_case.input)
        testing.expect(t, ok, fmt.tprintf("Parse should succeed for: %s", test_case.description))

        row_count := len(parser.all_rows)
        testing.expect_value(t, row_count, test_case.expected_rows)

        cisv.parser_destroy(parser)
    }

    fmt.printf("✅ Empty and whitespace cases handled correctly\n")
}

// Test: Large dataset workflow
@(test)
test_integration_large_dataset :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Large Dataset Workflow ===\n")

    // Generate CSV with many rows
    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)

    num_rows := 10000
    for i in 0..<num_rows {
        strings.write_string(&builder, fmt.tprintf("row%d,value%d,data%d\n", i, i*10, i*100))
    }

    csv_data := strings.to_string(builder)

    // Parse
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, csv_data)
    testing.expect(t, ok, "Large dataset should parse")
    testing.expect_value(t, len(parser.all_rows), num_rows)

    // Verify first and last rows
    testing.expect_value(t, parser.all_rows[0][0], "row0")
    testing.expect_value(t, parser.all_rows[num_rows-1][0], fmt.tprintf("row%d", num_rows-1))

    fmt.printf("✅ Large dataset (%d rows) parsed successfully\n", num_rows)
}

// Test: Jagged CSV (rows with different column counts)
@(test)
test_integration_jagged_csv :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Jagged CSV ===\n")

    csv_data := `a,b,c
1,2
x,y,z,extra
single`

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, csv_data)
    testing.expect(t, ok)

    testing.expect_value(t, len(parser.all_rows), 4)
    testing.expect_value(t, len(parser.all_rows[0]), 3) // 3 cols
    testing.expect_value(t, len(parser.all_rows[1]), 2) // 2 cols
    testing.expect_value(t, len(parser.all_rows[2]), 4) // 4 cols
    testing.expect_value(t, len(parser.all_rows[3]), 1) // 1 col

    fmt.printf("✅ Jagged CSV handled correctly\n")
}

// Test: Real-world-like CSV with all features
@(test)
test_integration_realistic_csv :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Realistic CSV ===\n")

    // Realistic CSV with headers, quotes, commas in quotes, etc.
    csv_data := `# Sales data for Q1 2024
product,price,description,quantity
"Widget A",19.99,"A great widget, now with more features!",100
"Gadget B",29.99,"Essential gadget
Multi-line description",50
"Item C",9.99,"Simple item",200
# End of data`

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)
    parser.config.comment = '#'

    ok := cisv.parse_csv(parser, csv_data)
    testing.expect(t, ok)

    // Should have header + 3 data rows (2 comment lines filtered)
    testing.expect_value(t, len(parser.all_rows), 4)

    // Verify header
    testing.expect_value(t, parser.all_rows[0][0], "product")
    testing.expect_value(t, parser.all_rows[0][1], "price")
    testing.expect_value(t, parser.all_rows[0][2], "description")
    testing.expect_value(t, parser.all_rows[0][3], "quantity")

    // Verify data with complex fields
    testing.expect_value(t, parser.all_rows[1][0], "Widget A")
    testing.expect_value(t, parser.all_rows[1][2], "A great widget, now with more features!")

    // Verify multiline field
    testing.expect_value(t, parser.all_rows[2][0], "Gadget B")
    testing.expect_value(t, parser.all_rows[2][2], "Essential gadget\nMulti-line description")

    fmt.printf("✅ Realistic CSV parsed correctly\n")
}

// Test: Error recovery - parsing after error
@(test)
test_integration_error_recovery :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Error Recovery ===\n")

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)
    parser.config.relaxed = false // Strict mode

    // First parse: malformed (should fail)
    malformed := `"unterminated quote,value`
    ok1 := cisv.parse_csv(parser, malformed)
    testing.expect(t, !ok1, "Malformed CSV should fail in strict mode")

    // Second parse: valid (should succeed)
    valid := `a,b,c
1,2,3`
    ok2 := cisv.parse_csv(parser, valid)
    testing.expect(t, ok2, "Valid CSV should parse after error")
    testing.expect_value(t, len(parser.all_rows), 2)

    fmt.printf("✅ Parser recovered correctly after error\n")
}

// Test: International characters and Unicode
@(test)
test_integration_international :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: International Characters ===\n")

    csv_data := `language,greeting,country
English,Hello,USA
日本語,こんにちは,日本
中文,你好,中国
Español,Hola,España
Français,Bonjour,France
한국어,안녕하세요,한국`

    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    ok := cisv.parse_csv(parser, csv_data)
    testing.expect(t, ok)

    testing.expect_value(t, len(parser.all_rows), 7) // header + 6 languages

    // Verify Unicode content (row 0 is header, data starts at row 1)
    testing.expect_value(t, parser.all_rows[2][0], "日本語")
    testing.expect_value(t, parser.all_rows[2][1], "こんにちは")
    testing.expect_value(t, parser.all_rows[3][0], "中文")
    testing.expect_value(t, parser.all_rows[4][0], "Español")

    fmt.printf("✅ International characters handled correctly\n")
}

// Test: Common delimiters (CSV, TSV, PSV)
@(test)
test_integration_common_formats :: proc(t: ^testing.T) {
    fmt.printf("\n=== Integration: Common Formats ===\n")

    formats := []struct{
        name: string,
        delimiter: byte,
        data: string,
    }{
        {"CSV (comma)", ',', "a,b,c\n1,2,3\n"},
        {"TSV (tab)", '\t', "a\tb\tc\n1\t2\t3\n"},
        {"PSV (pipe)", '|', "a|b|c\n1|2|3\n"},
        {"SSV (semicolon)", ';', "a;b;c\n1;2;3\n"},
    }

    for format in formats {
        parser := cisv.parser_create()
        parser.config.delimiter = format.delimiter

        ok := cisv.parse_csv(parser, format.data)
        testing.expect(t, ok, fmt.tprintf("%s should parse", format.name))
        testing.expect_value(t, len(parser.all_rows), 2)
        testing.expect_value(t, len(parser.all_rows[0]), 3)

        cisv.parser_destroy(parser)
    }

    fmt.printf("✅ All common formats supported\n")
}
