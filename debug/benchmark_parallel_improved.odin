package main

import "core:fmt"
import "core:strings"
import "core:time"
import ocsv "../src"

main :: proc() {
    fmt.println("=== OCSV Parallel Processing Benchmark ===\n")

    // Test 1: Small file (should use sequential)
    {
        fmt.println("Test 1: Small file (100 KB)")
        fmt.println("Expected: Sequential parsing (file too small)")

        builder := strings.builder_make(0, 100 * 1024)
        defer strings.builder_destroy(&builder)

        strings.write_string(&builder, "id,name,value\n")
        for i in 0..<1000 {
            strings.write_string(&builder, fmt.tprintf("%d,Name%d,%d\n", i, i, i))
        }

        csv_data := strings.to_string(builder)
        fmt.printfln("File size: %.2f KB\n", f64(len(csv_data)) / 1024.0)

        config := ocsv.Parallel_Config{num_threads = 4, min_file_size = 0} // Use default 10 MB
        start := time.now()
        parser, ok := ocsv.parse_parallel(csv_data, config)
        elapsed := time.since(start)

        fmt.printfln("Success: %v", ok)
        fmt.printfln("Rows: %d", len(parser.all_rows))
        fmt.printfln("Time: %v\n", elapsed)

        ocsv.parser_destroy(parser)
    }

    // Test 2: Medium file (should use sequential)
    {
        fmt.println("Test 2: Medium file (5 MB)")
        fmt.println("Expected: Sequential parsing (< 10 MB threshold)")

        builder := strings.builder_make(0, 5 * 1024 * 1024)
        defer strings.builder_destroy(&builder)

        strings.write_string(&builder, "id,name,email,age,city,department,salary,start_date\n")
        for i in 0..<50000 {
            strings.write_string(&builder, fmt.tprintf(
                "%d,Employee%d,emp%d@company.com,%d,City%d,Dept%d,%d,2020-01-01\n",
                i, i, i, 25 + (i % 40), i % 100, i % 20, 50000 + (i % 50000),
            ))
        }

        csv_data := strings.to_string(builder)
        fmt.printfln("File size: %.2f MB\n", f64(len(csv_data)) / (1024.0 * 1024.0))

        // Sequential
        start_seq := time.now()
        parser_seq := ocsv.parser_create()
        ok_seq := ocsv.parse_csv(parser_seq, csv_data)
        elapsed_seq := time.since(start_seq)

        fmt.println("Sequential:")
        fmt.printfln("  Success: %v", ok_seq)
        fmt.printfln("  Rows: %d", len(parser_seq.all_rows))
        fmt.printfln("  Time: %v", elapsed_seq)
        fmt.printfln("  Throughput: %.2f MB/s\n",
            f64(len(csv_data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed_seq))

        // Parallel (should fallback to sequential)
        config := ocsv.Parallel_Config{num_threads = 4}
        start_par := time.now()
        parser_par, ok_par := ocsv.parse_parallel(csv_data, config)
        elapsed_par := time.since(start_par)

        fmt.println("Parallel (will use sequential):")
        fmt.printfln("  Success: %v", ok_par)
        fmt.printfln("  Rows: %d", len(parser_par.all_rows))
        fmt.printfln("  Time: %v", elapsed_par)
        fmt.printfln("  Speedup: %.2fx\n", time.duration_seconds(elapsed_seq) / time.duration_seconds(elapsed_par))

        ocsv.parser_destroy(parser_seq)
        ocsv.parser_destroy(parser_par)
    }

    // Test 3: Large file (should use parallel)
    {
        fmt.println("Test 3: Large file (15 MB)")
        fmt.println("Expected: Parallel parsing (> 10 MB threshold)")

        builder := strings.builder_make(0, 15 * 1024 * 1024)
        defer strings.builder_destroy(&builder)

        strings.write_string(&builder, "id,name,email,age,city,department,salary,start_date,notes\n")
        for i in 0..<150000 {
            strings.write_string(&builder, fmt.tprintf(
                "%d,Employee%d,emp%d@company.com,%d,City%d,Dept%d,%d,2020-01-01,Notes for employee %d\n",
                i, i, i, 25 + (i % 40), i % 100, i % 20, 50000 + (i % 50000), i,
            ))
        }

        csv_data := strings.to_string(builder)
        fmt.printfln("File size: %.2f MB\n", f64(len(csv_data)) / (1024.0 * 1024.0))

        // Sequential
        start_seq := time.now()
        parser_seq := ocsv.parser_create()
        ok_seq := ocsv.parse_csv(parser_seq, csv_data)
        elapsed_seq := time.since(start_seq)

        fmt.println("Sequential:")
        fmt.printfln("  Success: %v", ok_seq)
        fmt.printfln("  Rows: %d", len(parser_seq.all_rows))
        fmt.printfln("  Time: %v", elapsed_seq)
        fmt.printfln("  Throughput: %.2f MB/s",
            f64(len(csv_data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed_seq))
        fmt.printfln("  Rows/sec: %.0f\n",
            f64(len(parser_seq.all_rows)) / time.duration_seconds(elapsed_seq))

        // Parallel (2 threads)
        config2 := ocsv.Parallel_Config{num_threads = 2, min_file_size = 0}
        start_par2 := time.now()
        parser_par2, ok_par2 := ocsv.parse_parallel(csv_data, config2)
        elapsed_par2 := time.since(start_par2)

        fmt.println("Parallel (2 threads):")
        fmt.printfln("  Success: %v", ok_par2)
        fmt.printfln("  Rows: %d (expected: %d)", len(parser_par2.all_rows), len(parser_seq.all_rows))
        fmt.printfln("  Match: %v", len(parser_par2.all_rows) == len(parser_seq.all_rows))
        fmt.printfln("  Time: %v", elapsed_par2)
        fmt.printfln("  Throughput: %.2f MB/s",
            f64(len(csv_data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed_par2))
        fmt.printfln("  Speedup: %.2fx\n", time.duration_seconds(elapsed_seq) / time.duration_seconds(elapsed_par2))

        // Parallel (4 threads)
        config4 := ocsv.Parallel_Config{num_threads = 4, min_file_size = 0}
        start_par4 := time.now()
        parser_par4, ok_par4 := ocsv.parse_parallel(csv_data, config4)
        elapsed_par4 := time.since(start_par4)

        fmt.println("Parallel (4 threads):")
        fmt.printfln("  Success: %v", ok_par4)
        fmt.printfln("  Rows: %d (expected: %d)", len(parser_par4.all_rows), len(parser_seq.all_rows))
        fmt.printfln("  Match: %v", len(parser_par4.all_rows) == len(parser_seq.all_rows))
        fmt.printfln("  Time: %v", elapsed_par4)
        fmt.printfln("  Throughput: %.2f MB/s",
            f64(len(csv_data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed_par4))
        fmt.printfln("  Speedup: %.2fx\n", time.duration_seconds(elapsed_seq) / time.duration_seconds(elapsed_par4))

        ocsv.parser_destroy(parser_seq)
        ocsv.parser_destroy(parser_par2)
        ocsv.parser_destroy(parser_par4)
    }

    fmt.println("=== Benchmark Complete ===")
}
