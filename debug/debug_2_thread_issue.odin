package main

import "core:fmt"
import "core:strings"
import ocsv "../src"

main :: proc() {
    fmt.println("=== Debugging 2-Thread Row Loss ===\n")

    // Create same large file as benchmark
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
    fmt.printfln("CSV data size: %.2f MB", f64(len(csv_data)) / (1024.0 * 1024.0))
    fmt.printfln("Total characters: %d\n", len(csv_data))

    // Test chunk splitting with 2 chunks
    chunks := ocsv.find_safe_chunks(csv_data, 2)
    defer delete(chunks)

    fmt.printfln("Created %d chunks:\n", len(chunks))

    total_coverage := 0
    for chunk, i in chunks {
        fmt.printfln("Chunk %d:", i)
        fmt.printfln("  Size: %d bytes (%.2f MB)", len(chunk), f64(len(chunk)) / (1024.0 * 1024.0))
        fmt.printfln("  Start pos: %d", total_coverage)
        fmt.printfln("  End pos: %d", total_coverage + len(chunk))

        // Show first and last 100 characters
        preview_len := min(100, len(chunk))
        fmt.printfln("  First %d chars: %q", preview_len, chunk[:preview_len])

        if len(chunk) > preview_len {
            last_start := len(chunk) - preview_len
            fmt.printfln("  Last %d chars: %q", preview_len, chunk[last_start:])
        }

        // Parse this chunk
        parser := ocsv.parser_create()
        ok := ocsv.parse_csv(parser, chunk)
        fmt.printfln("  Parse success: %v", ok)
        fmt.printfln("  Rows parsed: %d\n", len(parser.all_rows))
        ocsv.parser_destroy(parser)

        total_coverage += len(chunk)
    }

    fmt.printfln("Total coverage: %d bytes", total_coverage)
    fmt.printfln("Original size: %d bytes", len(csv_data))
    fmt.printfln("Coverage match: %v\n", total_coverage == len(csv_data))

    // Now test actual parallel parsing with 2 threads
    fmt.println("=== Parallel Parsing (2 threads) ===")
    config := ocsv.Parallel_Config{num_threads = 2, min_file_size = 0}
    parser, ok := ocsv.parse_parallel(csv_data, config)
    defer ocsv.parser_destroy(parser)

    fmt.printfln("Parse success: %v", ok)
    fmt.printfln("Total rows: %d (expected: 150001)", len(parser.all_rows))

    if len(parser.all_rows) != 150001 {
        fmt.println("\n⚠️  Row count mismatch detected!")
        fmt.printfln("Missing rows: %d", 150001 - len(parser.all_rows))
    }
}
