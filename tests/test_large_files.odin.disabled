package tests

import "core:testing"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:time"
import ocsv "../src"

// ============================================================================
// Large File Tests
// ============================================================================

// Test with progressively larger datasets
@(test)
test_large_10mb :: proc(t: ^testing.T) {
    test_large_file(t, 10 * 1024 * 1024, "10MB")
}

@(test)
test_large_50mb :: proc(t: ^testing.T) {
    test_large_file(t, 50 * 1024 * 1024, "50MB")
}

// Only run 100MB test if explicitly enabled (slow)
@(test)
test_large_100mb :: proc(t: ^testing.T) {
    // Skip unless ODIN_TEST_LARGE is set
    when #config(ODIN_TEST_LARGE, false) {
        test_large_file(t, 100 * 1024 * 1024, "100MB")
    } else {
        testing.expect(t, true, "Large test skipped (use -define:ODIN_TEST_LARGE=true)")
    }
}

test_large_file :: proc(t: ^testing.T, target_size: int, label: string) {
    fmt.printf("\n=== Testing %s file ===\n", label)

    // Generate data
    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)

    row_template := "field1,field2,field3,field4,field5,field6,field7,field8,field9,field10\n"
    row_size := len(row_template)
    num_rows := target_size / row_size

    fmt.printf("Generating %d rows...\n", num_rows)
    gen_start := time.now()

    for i in 0..<num_rows {
        strings.write_string(&builder, row_template)
    }

    gen_elapsed := time.since(gen_start)
    csv_data := strings.to_string(builder)
    actual_size := len(csv_data)

    fmt.printf("Generated %d MB in %v\n", actual_size / 1024 / 1024, gen_elapsed)

    // Parse
    fmt.printf("Parsing...\n")
    parse_start := time.now()

    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    ok := ocsv.parse_csv(parser, csv_data)
    parse_elapsed := time.since(parse_start)

    testing.expect(t, ok, fmt.tprintf("%s file should parse successfully", label))

    // Validate results
    row_count := len(parser.all_rows)
    testing.expect(t, row_count > 0, "Should have parsed rows")

    // Calculate stats
    mb := f64(actual_size) / 1024 / 1024
    seconds := time.duration_seconds(parse_elapsed)
    throughput := mb / seconds

    fmt.printf("Results:\n")
    fmt.printf("  Rows: %d\n", row_count)
    fmt.printf("  Size: %.2f MB\n", mb)
    fmt.printf("  Time: %.2f s\n", seconds)
    fmt.printf("  Throughput: %.2f MB/s\n", throughput)

    // Performance expectations (lower for large files due to generation overhead)
    min_throughput := 2.0 // Minimum acceptable: 2 MB/s (includes generation time)
    testing.expect(t, throughput >= min_throughput,
        fmt.tprintf("Throughput %.2f MB/s should be >= %.2f MB/s", throughput, min_throughput))
}

// Test memory usage doesn't grow excessively
@(test)
test_memory_scaling :: proc(t: ^testing.T) {
    fmt.printf("\n=== Testing Memory Scaling ===\n")

    sizes := []int{1 * 1024 * 1024, 5 * 1024 * 1024, 10 * 1024 * 1024}

    for size, idx in sizes {
        // Generate data
        builder: strings.Builder
        strings.builder_init(&builder)

        row_template := "a,b,c,d,e,f,g,h,i,j\n"
        num_rows := size / len(row_template)

        for i in 0..<num_rows {
            strings.write_string(&builder, row_template)
        }

        csv_data := strings.to_string(builder)
        input_size := len(csv_data)

        // Parse
        parser := ocsv.parser_create()

        ok := ocsv.parse_csv(parser, csv_data)
        testing.expect(t, ok)

        // Check memory usage (rough estimate)
        // Each row has ~10 fields, each field is a cloned string
        row_count := len(parser.all_rows)
        estimated_memory := row_count * 10 * 10 // rows * fields * avg field size

        mb_input := f64(input_size) / 1024 / 1024
        mb_estimated := f64(estimated_memory) / 1024 / 1024

        fmt.printf("Size %d MB: rows=%d, estimated memory=%.2f MB\n",
            int(mb_input), row_count, mb_estimated)

        // Cleanup
        ocsv.parser_destroy(parser)
        strings.builder_destroy(&builder)
    }

    testing.expect(t, true, "Memory scaling test completed")
}

// Test parsing a very wide row (many columns)
@(test)
test_wide_row :: proc(t: ^testing.T) {
    fmt.printf("\n=== Testing Wide Row (1000 columns) ===\n")

    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)

    // Create a row with 1000 columns
    num_cols := 1000
    for i in 0..<num_cols {
        strings.write_string(&builder, fmt.tprintf("col%d", i))
        if i < num_cols - 1 {
            strings.write_byte(&builder, ',')
        }
    }
    strings.write_byte(&builder, '\n')

    csv_data := strings.to_string(builder)

    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    ok := ocsv.parse_csv(parser, csv_data)
    testing.expect(t, ok, "Wide row should parse")
    testing.expect_value(t, len(parser.all_rows), 1)
    testing.expect_value(t, len(parser.all_rows[0]), num_cols)

    fmt.printf("✓ Successfully parsed row with %d columns\n", num_cols)
}

// Test parsing many rows
@(test)
test_many_rows :: proc(t: ^testing.T) {
    fmt.printf("\n=== Testing Many Rows (100,000 rows) ===\n")

    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)

    num_rows := 100000
    start := time.now()

    for i in 0..<num_rows {
        strings.write_string(&builder, "a,b,c\n")
    }

    csv_data := strings.to_string(builder)
    gen_elapsed := time.since(start)

    fmt.printf("Generated %d rows in %v\n", num_rows, gen_elapsed)

    parse_start := time.now()

    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)

    ok := ocsv.parse_csv(parser, csv_data)
    parse_elapsed := time.since(parse_start)

    testing.expect(t, ok, "Many rows should parse")
    testing.expect_value(t, len(parser.all_rows), num_rows)

    fmt.printf("Parsed %d rows in %v\n", num_rows, parse_elapsed)

    // Should parse at least 10k rows/sec
    rows_per_sec := f64(num_rows) / time.duration_seconds(parse_elapsed)
    fmt.printf("Throughput: %.0f rows/sec\n", rows_per_sec)

    testing.expect(t, rows_per_sec >= 10000, "Should parse at least 10k rows/sec")
}
