package tests

import "core:testing"
import "core:fmt"
import "core:math/rand"
import "core:strings"
import ocsv "../src"

// ============================================================================
// Property-Based Testing (Fuzzing)
// ============================================================================

// Generate random CSV data for testing
Random_CSV_Generator :: struct {
    seed: u64,
    counter: u64,
    max_rows: int,
    max_cols: int,
    max_field_len: int,
}

generator_create :: proc(seed: u64) -> Random_CSV_Generator {
    gen: Random_CSV_Generator
    gen.seed = seed
    gen.counter = 0
    gen.max_rows = 100
    gen.max_cols = 20
    gen.max_field_len = 100
    return gen
}

// Simple LCG random number generator
next_random :: proc(gen: ^Random_CSV_Generator, max: i32) -> i32 {
    gen.counter += 1
    value := (gen.seed * gen.counter) % u64(max)
    return i32(value)
}

generate_random_field :: proc(gen: ^Random_CSV_Generator) -> string {
    // Randomly decide field type
    field_type := next_random(gen, 5)

    builder: strings.Builder
    strings.builder_init(&builder)

    switch field_type {
    case 0: // Simple alphanumeric
        len := next_random(gen, i32(gen.max_field_len)) + 1
        for i in 0..<len {
            ch := byte(next_random(gen, 26) + 'a')
            strings.write_byte(&builder, ch)
        }

    case 1: // Numbers
        num := next_random(gen, 10000)
        strings.write_string(&builder, fmt.tprintf("%d", num))

    case 2: // Empty field
        // Leave empty

    case 3: // Field with spaces
        len := next_random(gen, i32(gen.max_field_len)) + 1
        for i in 0..<len {
            if next_random(gen, 3) == 0 {
                strings.write_byte(&builder, ' ')
            } else {
                ch := byte(next_random(gen, 26) + 'a')
                strings.write_byte(&builder, ch)
            }
        }

    case 4: // Quoted field (requires quotes)
        strings.write_byte(&builder, '"')
        len := next_random(gen, i32(gen.max_field_len)) + 1
        for i in 0..<len {
            // Sometimes add comma or newline (forces quotes)
            if next_random(gen, 10) == 0 {
                strings.write_byte(&builder, ',')
            } else if next_random(gen, 20) == 0 {
                strings.write_byte(&builder, '\n')
            } else if next_random(gen, 20) == 0 {
                // Nested quote
                strings.write_string(&builder, "\"\"")
            } else {
                ch := byte(next_random(gen, 26) + 'a')
                strings.write_byte(&builder, ch)
            }
        }
        strings.write_byte(&builder, '"')
    }

    return strings.to_string(builder)
}

generate_random_csv :: proc(gen: ^Random_CSV_Generator) -> string {
    num_rows := next_random(gen, i32(gen.max_rows)) + 1
    num_cols := next_random(gen, i32(gen.max_cols)) + 1

    builder: strings.Builder
    strings.builder_init(&builder)

    for row in 0..<num_rows {
        for col in 0..<num_cols {
            field := generate_random_field(gen)
            strings.write_string(&builder, field)
            delete(field)

            if col < num_cols - 1 {
                strings.write_byte(&builder, ',')
            }
        }
        strings.write_byte(&builder, '\n')
    }

    return strings.to_string(builder)
}

// Property 1: Parse result should never crash
@(test)
test_fuzz_no_crash :: proc(t: ^testing.T) {
    gen := generator_create(12345)

    for i in 0..<100 {
        csv_data := generate_random_csv(&gen)
        defer delete(csv_data)

        parser := ocsv.parser_create()
        defer ocsv.parser_destroy(parser)

        // Should not crash, regardless of result
        _ = ocsv.parse_csv(parser, csv_data)
    }

    testing.expect(t, true, "Fuzzing completed without crashes")
}

// Property 2: If parse succeeds, row count should be positive
@(test)
test_fuzz_valid_row_count :: proc(t: ^testing.T) {
    gen := generator_create(54321)

    for i in 0..<50 {
        csv_data := generate_random_csv(&gen)
        defer delete(csv_data)

        parser := ocsv.parser_create()
        defer ocsv.parser_destroy(parser)

        ok := ocsv.parse_csv(parser, csv_data)
        if ok {
            testing.expect(t, len(parser.all_rows) > 0, "Successful parse should have rows")
        }
    }
}

// Property 3: Parsing same data twice should give same result
@(test)
test_fuzz_deterministic :: proc(t: ^testing.T) {
    gen := generator_create(99999)

    for i in 0..<20 {
        csv_data := generate_random_csv(&gen)
        defer delete(csv_data)

        parser1 := ocsv.parser_create()
        defer ocsv.parser_destroy(parser1)

        parser2 := ocsv.parser_create()
        defer ocsv.parser_destroy(parser2)

        ok1 := ocsv.parse_csv(parser1, csv_data)
        ok2 := ocsv.parse_csv(parser2, csv_data)

        testing.expect_value(t, ok1, ok2)
        if ok1 && ok2 {
            testing.expect_value(t, len(parser1.all_rows), len(parser2.all_rows))
        }
    }
}

// Property 4: Empty input should parse without error
@(test)
test_fuzz_empty_variations :: proc(t: ^testing.T) {
    test_cases := []string{
        "",
        "\n",
        "\n\n",
        "   ",
        "\r\n",
        "\r\n\r\n",
    }

    for test_case in test_cases {
        parser := ocsv.parser_create()
        defer ocsv.parser_destroy(parser)

        ok := ocsv.parse_csv(parser, test_case)
        testing.expect(t, ok, fmt.tprintf("Empty variation should parse: %q", test_case))
    }
}

// Property 5: Malicious input should not crash
@(test)
test_fuzz_malicious_input :: proc(t: ^testing.T) {
    // Create malicious test cases
    null_bytes: [4]byte = {0, 0, 0, 0}
    null_string := transmute(string)null_bytes[:]

    quotes_str := strings.repeat("\"", 1000)
    defer delete(quotes_str)

    delimiters_str := strings.repeat(",", 1000)
    defer delete(delimiters_str)

    newlines_str := strings.repeat("\n", 1000)
    defer delete(newlines_str)

    // Build unterminated quote string
    unterminated_builder: strings.Builder
    strings.builder_init(&unterminated_builder)
    strings.write_byte(&unterminated_builder, '"')
    repeated_a := strings.repeat("a", 10000)
    strings.write_string(&unterminated_builder, repeated_a)
    delete(repeated_a)  // Free the repeated string
    unterminated_str := strings.to_string(unterminated_builder)
    defer {
        strings.builder_destroy(&unterminated_builder)
    }

    wide_row_str := strings.repeat("a,", 5000)
    defer delete(wide_row_str)

    malicious_cases := []string{
        null_string,
        quotes_str,
        delimiters_str,
        newlines_str,
        unterminated_str,
        wide_row_str,
    }

    for malicious_case, idx in malicious_cases {
        parser := ocsv.parser_create()
        defer ocsv.parser_destroy(parser)

        // Should not crash (may or may not parse successfully)
        _ = ocsv.parse_csv(parser, malicious_case)

        testing.expect(t, true, fmt.tprintf("Malicious case %d completed", idx))
    }
}
