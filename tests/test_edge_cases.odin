package tests

import "core:testing"
import "core:strings"
import cisv "../src"

// ============================================================================
// RFC 4180 Edge Cases Tests
// ============================================================================

// Test 1: Nested quotes (RFC 4180 requirement: "" = literal quote)
@(test)
test_nested_quotes :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := `"He said ""Hello"" to me"`
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, len(parser.all_rows[0]), 1)
    testing.expect_value(t, parser.all_rows[0][0], `He said "Hello" to me`)
}

// Test 2: Multiline field (quotes preserve newlines)
@(test)
test_multiline_field :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "\"Line 1\nLine 2\nLine 3\""
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, parser.all_rows[0][0], "Line 1\nLine 2\nLine 3")
}

// Test 3: Empty quoted fields
@(test)
test_empty_quoted_fields :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := `"",a,""`
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, len(parser.all_rows[0]), 3)
    testing.expect_value(t, parser.all_rows[0][0], "")
    testing.expect_value(t, parser.all_rows[0][1], "a")
    testing.expect_value(t, parser.all_rows[0][2], "")
}

// Test 4: Comment character inside quotes (should be literal)
@(test)
test_comment_in_quotes :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := `"# Not a comment",a`
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, parser.all_rows[0][0], "# Not a comment")
}

// Test 5: Delimiter inside quotes (should be literal)
@(test)
test_delimiter_in_quotes :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := `"a,b,c",d`
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, len(parser.all_rows[0]), 2)
    testing.expect_value(t, parser.all_rows[0][0], "a,b,c")
    testing.expect_value(t, parser.all_rows[0][1], "d")
}

// Test 6: Multiple consecutive delimiters (empty fields)
@(test)
test_empty_fields :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "a,,b,,,c"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 6)
    testing.expect_value(t, parser.all_rows[0][0], "a")
    testing.expect_value(t, parser.all_rows[0][1], "")
    testing.expect_value(t, parser.all_rows[0][2], "b")
    testing.expect_value(t, parser.all_rows[0][3], "")
    testing.expect_value(t, parser.all_rows[0][4], "")
    testing.expect_value(t, parser.all_rows[0][5], "c")
}

// Test 7: Trailing delimiter (creates empty field)
@(test)
test_trailing_delimiter :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "a,b,c,"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 4)
    testing.expect_value(t, parser.all_rows[0][3], "")
}

// Test 8: Leading delimiter (creates empty field)
@(test)
test_leading_delimiter :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := ",a,b,c"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 4)
    testing.expect_value(t, parser.all_rows[0][0], "")
}

// Test 9: CRLF line endings (Windows)
@(test)
test_crlf_line_endings :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "a,b,c\r\n1,2,3\r\n"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 2)
    testing.expect_value(t, parser.all_rows[0][0], "a")
    testing.expect_value(t, parser.all_rows[1][0], "1")
}

// Test 10: Mixed quotes in same field
@(test)
test_complex_quotes :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := `"He said ""Hi"" and ""Bye"""`
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, parser.all_rows[0][0], `He said "Hi" and "Bye"`)
}

// Test 11: Quoted field with newline and comma
@(test)
test_quoted_multiline_with_comma :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "\"Line 1,\nLine 2\",b"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, len(parser.all_rows[0]), 2)
    testing.expect_value(t, parser.all_rows[0][0], "Line 1,\nLine 2")
    testing.expect_value(t, parser.all_rows[0][1], "b")
}

// Test 12: Empty line in the middle
@(test)
test_empty_line_middle :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "a,b\n\nc,d"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    // Should have 3 rows: a,b | empty | c,d
    testing.expect_value(t, len(parser.all_rows), 3)
}

// Test 13: Only quotes
@(test)
test_only_quotes :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := `""""""`
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, parser.all_rows[0][0], `""`)
}

// Test 14: Newline at end of quoted field
@(test)
test_newline_in_quoted_field :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "\"a\n\",b"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, parser.all_rows[0][0], "a\n")
}

// Test 15: Comment line (should be skipped)
@(test)
test_comment_line :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "# Comment line\na,b,c"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, parser.all_rows[0][0], "a")
}

// Test 16: Comment character not at start of line (should be literal)
@(test)
test_comment_mid_line :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "a,#b,c"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, parser.all_rows[0][1], "#b")
}

// Test 17: Single quote in unquoted field
@(test)
test_quote_in_unquoted :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)
    parser.config.relaxed = true // Enable relaxed mode

    input := `a"b,c`
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, parser.all_rows[0][0], `a"b`)
}

// Test 18: Tab delimiter
@(test)
test_tab_delimiter :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)
    parser.config.delimiter = '\t'

    input := "a\tb\tc"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 3)
    testing.expect_value(t, parser.all_rows[0][1], "b")
}

// Test 19: Semicolon delimiter
@(test)
test_semicolon_delimiter :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)
    parser.config.delimiter = ';'

    input := "a;b;c"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 3)
}

// Test 20: Very long field (stress test)
@(test)
test_long_field :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    // Create a field with 10,000 characters
    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)

    for i in 0..<10000 {
        strings.write_byte(&builder, 'a')
    }
    long_field := strings.to_string(builder)

    input := strings.concatenate({long_field, ",b"})
    defer delete(input)

    ok := cisv.parse_csv(parser, input)
    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0][0]), 10000)
}

// Test 21: All empty fields
@(test)
test_all_empty :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := ",,,"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 4)
    for field in parser.all_rows[0] {
        testing.expect_value(t, field, "")
    }
}

// Test 22: Quote at end of unquoted field (relaxed mode)
@(test)
test_trailing_quote_relaxed :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)
    parser.config.relaxed = true

    input := `abc",def`
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
}

// Test 23: Unicode content
@(test)
test_unicode_content :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "日本語,中文,한국어"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows[0]), 3)
    testing.expect_value(t, parser.all_rows[0][0], "日本語")
}

// Test 24: Whitespace preservation
@(test)
test_whitespace_preservation :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := " a , b , c "
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, parser.all_rows[0][0], " a ")
    testing.expect_value(t, parser.all_rows[0][1], " b ")
}

// Test 25: Multiple rows with varying field counts
@(test)
test_jagged_rows :: proc(t: ^testing.T) {
    parser := cisv.parser_create()
    defer cisv.parser_destroy(parser)

    input := "a,b,c\nd,e\nf,g,h,i"
    ok := cisv.parse_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 3)
    testing.expect_value(t, len(parser.all_rows[0]), 3)
    testing.expect_value(t, len(parser.all_rows[1]), 2)
    testing.expect_value(t, len(parser.all_rows[2]), 4)
}
