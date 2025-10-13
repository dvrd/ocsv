package main

import "core:fmt"
import "core:time"
import "core:os"
import "core:strings"
import ocsv "../src"

main :: proc() {
	// Generate test data: 50,000 rows, 8 columns
	rows := 50_000
	cols := 8

	// Generate CSV data
	builder := strings.builder_make(0, rows * cols * 10)
	defer strings.builder_destroy(&builder)

	// Header
	for i in 0..<cols {
		if i > 0 do strings.write_byte(&builder, ',')
		fmt.sbprintf(&builder, "col%d", i)
	}
	strings.write_byte(&builder, '\n')

	// Data rows
	for row in 0..<rows {
		for col in 0..<cols {
			if col > 0 do strings.write_byte(&builder, ',')
			fmt.sbprintf(&builder, "r%dc%d", row, col)
		}
		strings.write_byte(&builder, '\n')
	}

	csv_data := strings.to_string(builder)
	data_size := len(csv_data)
	data_mb := f64(data_size) / (1024.0 * 1024.0)

	fmt.printfln("Dataset: %d rows, %d columns", rows, cols)
	fmt.printfln("Data size: %.2f MB\n", data_mb)

	// Test configurations
	configs := []struct {
		name: string,
		threads: int,
	}{
		{"Sequential", 0},  // Will use sequential because of min_file_size
		{"2 Threads", 2},
		{"4 Threads", 4},
		{"8 Threads", 8},
	}

	for cfg in configs {
		fmt.printfln("=== %s ===", cfg.name)

		config := ocsv.Parallel_Config{
			num_threads = cfg.threads,
			min_file_size = 0,  // Force parallel even for small files
		}

		start := time.now()

		parser, ok := ocsv.parse_parallel(csv_data, config)
		defer ocsv.parser_destroy(parser)

		end := time.now()
		duration := time.diff(start, end)

		if !ok {
			fmt.printfln("Parse failed!\n")
			continue
		}

		row_count := len(parser.all_rows)
		expected_rows := rows + 1  // +1 for header

		time_ms := f64(time.duration_milliseconds(duration))
		time_s := time_ms / 1000.0
		throughput := data_mb / time_s
		rows_per_sec := i64(f64(row_count) / time_s)

		fmt.printfln("Rows parsed: %d (expected: %d) %s",
			row_count, expected_rows,
			row_count == expected_rows ? "✓" : "✗ MISMATCH")
		fmt.printfln("Time: %.2f ms", time_ms)
		fmt.printfln("Throughput: %.2f MB/s", throughput)
		fmt.printfln("Rows/sec: %d\n", rows_per_sec)
	}
}
