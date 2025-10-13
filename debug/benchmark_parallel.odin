package main

import "core:fmt"
import "core:strings"
import "core:time"
import ocsv "../src"

main :: proc() {
    // Generate large CSV for benchmarking
    builder := strings.builder_make(0, 10 * 1024 * 1024)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "id,name,email,age,city,department,salary,start_date\n")

    // Generate 50,000 rows
    for i in 0..<50000 {
        strings.write_string(&builder, fmt.tprintf(
            "%d,Employee%d,emp%d@company.com,%d,City%d,Dept%d,%d,2020-01-01\n",
            i, i, i, 25 + (i % 40), i % 100, i % 20, 50000 + (i % 50000),
        ))
    }

    csv_data := strings.to_string(builder)
    fmt.printfln("Generated CSV: %.2f MB, %d rows",
        f64(len(csv_data)) / (1024.0 * 1024.0), 50001)

    // Benchmark sequential parsing
    fmt.println("\n=== Sequential Parsing ===")
    {
        start := time.now()
        parser := ocsv.parser_create()
        ok := ocsv.parse_csv(parser, csv_data)
        elapsed := time.since(start)

        fmt.printfln("Success: %v", ok)
        fmt.printfln("Rows parsed: %d", len(parser.all_rows))
        fmt.printfln("Time: %v", elapsed)
        fmt.printfln("Throughput: %.2f MB/s",
            f64(len(csv_data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed))
        fmt.printfln("Rows/sec: %.0f",
            f64(len(parser.all_rows)) / time.duration_seconds(elapsed))

        ocsv.parser_destroy(parser)
    }

    // Benchmark parallel parsing (2 threads)
    fmt.println("\n=== Parallel Parsing (2 threads) ===")
    {
        config := ocsv.Parallel_Config{num_threads = 2}
        start := time.now()
        parser, ok := ocsv.parse_parallel(csv_data, config)
        elapsed := time.since(start)

        fmt.printfln("Success: %v", ok)
        fmt.printfln("Rows parsed: %d", len(parser.all_rows))
        fmt.printfln("Time: %v", elapsed)
        fmt.printfln("Throughput: %.2f MB/s",
            f64(len(csv_data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed))
        fmt.printfln("Rows/sec: %.0f",
            f64(len(parser.all_rows)) / time.duration_seconds(elapsed))

        ocsv.parser_destroy(parser)
    }

    // Benchmark parallel parsing (4 threads)
    fmt.println("\n=== Parallel Parsing (4 threads) ===")
    {
        config := ocsv.Parallel_Config{num_threads = 4}
        start := time.now()
        parser, ok := ocsv.parse_parallel(csv_data, config)
        elapsed := time.since(start)

        fmt.printfln("Success: %v", ok)
        fmt.printfln("Rows parsed: %d", len(parser.all_rows))
        fmt.printfln("Time: %v", elapsed)
        fmt.printfln("Throughput: %.2f MB/s",
            f64(len(csv_data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed))
        fmt.printfln("Rows/sec: %.0f",
            f64(len(parser.all_rows)) / time.duration_seconds(elapsed))

        ocsv.parser_destroy(parser)
    }

    // Benchmark parallel parsing (8 threads)
    fmt.println("\n=== Parallel Parsing (8 threads) ===")
    {
        config := ocsv.Parallel_Config{num_threads = 8}
        start := time.now()
        parser, ok := ocsv.parse_parallel(csv_data, config)
        elapsed := time.since(start)

        fmt.printfln("Success: %v", ok)
        fmt.printfln("Rows parsed: %d", len(parser.all_rows))
        fmt.printfln("Time: %v", elapsed)
        fmt.printfln("Throughput: %.2f MB/s",
            f64(len(csv_data)) / (1024.0 * 1024.0) / time.duration_seconds(elapsed))
        fmt.printfln("Rows/sec: %.0f",
            f64(len(parser.all_rows)) / time.duration_seconds(elapsed))

        ocsv.parser_destroy(parser)
    }
}
