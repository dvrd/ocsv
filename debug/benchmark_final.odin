package main

import "core:fmt"
import "core:strings"
import "core:time"
import ocsv "../src"

main :: proc() {
    fmt.println("╔══════════════════════════════════════════════════════════════╗")
    fmt.println("║     OCSV Parallel Processing - Final Performance Report      ║")
    fmt.println("╚══════════════════════════════════════════════════════════════╝")
    fmt.println()

    test_scenarios := []struct {
        name:          string,
        rows:          int,
        expected_mode: string,
    }{
        {"Tiny (1K rows, ~15 KB)", 1_000, "Sequential"},
        {"Small (10K rows, ~150 KB)", 10_000, "Sequential"},
        {"Medium (50K rows, ~3.5 MB)", 50_000, "Sequential"},
        {"Large (150K rows, ~14 MB)", 150_000, "Parallel"},
        {"Very Large (300K rows, ~29 MB)", 300_000, "Parallel"},
    }

    for scenario in test_scenarios {
        fmt.println("─────────────────────────────────────────────────────────────")
        fmt.printfln("Test: %s", scenario.name)
        fmt.printfln("Expected mode: %s", scenario.expected_mode)
        fmt.println()

        // Generate test data
        builder := strings.builder_make(0, scenario.rows * 100)
        defer strings.builder_destroy(&builder)

        strings.write_string(&builder, "id,name,email,age,city,department,salary,start_date,notes\n")
        for i in 0..<scenario.rows {
            strings.write_string(&builder, fmt.tprintf(
                "%d,Employee%d,emp%d@company.com,%d,City%d,Dept%d,%d,2020-01-01,Notes %d\n",
                i, i, i, 25 + (i % 40), i % 100, i % 20, 50000 + (i % 50000), i,
            ))
        }

        csv_data := strings.to_string(builder)
        file_size_mb := f64(len(csv_data)) / (1024.0 * 1024.0)
        fmt.printfln("File size: %.2f MB (%d bytes)", file_size_mb, len(csv_data))

        // Sequential baseline
        start_seq := time.now()
        parser_seq := ocsv.parser_create()
        ok_seq := ocsv.parse_csv(parser_seq, csv_data)
        elapsed_seq := time.since(start_seq)

        if !ok_seq {
            fmt.println("❌ Sequential parse failed!")
            ocsv.parser_destroy(parser_seq)
            continue
        }

        seq_throughput := file_size_mb / time.duration_seconds(elapsed_seq)
        seq_rows_per_sec := f64(len(parser_seq.all_rows)) / time.duration_seconds(elapsed_seq)

        fmt.printfln("  Sequential: %v | %d rows | %.2f MB/s | %.0f rows/sec",
            elapsed_seq, len(parser_seq.all_rows), seq_throughput, seq_rows_per_sec)

        // Parallel (auto threads)
        if file_size_mb >= 10 {
            config_auto := ocsv.Parallel_Config{num_threads = 0, min_file_size = 0}
            start_par_auto := time.now()
            parser_par_auto, ok_par_auto := ocsv.parse_parallel(csv_data, config_auto)
            elapsed_par_auto := time.since(start_par_auto)

            if ok_par_auto && len(parser_par_auto.all_rows) == len(parser_seq.all_rows) {
                speedup := time.duration_seconds(elapsed_seq) / time.duration_seconds(elapsed_par_auto)
                par_throughput := file_size_mb / time.duration_seconds(elapsed_par_auto)
                fmt.printfln("  Parallel (auto): %v | %d rows | %.2f MB/s | %.2fx speedup",
                    elapsed_par_auto, len(parser_par_auto.all_rows), par_throughput, speedup)
            } else {
                fmt.printfln("  Parallel (auto): ❌ Failed or row mismatch")
            }

            ocsv.parser_destroy(parser_par_auto)

            // Parallel (2 threads)
            config_2 := ocsv.Parallel_Config{num_threads = 2, min_file_size = 0}
            start_par_2 := time.now()
            parser_par_2, ok_par_2 := ocsv.parse_parallel(csv_data, config_2)
            elapsed_par_2 := time.since(start_par_2)

            if ok_par_2 && len(parser_par_2.all_rows) == len(parser_seq.all_rows) {
                speedup := time.duration_seconds(elapsed_seq) / time.duration_seconds(elapsed_par_2)
                par_throughput := file_size_mb / time.duration_seconds(elapsed_par_2)
                fmt.printfln("  Parallel (2t): %v | %d rows | %.2f MB/s | %.2fx speedup",
                    elapsed_par_2, len(parser_par_2.all_rows), par_throughput, speedup)
            } else {
                fmt.printfln("  Parallel (2t): ❌ Failed or row mismatch")
            }

            ocsv.parser_destroy(parser_par_2)

            // Parallel (4 threads)
            config_4 := ocsv.Parallel_Config{num_threads = 4, min_file_size = 0}
            start_par_4 := time.now()
            parser_par_4, ok_par_4 := ocsv.parse_parallel(csv_data, config_4)
            elapsed_par_4 := time.since(start_par_4)

            if ok_par_4 && len(parser_par_4.all_rows) == len(parser_seq.all_rows) {
                speedup := time.duration_seconds(elapsed_seq) / time.duration_seconds(elapsed_par_4)
                par_throughput := file_size_mb / time.duration_seconds(elapsed_par_4)
                fmt.printfln("  Parallel (4t): %v | %d rows | %.2f MB/s | %.2fx speedup",
                    elapsed_par_4, len(parser_par_4.all_rows), par_throughput, speedup)
            } else {
                fmt.printfln("  Parallel (4t): ❌ Failed or row mismatch")
            }

            ocsv.parser_destroy(parser_par_4)
        } else {
            // Test with threshold check
            config := ocsv.Parallel_Config{num_threads = 4}
            start_par := time.now()
            parser_par, ok_par := ocsv.parse_parallel(csv_data, config)
            elapsed_par := time.since(start_par)

            if ok_par && len(parser_par.all_rows) == len(parser_seq.all_rows) {
                speedup := time.duration_seconds(elapsed_seq) / time.duration_seconds(elapsed_par)
                fmt.printfln("  Parallel (with 10MB threshold): %v | %.2fx (falls back to sequential)",
                    elapsed_par, speedup)
            }

            ocsv.parser_destroy(parser_par)
        }

        ocsv.parser_destroy(parser_seq)
        fmt.println()
    }

    fmt.println("╔══════════════════════════════════════════════════════════════╗")
    fmt.println("║                   Benchmark Complete                          ║")
    fmt.println("╚══════════════════════════════════════════════════════════════╝")
}
