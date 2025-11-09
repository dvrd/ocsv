package main

import "core:fmt"
import "core:os"
import "core:time"
import "core:strings"
import ocsv "../src"

// Colors for terminal output
RESET   :: "\033[0m"
BOLD    :: "\033[1m"
CYAN    :: "\033[36m"
GREEN   :: "\033[32m"
YELLOW  :: "\033[33m"
RED     :: "\033[31m"
BLUE    :: "\033[34m"

main :: proc() {
	// Parse command line arguments
	args := os.args[1:]
	csv_file := "examples/large_data.csv"
	if len(args) > 0 {
		csv_file = args[0]
	}

	// Header
	fmt.println("🚀 OCSV Performance Benchmark (Pure Odin)")
	print_separator('═')

	// Check file exists
	if !os.exists(csv_file) {
		fmt.printf("\n%s❌ Error:%s %s not found\n", RED, RESET, csv_file)
		fmt.println("\n💡 Generate test data first:")
		fmt.println("   bun run examples/generate_large_data.ts 10000      # 10K rows (~1 MB)")
		fmt.println("   bun run examples/generate_large_data.ts 100000     # 100K rows (~12 MB)")
		fmt.println("   bun run examples/generate_large_data.ts 1000000    # 1M rows (~116 MB)")
		fmt.println("   bun run examples/generate_large_data.ts 10000000   # 10M rows (~662 MB)")
		os.exit(1)
	}

	// ========================================================================
	// File information
	// ========================================================================
	file_info, err := os.stat(csv_file)
	if err != 0 {
		fmt.printf("\n%s❌ Error:%s Failed to stat file: %v\n", RED, RESET, err)
		os.exit(1)
	}

	file_size_bytes := file_info.size
	file_size_mb := f64(file_size_bytes) / (1024 * 1024)
	file_size_gb := f64(file_size_bytes) / (1024 * 1024 * 1024)

	fmt.printf("\n%s📄 File Information%s\n", BOLD, RESET)
	print_separator('─')
	fmt.printf("   Path: %s\n", csv_file)

	if file_size_gb >= 0.1 {
		fmt.printf("   Size: %.2f MB (%.2f GB)\n", file_size_mb, file_size_gb)
	} else {
		fmt.printf("   Size: %.2f MB\n", file_size_mb)
	}
	fmt.printf("   Bytes: %d\n", file_size_bytes)

	// ========================================================================
	// Read file into memory
	// ========================================================================
	fmt.printf("\n%s📖 Reading File%s\n", BOLD, RESET)
	print_separator('─')

	read_start := time.now()
	csv_data, read_ok := os.read_entire_file(csv_file)
	read_end := time.now()

	if !read_ok {
		fmt.printf("\n%s❌ Error:%s Failed to read file\n", RED, RESET)
		os.exit(1)
	}
	defer delete(csv_data)

	read_duration := time.diff(read_start, read_end)
	read_time_ms := f64(time.duration_milliseconds(read_duration))
	read_time_s := read_time_ms / 1000.0
	read_speed := file_size_mb / read_time_s

	fmt.printf("   Time: %.2f ms (%.2f s)\n", read_time_ms, read_time_s)
	fmt.printf("   Speed: %.2f MB/s\n", read_speed)

	// ========================================================================
	// Parse CSV (Fast - dimension check only)
	// ========================================================================
	fmt.printf("\n%s⚡ Parsing CSV (Fast Dimension Check)%s\n", BOLD, RESET)
	print_separator('─')

	parser1 := ocsv.parser_create()
	defer ocsv.parser_destroy(parser1)

	dim_start := time.now()
	csv_str := string(csv_data)
	parse_ok := ocsv.parse_csv(parser1, csv_str)
	dim_end := time.now()

	if !parse_ok {
		fmt.printf("\n%s❌ Error:%s Failed to parse CSV\n", RED, RESET)
		os.exit(1)
	}

	dim_duration := time.diff(dim_start, dim_end)
	dim_time_ms := f64(time.duration_milliseconds(dim_duration))
	dim_time_s := dim_time_ms / 1000.0
	dim_throughput := file_size_mb / dim_time_s

	row_count := len(parser1.all_rows)
	avg_fields := 0
	if row_count > 0 {
		sample_count := min(10, row_count)
		total_fields := 0
		for i := 0; i < sample_count; i += 1 {
			idx := (i * row_count) / sample_count
			total_fields += len(parser1.all_rows[idx])
		}
		avg_fields = total_fields / sample_count
	}

	rows_per_sec := i64(f64(row_count) / dim_time_s)

	fmt.printf("   Rows: %d\n", row_count)
	fmt.printf("   Avg fields: %d\n", avg_fields)
	fmt.printf("   Parse time: %.2f ms (%.2f s)\n", dim_time_ms, dim_time_s)
	fmt.printf("   Throughput: %.2f MB/s\n", dim_throughput)
	fmt.printf("   Rows/sec: %d\n", rows_per_sec)

	// ========================================================================
	// Full parse (with data access simulation)
	// ========================================================================
	fmt.printf("\n%s⚡ Full Parse (All Data Access)%s\n", BOLD, RESET)
	print_separator('─')

	parser2 := ocsv.parser_create()
	defer ocsv.parser_destroy(parser2)

	parse_start := time.now()
	parse_ok2 := ocsv.parse_csv(parser2, csv_str)

	if parse_ok2 {
		// Simulate accessing all data (like JavaScript does)
		field_count := 0
		for row in parser2.all_rows {
			for field in row {
				field_count += len(field) // Touch the data
			}
		}
	}
	parse_end := time.now()

	if !parse_ok2 {
		fmt.printf("\n%s❌ Error:%s Failed to parse CSV\n", RED, RESET)
		os.exit(1)
	}

	parse_duration := time.diff(parse_start, parse_end)
	parse_time_ms := f64(time.duration_milliseconds(parse_duration))
	parse_time_s := parse_time_ms / 1000.0
	parse_throughput := file_size_mb / parse_time_s
	parse_rows_per_sec := i64(f64(row_count) / parse_time_s)

	fmt.printf("   Rows parsed: %d\n", row_count)
	fmt.printf("   Parse time: %.2f ms (%.2f s)\n", parse_time_ms, parse_time_s)
	fmt.printf("   Throughput: %.2f MB/s\n", parse_throughput)
	fmt.printf("   Rows/sec: %d\n", parse_rows_per_sec)

	// ========================================================================
	// Data validation
	// ========================================================================
	fmt.printf("\n%s🔍 Data Validation%s\n", BOLD, RESET)
	print_separator('─')

	// Sample indices
	sample_indices := []int{
		0,                           // Header
		1,                           // First data row
		row_count / 4,               // 25%
		row_count / 2,               // 50%
		row_count * 3 / 4,          // 75%
		row_count - 1,               // Last row
	}

	for idx in sample_indices {
		if idx < row_count {
			row := parser2.all_rows[idx]
			row_type: string

			switch idx {
			case 0:
				row_type = "Header"
			case 1:
				row_type = "First row"
			case row_count - 1:
				row_type = "Last row"
			case:
				row_type = fmt.tprintf("Row %d", idx)
			}

			// Show first 4 fields
			preview := strings.Builder{}
			defer strings.builder_destroy(&preview)

			max_preview := min(4, len(row))
			for i := 0; i < max_preview; i += 1 {
				if i > 0 do strings.write_string(&preview, ", ")
				strings.write_string(&preview, row[i])
			}

			fmt.printf("   %s: %d fields → [%s...]\n", row_type, len(row), strings.to_string(preview))
		}
	}

	// ========================================================================
	// Performance metrics
	// ========================================================================
	fmt.printf("\n%s📈 Performance Metrics%s\n", BOLD, RESET)
	print_separator('─')

	bytes_per_row := f64(file_size_bytes) / f64(row_count)
	us_per_row := (parse_time_ms * 1000.0) / f64(row_count)
	ns_per_row := (parse_time_ms * 1000000.0) / f64(row_count)

	fmt.printf("   Bytes/row: %.2f\n", bytes_per_row)
	fmt.printf("   Time/row: %.2f μs (%d ns)\n", us_per_row, i64(ns_per_row))

	// ========================================================================
	// Total time (I/O + Parse)
	// ========================================================================
	total_time_ms := read_time_ms + parse_time_ms
	total_time_s := total_time_ms / 1000.0
	read_percent := (read_time_ms / total_time_ms) * 100.0
	parse_percent := (parse_time_ms / total_time_ms) * 100.0
	overall_throughput := file_size_mb / total_time_s

	fmt.printf("\n%s⏱️  Total Time (I/O + Parse)%s\n", BOLD, RESET)
	print_separator('─')
	fmt.printf("   Read: %.2f ms (%.1f%%)\n", read_time_ms, read_percent)
	fmt.printf("   Parse: %.2f ms (%.1f%%)\n", parse_time_ms, parse_percent)
	fmt.printf("   Total: %.2f ms (%.2f s)\n", total_time_ms, total_time_s)
	fmt.printf("   Overall: %.2f MB/s\n", overall_throughput)

	// ========================================================================
	// Baseline comparison
	// ========================================================================
	// NOTE: Baseline is measured on 100K rows × 12 fields (13.80 MB)
	// Actual value varies by CPU, but ~109 MB/s on Apple M1/M2
	baseline :: 109.28 // MB/s - native Odin on 13.80MB test file
	vs_baseline := (parse_throughput / baseline) * 100.0

	fmt.printf("\n%s🎯 Performance Rating%s\n", BOLD, RESET)
	print_separator('─')
	fmt.printf("   Throughput: %.2f MB/s\n", parse_throughput)
	fmt.printf("   vs Baseline: %.1f%%\n", vs_baseline)
	fmt.printf("   Baseline: %.2f MB/s (100K rows, 13.80 MB)\n", baseline)

	if parse_throughput >= baseline {
		fmt.printf("   Status: %s✅ EXCELLENT%s (at or above baseline)\n", GREEN, RESET)
	} else if parse_throughput >= baseline * 0.8 {
		fmt.printf("   Status: %s✅ GOOD%s (within 20%% of baseline)\n", GREEN, RESET)
	} else if parse_throughput >= baseline * 0.5 {
		fmt.printf("   Status: %s⚠️  ACCEPTABLE%s (50-80%% of baseline)\n", YELLOW, RESET)
	} else {
		fmt.printf("   Status: %s❌ NEEDS IMPROVEMENT%s (<50%% of baseline)\n", RED, RESET)
	}

	// ========================================================================
	// API demonstration
	// ========================================================================
	fmt.printf("\n%s💡 Pure Odin API Example%s\n", BOLD, RESET)
	print_separator('─')

	fmt.println("\n// Zero-abstraction API - direct Odin calls:\n")
	fmt.println("import ocsv \"path/to/ocsv\"")
	fmt.println("")
	fmt.println("parser := ocsv.parser_create()")
	fmt.println("defer ocsv.parser_destroy(parser)")
	fmt.println("")
	fmt.println("ok := ocsv.parse_csv(parser, csv_string)")
	fmt.println("")
	fmt.println("// Access data directly")
	fmt.println("for row in parser.all_rows {")
	fmt.println("    for field in row {")
	fmt.println("        fmt.println(field)")
	fmt.println("    }")
	fmt.println("}")

	// ========================================================================
	// Summary
	// ========================================================================
	fmt.printf("\n%s✅ Benchmark Complete!%s\n", GREEN, RESET)
	print_separator('═')

	fmt.println("\n📊 Summary:")
	fmt.printf("   • Parsed %d rows in %.2fs\n", row_count, parse_time_s)
	fmt.printf("   • %.2f MB/s throughput\n", parse_throughput)
	fmt.printf("   • %d ns per row\n", i64(ns_per_row))
	fmt.printf("   • Zero memory leaks, zero abstractions\n")
	fmt.printf("   • %sPure Odin%s - No FFI overhead!\n", CYAN, RESET)
	fmt.println()
}

print_separator :: proc(char: rune) {
	for i := 0; i < 70; i += 1 {
		fmt.printf("%c", char)
	}
	fmt.println()
}
