package tests

import "core:testing"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:time"
import ocsv "../src"

//
// Basic Parallel Tests
//

@(test)
test_parallel_small_file_fallback :: proc(t: ^testing.T) {
    // Small file should fall back to sequential parsing
    csv_data := "name,age\nAlice,30\nBob,25\n"

    config := ocsv.Parallel_Config{
        num_threads = 4,
    }

    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)

    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 3)  // Header + 2 data rows
    testing.expect_value(t, parser.all_rows[0][0], "name")
    testing.expect_value(t, parser.all_rows[1][0], "Alice")
}

@(test)
test_parallel_large_file :: proc(t: ^testing.T) {
    // Generate CSV with 1000 rows (should trigger parallel parsing)
    builder := strings.builder_make(0, 50 * 1000)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "id,name,value\n")
    for i in 0..<1000 {
        strings.write_string(&builder, fmt.tprintf("%d,Name%d,%d\n", i, i, i * 10))
    }

    csv_data := strings.to_string(builder)

    config := ocsv.Parallel_Config{
        num_threads = 4,
    }

    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)

    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 1001)  // Header + 1000 data rows

    // Verify first row
    testing.expect_value(t, parser.all_rows[0][0], "id")
    testing.expect_value(t, parser.all_rows[1][0], "0")

    // Verify last row
    testing.expect_value(t, parser.all_rows[1000][0], "999")
}

@(test)
test_parallel_auto_thread_count :: proc(t: ^testing.T) {
    // Generate large enough CSV for parallel processing
    builder := strings.builder_make(0, 100 * 1000)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "id,data\n")
    for i in 0..<2000 {
        strings.write_string(&builder, fmt.tprintf("%d,Data%d\n", i, i))
    }

    csv_data := strings.to_string(builder)

    // Use auto thread count (0 = auto-detect)
    config := ocsv.Parallel_Config{
        num_threads = 0,
    }

    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)

    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 2001)
}

//
// Chunk Splitting Tests
//

@(test)
test_find_safe_chunks :: proc(t: ^testing.T) {
    csv_data := "a,b,c\n1,2,3\n4,5,6\n7,8,9\n"

    chunks := ocsv.find_safe_chunks(csv_data, 2)
    defer delete(chunks)

    testing.expect(t, len(chunks) > 0, "Should create chunks")
    testing.expect(t, len(chunks) <= 2, "Should not exceed requested chunks")

    // Verify chunks cover all data
    total_len := 0
    for chunk in chunks {
        total_len += len(chunk)
    }
    testing.expect_value(t, total_len, len(csv_data))
}

@(test)
test_find_safe_chunks_quoted_fields :: proc(t: ^testing.T) {
    // Test that chunks are created without splitting rows
    // Note: Individual chunks may not be parseable if they start mid-file
    // The important thing is that when merged, all data is preserved
    builder := strings.builder_make(0, 100 * 1024)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "name,description\n")
    for i in 0..<1000 {
        if i % 2 == 0 {
            strings.write_string(&builder, fmt.tprintf("Name%d,\"Line1\nLine2\"\n", i))
        } else {
            strings.write_string(&builder, fmt.tprintf("Name%d,Simple\n", i))
        }
    }

    csv_data := strings.to_string(builder)

    chunks := ocsv.find_safe_chunks(csv_data, 4)
    defer delete(chunks)

    testing.expect(t, len(chunks) > 0, "Should create chunks")

    // Verify chunks cover all data
    total_len := 0
    for chunk in chunks {
        total_len += len(chunk)
    }
    testing.expect_value(t, total_len, len(csv_data))
}

@(test)
test_find_next_row_boundary :: proc(t: ^testing.T) {
    csv_data := "a,b,c\n1,2,3\n"

    // Find first newline
    boundary1 := ocsv.find_next_row_boundary(csv_data, 0)
    testing.expect_value(t, boundary1, 6)  // After "a,b,c\n"

    // Find second newline
    boundary2 := ocsv.find_next_row_boundary(csv_data, boundary1)
    testing.expect_value(t, boundary2, 12)  // After "1,2,3\n"

    // No more newlines
    boundary3 := ocsv.find_next_row_boundary(csv_data, boundary2)
    testing.expect_value(t, boundary3, -1)
}

@(test)
test_find_next_row_boundary_quoted :: proc(t: ^testing.T) {
    // Newline inside quotes should be skipped
    csv_data := "a,\"b\nc\",d\ne,f,g\n"

    // Should find newline after quoted field
    // csv_data = "a,\"b\nc\",d\ne,f,g\n"
    //              0123456789...
    //                        ^10 (after \n following d)
    boundary := ocsv.find_next_row_boundary(csv_data, 0)
    testing.expect_value(t, boundary, 10)  // After "a,\"b\nc\",d\n" (position right after the \n)
}

//
// Result Merging Tests
//

@(test)
test_merge_worker_results_empty :: proc(t: ^testing.T) {
    results: []ocsv.Parse_Worker_Result

    parser := ocsv.merge_worker_results(results)

    testing.expect(t, parser == nil, "Should return nil for empty results")
}

@(test)
test_merge_worker_results_single :: proc(t: ^testing.T) {
    // Create single parser result
    p := ocsv.parser_create()
    // Note: Don't defer destroy - merge_worker_results takes ownership

    ok := ocsv.parse_csv(p, "a,b\n1,2\n")
    testing.expect(t, ok, "Parse should succeed")

    results := []ocsv.Parse_Worker_Result{
        {parser = p, chunk_index = 0, success = true},
    }

    merged := ocsv.merge_worker_results(results)
    defer ocsv.parser_destroy(merged)

    // Merged parser should be created and p is destroyed by merge
    testing.expect(t, merged != nil, "Should create merged parser")
}

@(test)
test_merge_worker_results_order :: proc(t: ^testing.T) {
    // Create parsers in wrong order
    p1 := ocsv.parser_create()
    p2 := ocsv.parser_create()
    // Note: Don't defer destroy - merge_worker_results takes ownership

    ocsv.parse_csv(p1, "c,d\n")  // Chunk 1
    ocsv.parse_csv(p2, "a,b\n")  // Chunk 0

    // Submit in wrong order
    results := []ocsv.Parse_Worker_Result{
        {parser = p1, chunk_index = 1, success = true},
        {parser = p2, chunk_index = 0, success = true},
    }

    merged := ocsv.merge_worker_results(results)
    defer ocsv.parser_destroy(merged)

    testing.expect(t, merged != nil, "Should create merged parser")
    testing.expect_value(t, len(merged.all_rows), 2)

    // Should be sorted by chunk_index
    testing.expect_value(t, merged.all_rows[0][0], "a")  // Chunk 0 first
    testing.expect_value(t, merged.all_rows[1][0], "c")  // Chunk 1 second
}

//
// Edge Cases
//

@(test)
test_parallel_empty_csv :: proc(t: ^testing.T) {
    csv_data := ""

    config := ocsv.Parallel_Config{num_threads = 4}
    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)

    testing.expect(t, ok, "Parse should succeed for empty CSV")
    testing.expect_value(t, len(parser.all_rows), 0)
}

@(test)
test_parallel_single_row :: proc(t: ^testing.T) {
    csv_data := "a,b,c\n"

    config := ocsv.Parallel_Config{num_threads = 4}
    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)

    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 1)
}

@(test)
test_parallel_quoted_fields :: proc(t: ^testing.T) {
    builder := strings.builder_make(0, 100 * 1000)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "name,description\n")
    for i in 0..<1000 {
        if i % 2 == 0 {
            // Add quoted field with comma
            strings.write_string(&builder, fmt.tprintf("Name%d,\"Description %d, with comma\"\n", i, i))
        } else {
            strings.write_string(&builder, fmt.tprintf("Name%d,Description %d\n", i, i))
        }
    }

    csv_data := strings.to_string(builder)

    config := ocsv.Parallel_Config{num_threads = 4}
    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)

    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 1001)

    // Verify quoted field was preserved
    testing.expect(t, strings.contains(parser.all_rows[1][1], "comma"), "Quoted field should be preserved")
}

@(test)
test_parallel_multiline_fields :: proc(t: ^testing.T) {
    builder := strings.builder_make(0, 100 * 1000)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "id,text\n")
    for i in 0..<1000 {
        if i % 3 == 0 {
            // Add multiline field
            strings.write_string(&builder, fmt.tprintf("%d,\"Line1\nLine2\nLine3\"\n", i))
        } else {
            strings.write_string(&builder, fmt.tprintf("%d,SingleLine\n", i))
        }
    }

    csv_data := strings.to_string(builder)

    config := ocsv.Parallel_Config{num_threads = 4}
    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)

    testing.expect(t, ok, "Parse should succeed")
    testing.expect_value(t, len(parser.all_rows), 1001)
}

//
// Performance Tests
//

@(test)
test_get_optimal_thread_count :: proc(t: ^testing.T) {
    // Small file - should return 1
    count1 := ocsv.get_optimal_thread_count(32 * 1024)  // 32 KB
    testing.expect_value(t, count1, 1)

    // Medium file - should return reasonable count
    count2 := ocsv.get_optimal_thread_count(512 * 1024)  // 512 KB
    testing.expect(t, count2 >= 1 && count2 <= os.processor_core_count(), "Should return reasonable count")

    // Large file - should return CPU count
    count3 := ocsv.get_optimal_thread_count(10 * 1024 * 1024)  // 10 MB
    cpu_count := os.processor_core_count()
    if cpu_count > 0 {
        testing.expect_value(t, count3, cpu_count)
    }
}

@(test)
test_parallel_vs_sequential_correctness :: proc(t: ^testing.T) {
    // Generate same CSV and parse both ways
    builder := strings.builder_make(0, 100 * 1000)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "id,name,value\n")
    for i in 0..<2000 {
        strings.write_string(&builder, fmt.tprintf("%d,Name%d,%d\n", i, i, i * 10))
    }

    csv_data := strings.to_string(builder)

    // Sequential parse
    seq_parser := ocsv.parser_create()
    defer ocsv.parser_destroy(seq_parser)
    seq_ok := ocsv.parse_csv(seq_parser, csv_data)
    testing.expect(t, seq_ok, "Sequential parse should succeed")

    // Parallel parse
    config := ocsv.Parallel_Config{num_threads = 4}
    par_parser, par_ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(par_parser)
    testing.expect(t, par_ok, "Parallel parse should succeed")

    // Compare results
    testing.expect_value(t, len(par_parser.all_rows), len(seq_parser.all_rows))

    // Spot check some rows
    for i in 0..<min(10, len(seq_parser.all_rows)) {
        testing.expect_value(t, len(par_parser.all_rows[i]), len(seq_parser.all_rows[i]))

        for j in 0..<len(seq_parser.all_rows[i]) {
            testing.expect_value(t, par_parser.all_rows[i][j], seq_parser.all_rows[i][j])
        }
    }
}
