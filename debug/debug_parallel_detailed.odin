package main

import "core:fmt"
import "core:strings"
import ocsv "../src"

main :: proc() {
    fmt.println("=== Detailed Parallel Parsing Debug ===\n")

    // Create medium-sized test CSV
    builder := strings.builder_make(0, 2 * 1024 * 1024)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "id,name\n")
    for i in 0..<20000 {
        strings.write_string(&builder, fmt.tprintf("%d,Name%d\n", i, i))
    }

    csv_data := strings.to_string(builder)
    fmt.printfln("CSV data: %.2f MB, %d characters\n",
        f64(len(csv_data)) / (1024.0 * 1024.0), len(csv_data))

    // Parse sequentially first for reference
    fmt.println("=== Sequential Parse ===")
    parser_seq := ocsv.parser_create()
    ok_seq := ocsv.parse_csv(parser_seq, csv_data)
    fmt.printfln("Success: %v, Rows: %d\n", ok_seq, len(parser_seq.all_rows))

    // Parse in parallel with 2 threads (forcing it)
    fmt.println("=== Parallel Parse (2 threads) ===")
    config := ocsv.Parallel_Config{num_threads = 2, min_file_size = 0}
    parser_par, ok_par := ocsv.parse_parallel(csv_data, config)

    fmt.printfln("Success: %v", ok_par)
    fmt.printfln("Rows: %d (expected: %d)", len(parser_par.all_rows), len(parser_seq.all_rows))

    if len(parser_par.all_rows) != len(parser_seq.all_rows) {
        fmt.println("\n⚠️  Row count mismatch!")
        fmt.printfln("Missing: %d rows", len(parser_seq.all_rows) - len(parser_par.all_rows))

        // Check if we got any specific rows
        fmt.println("\nFirst 10 parallel rows:")
        for i in 0..<min(10, len(parser_par.all_rows)) {
            fmt.printfln("  %v", parser_par.all_rows[i])
        }

        fmt.println("\nLast 10 parallel rows:")
        start_idx := max(0, len(parser_par.all_rows) - 10)
        for i in start_idx..<len(parser_par.all_rows) {
            fmt.printfln("  %v", parser_par.all_rows[i])
        }
    } else {
        fmt.println("\n✅ Row counts match!")
    }

    ocsv.parser_destroy(parser_seq)
    ocsv.parser_destroy(parser_par)
}
