package tests

import "core:testing"
import "core:fmt"
import ocsv "../src"

@(test)
test_parser_create_destroy :: proc(t: ^testing.T) {
    parser := ocsv.parser_create()
    testing.expect(t, parser != nil, "Parser should be created")
    ocsv.parser_destroy(parser)
}

@(test)
test_default_config :: proc(t: ^testing.T) {
    config := ocsv.default_config()
    testing.expect_value(t, config.delimiter, byte(','))
    testing.expect_value(t, config.quote, byte('"'))
    testing.expect_value(t, config.escape, byte('"'))
}

@(test)
test_parse_empty_string :: proc(t: ^testing.T) {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    ok := ocsv.parse_simple_csv(parser, "")
    testing.expect(t, ok, "Parsing empty string should succeed")
    testing.expect_value(t, len(parser.all_rows), 0)
}

@(test)
test_parse_single_field :: proc(t: ^testing.T) {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    ok := ocsv.parse_simple_csv(parser, "hello")
    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, len(parser.all_rows[0]), 1)
    testing.expect_value(t, parser.all_rows[0][0], "hello")
}

@(test)
test_parse_simple_csv :: proc(t: ^testing.T) {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    input := "a,b,c\n1,2,3\n"
    ok := ocsv.parse_simple_csv(parser, input)

    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 2)
    testing.expect_value(t, len(parser.all_rows[0]), 3)
    testing.expect_value(t, parser.all_rows[0][0], "a")
    testing.expect_value(t, parser.all_rows[0][1], "b")
    testing.expect_value(t, parser.all_rows[0][2], "c")
}

@(test)
test_parse_multiple_rows :: proc(t: ^testing.T) {
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    input := "name,age,city\nAlice,30,NYC\nBob,25,LA\n"
    ok := ocsv.parse_simple_csv(parser, input)

    testing.expect(t, ok)
    testing.expect_value(t, len(parser.all_rows), 3)

    // Check header
    testing.expect_value(t, parser.all_rows[0][0], "name")
    testing.expect_value(t, parser.all_rows[0][1], "age")
    testing.expect_value(t, parser.all_rows[0][2], "city")

    // Check first data row
    testing.expect_value(t, parser.all_rows[1][0], "Alice")
    testing.expect_value(t, parser.all_rows[1][1], "30")
    testing.expect_value(t, parser.all_rows[1][2], "NYC")
}
