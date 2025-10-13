package main

import "core:fmt"
import "core:time"
import "core:strings"
import ocsv "../src"

// Test different file sizes to verify heuristic
main :: proc() {
	test_sizes := []struct {
		rows: int,
		name: string,
	}{
		{1_000, "1K rows (~70 KB)"},
		{10_000, "10K rows (~700 KB)"},
		{50_000, "50K rows (~3.5 MB)"},
		{100_000, "100K rows (~7 MB)"},
		{200_000, "200K rows (~14 MB)"},
	}

	for size in test_sizes {
		fmt.printfln("\n=== Testing %s ===", size.name)

		// Generate CSV data
		builder := strings.builder_make()
		defer strings.builder_destroy(&builder)

		// Header
		strings.write_string(&builder, "col0,col1,col2,col3,col4,col5,col6,col7\n")

		// Data rows
		for row in 0..<size.rows {
			fmt.sbprintf(&builder, "r%dc0,r%dc1,r%dc2,r%dc3,r%dc4,r%dc5,r%dc6,r%dc7\n",
				row, row, row, row, row, row, row, row)
		}

		csv_data := strings.to_string(builder)
		data_mb := f64(len(csv_data)) / (1024.0 * 1024.0)

		fmt.printfln("Size: %.2f MB", data_mb)

		// Test with auto-detection (config with num_threads = 0)
		config := ocsv.Parallel_Config{num_threads = 0}

		start := time.now()
		parser, ok := ocsv.parse_parallel(csv_data, config)
		end := time.now()

		if !ok || parser == nil {
			fmt.printfln("Parse failed!")
			if parser != nil do ocsv.parser_destroy(parser)
			continue
		}

		defer ocsv.parser_destroy(parser)

		duration := time.diff(start, end)
		time_ms := f64(time.duration_milliseconds(duration))
		throughput := data_mb / (time_ms / 1000.0)

		row_count := len(parser.all_rows)
		expected := size.rows + 1
		optimal_threads := ocsv.get_optimal_thread_count(len(csv_data))

		fmt.printfln("Optimal threads: %d", optimal_threads)
		fmt.printfln("Time: %.2f ms", time_ms)
		fmt.printfln("Throughput: %.2f MB/s", throughput)
		fmt.printfln("Rows: %d/%d %s", row_count, expected,
			row_count == expected ? "✓" : "✗")
	}
}
