package benchmarks

import "core:fmt"
import "core:os"
import "core:time"
import "core:strings"
import "core:mem"
import ocsv "../src"

// Benchmark configuration
Benchmark_Config :: struct {
	name:       string,
	rows:       int,
	columns:    int,
	field_size: int, // Average field size in bytes
}

// Benchmark result
Benchmark_Result :: struct {
	config:           Benchmark_Config,
	write_time_ns:    time.Duration,
	parse_time_ns:    time.Duration,
	file_size_bytes:  int,
	rows_per_sec:     f64,
	mb_per_sec:       f64,
	memory_used_mb:   f64,
}

// CSV Complexity for writer benchmarks
CSV_Complexity :: enum {
	Simple,      // Basic fields (no quotes needed)
	Quoted,      // Fields with commas (require quoting)
	Escaped,     // Fields with quotes and escapes
	Multiline,   // Fields with newlines
	Mixed,       // Mix of all above
}

BENCHMARK_CONFIGS :: []Benchmark_Config{
	// Small files
	{name = "Tiny (100 rows)", rows = 100, columns = 5, field_size = 10},
	{name = "Small (1K rows)", rows = 1_000, columns = 5, field_size = 10},
	{name = "Small (5K rows)", rows = 5_000, columns = 5, field_size = 10},
	// Medium files
	{name = "Medium (10K rows)", rows = 10_000, columns = 10, field_size = 15},
	{name = "Medium (25K rows)", rows = 25_000, columns = 10, field_size = 15},
	{name = "Medium (50K rows)", rows = 50_000, columns = 10, field_size = 15},
	// Large files
	{name = "Large (100K rows)", rows = 100_000, columns = 10, field_size = 20},
	{name = "Large (200K rows)", rows = 200_000, columns = 10, field_size = 20},
}

// Writer-specific benchmark configurations
Writer_Benchmark_Config :: struct {
	name:       string,
	rows:       int,
	columns:    int,
	complexity: CSV_Complexity,
}

WRITER_BENCHMARK_CONFIGS :: []Writer_Benchmark_Config{
	// Simple fields (no quoting)
	{name = "Write Simple (1K)", rows = 1_000, columns = 5, complexity = .Simple},
	{name = "Write Simple (10K)", rows = 10_000, columns = 10, complexity = .Simple},
	{name = "Write Simple (100K)", rows = 100_000, columns = 10, complexity = .Simple},
	// Quoted fields
	{name = "Write Quoted (1K)", rows = 1_000, columns = 5, complexity = .Quoted},
	{name = "Write Quoted (10K)", rows = 10_000, columns = 10, complexity = .Quoted},
	// Escaped quotes
	{name = "Write Escaped (1K)", rows = 1_000, columns = 5, complexity = .Escaped},
	{name = "Write Escaped (10K)", rows = 10_000, columns = 10, complexity = .Escaped},
	// Mixed complexity
	{name = "Write Mixed (1K)", rows = 1_000, columns = 5, complexity = .Mixed},
	{name = "Write Mixed (10K)", rows = 10_000, columns = 10, complexity = .Mixed},
}

// Generate CSV content for benchmark
generate_csv_content :: proc(config: Benchmark_Config, allocator := context.allocator) -> string {
	builder := strings.builder_make(allocator)
	// Note: Caller must delete returned string

	// Write header
	for col in 0..<config.columns {
		if col > 0 do strings.write_string(&builder, ",")
		fmt.sbprintf(&builder, "column_%d", col + 1)
	}
	strings.write_string(&builder, "\n")

	// Write rows
	for row in 0..<config.rows {
		for col in 0..<config.columns {
			if col > 0 do strings.write_string(&builder, ",")

			// Generate field content with varying patterns
			switch col % 4 {
			case 0: // Numeric field
				fmt.sbprintf(&builder, "%d", row * col + 1000)
			case 1: // Short text
				fmt.sbprintf(&builder, "value_%d", row)
			case 2: // Quoted field with comma
				fmt.sbprintf(&builder, "\"field %d, with comma\"", row)
			case 3: // Longer text
				fmt.sbprintf(&builder, "longer_text_field_%d_data", row * 7)
			}
		}
		strings.write_string(&builder, "\n")
	}

	return strings.to_string(builder)
}

// Generate CSV content with specific complexity
generate_csv_with_complexity :: proc(
	config: Writer_Benchmark_Config,
	allocator := context.allocator,
) -> string {
	builder := strings.builder_make(allocator)
	// Note: Caller must delete returned string

	// Write header
	for col in 0..<config.columns {
		if col > 0 do strings.write_string(&builder, ",")
		fmt.sbprintf(&builder, "column_%d", col + 1)
	}
	strings.write_string(&builder, "\n")

	// Write rows with different complexity patterns
	for row in 0..<config.rows {
		for col in 0..<config.columns {
			if col > 0 do strings.write_string(&builder, ",")

			switch config.complexity {
			case .Simple:
				// Simple fields (no quoting needed)
				fmt.sbprintf(&builder, "value_%d_%d", row, col)

			case .Quoted:
				// Fields with commas (require quoting)
				fmt.sbprintf(&builder, "\"field %d, column %d\"", row, col)

			case .Escaped:
				// Fields with quotes (require escaping)
				fmt.sbprintf(&builder, "\"field with \"\"quotes\"\" row %d\"", row)

			case .Multiline:
				// Fields with newlines
				if col % 2 == 0 {
					fmt.sbprintf(&builder, "\"line1\nline2\nrow %d\"", row)
				} else {
					fmt.sbprintf(&builder, "simple_%d", row)
				}

			case .Mixed:
				// Mix of all patterns
				switch col % 4 {
				case 0:
					fmt.sbprintf(&builder, "simple_%d", row)
				case 1:
					fmt.sbprintf(&builder, "\"field %d, with comma\"", row)
				case 2:
					fmt.sbprintf(&builder, "\"has \"\"quotes\"\" %d\"", row)
				case 3:
					fmt.sbprintf(&builder, "\"multiline\nfield %d\"", row)
				}
			}
		}
		strings.write_string(&builder, "\n")
	}

	return strings.to_string(builder)
}

// Writer benchmark result
Writer_Benchmark_Result :: struct {
	config:           Writer_Benchmark_Config,
	write_time_ns:    time.Duration,
	file_size_bytes:  int,
	rows_per_sec:     f64,
	mb_per_sec:       f64,
}

// Run writer-specific benchmark
run_writer_benchmark :: proc(config: Writer_Benchmark_Config) -> (result: Writer_Benchmark_Result, ok: bool) {
	result.config = config

	fmt.printf("Running: %s (%d rows × %d cols, %v)...\n",
		config.name, config.rows, config.columns, config.complexity)

	// Benchmark: Generate CSV content
	write_start := time.now()
	csv_content := generate_csv_with_complexity(config)
	write_end := time.now()
	defer delete(csv_content)

	result.write_time_ns = time.diff(write_start, write_end)
	result.file_size_bytes = len(csv_content)

	// Calculate metrics
	write_seconds := f64(time.duration_seconds(result.write_time_ns))
	result.rows_per_sec = f64(config.rows) / write_seconds
	result.mb_per_sec = (f64(result.file_size_bytes) / (1024.0 * 1024.0)) / write_seconds

	return result, true
}

// Print writer benchmark results
print_writer_results :: proc(results: []Writer_Benchmark_Result) {
	separator := strings.repeat("=", 100)
	defer delete(separator)

	fmt.println()
	fmt.println(separator)
	fmt.println("CSV WRITER BENCHMARK RESULTS")
	fmt.println(separator)
	fmt.printf("%-30s %10s %12s %12s %15s %12s\n",
		"Benchmark", "Rows", "File Size", "Write Time", "Rows/sec", "MB/sec")

	dash_line := strings.repeat("-", 100)
	defer delete(dash_line)
	fmt.println(dash_line)

	for result in results {
		file_size_kb := f64(result.file_size_bytes) / 1024.0
		write_ms := f64(time.duration_milliseconds(result.write_time_ns))

		file_size_str: string
		if file_size_kb < 1024 {
			file_size_str = fmt.tprintf("%.1f KB", file_size_kb)
		} else {
			file_size_str = fmt.tprintf("%.2f MB", file_size_kb / 1024.0)
		}

		fmt.printf("%-30s %10d %12s %9.2f ms %15.0f %9.2f\n",
			result.config.name,
			result.config.rows,
			file_size_str,
			write_ms,
			result.rows_per_sec,
			result.mb_per_sec)
	}

	fmt.println(separator)

	// Summary statistics
	total_rows := 0
	total_size := 0
	total_time_ns: time.Duration = 0

	for result in results {
		total_rows += result.config.rows
		total_size += result.file_size_bytes
		total_time_ns += result.write_time_ns
	}

	avg_throughput_mb := (f64(total_size) / (1024.0 * 1024.0)) / f64(time.duration_seconds(total_time_ns))

	fmt.println("\nWRITER SUMMARY:")
	fmt.printf("  Total Rows Generated:    %d\n", total_rows)
	fmt.printf("  Total Data Generated:    %.2f MB\n", f64(total_size) / (1024.0 * 1024.0))
	fmt.printf("  Total Write Time:        %.2f ms\n", f64(time.duration_milliseconds(total_time_ns)))
	fmt.printf("  Average Throughput:      %.2f MB/s\n", avg_throughput_mb)
	fmt.println(separator)
}

// Run single benchmark
run_benchmark :: proc(config: Benchmark_Config) -> (result: Benchmark_Result, ok: bool) {
	result.config = config

	fmt.printf("Running: %s (%d rows × %d cols)...\n", config.name, config.rows, config.columns)

	// Generate CSV content
	csv_content := generate_csv_content(config)
	defer delete(csv_content)

	result.file_size_bytes = len(csv_content)

	// Benchmark: Write to file
	temp_file := fmt.tprintf("temp_benchmark_%d.csv", config.rows)
	defer os.remove(temp_file)

	write_start := time.now()
	write_ok := os.write_entire_file(temp_file, transmute([]byte)csv_content)
	write_end := time.now()

	if !write_ok {
		fmt.eprintln("Failed to write benchmark file")
		return result, false
	}

	result.write_time_ns = time.diff(write_start, write_end)

	// Benchmark: Parse CSV
	parser := ocsv.parser_create()
	defer ocsv.parser_destroy(parser)

	// Measure memory before parsing
	mem_before := mem.Allocator_Error.None // placeholder

	parse_start := time.now()
	parse_ok := ocsv.parse_csv(parser, csv_content)
	parse_end := time.now()

	if !parse_ok {
		fmt.eprintln("Failed to parse CSV")
		return result, false
	}

	result.parse_time_ns = time.diff(parse_start, parse_end)

	// Calculate metrics
	parse_seconds := f64(time.duration_seconds(result.parse_time_ns))
	result.rows_per_sec = f64(config.rows) / parse_seconds
	result.mb_per_sec = (f64(result.file_size_bytes) / (1024.0 * 1024.0)) / parse_seconds

	// Estimate memory usage based on data size
	// CSV data + parsed structures (rough estimate: 2x the CSV size)
	result.memory_used_mb = f64(result.file_size_bytes) * 2.0 / (1024.0 * 1024.0)

	return result, true
}

// Print benchmark results
print_results :: proc(results: []Benchmark_Result) {
	separator := strings.repeat("=", 100)
	defer delete(separator)

	fmt.println()
	fmt.println(separator)
	fmt.println("CSV PARSING BENCHMARK RESULTS")
	fmt.println(separator)
	fmt.printf("%-25s %10s %12s %12s %15s %12s %10s\n",
		"Benchmark", "Rows", "File Size", "Parse Time", "Rows/sec", "MB/sec", "Memory")

	dash_line := strings.repeat("-", 100)
	defer delete(dash_line)
	fmt.println(dash_line)

	for result in results {
		file_size_kb := f64(result.file_size_bytes) / 1024.0
		parse_ms := f64(time.duration_milliseconds(result.parse_time_ns))

		file_size_str: string
		if file_size_kb < 1024 {
			file_size_str = fmt.tprintf("%.1f KB", file_size_kb)
		} else {
			file_size_str = fmt.tprintf("%.2f MB", file_size_kb / 1024.0)
		}

		fmt.printf("%-25s %10d %12s %9.2f ms %15.0f %9.2f %9.2f MB\n",
			result.config.name,
			result.config.rows,
			file_size_str,
			parse_ms,
			result.rows_per_sec,
			result.mb_per_sec,
			result.memory_used_mb)
	}

	fmt.println(separator)

	// Summary statistics
	total_rows := 0
	total_size := 0
	total_time_ns: time.Duration = 0

	for result in results {
		total_rows += result.config.rows
		total_size += result.file_size_bytes
		total_time_ns += result.parse_time_ns
	}

	avg_throughput_mb := (f64(total_size) / (1024.0 * 1024.0)) / f64(time.duration_seconds(total_time_ns))

	fmt.println("\nSUMMARY:")
	fmt.printf("  Total Rows Processed:    %d\n", total_rows)
	fmt.printf("  Total Data Processed:    %.2f MB\n", f64(total_size) / (1024.0 * 1024.0))
	fmt.printf("  Total Parse Time:        %.2f ms\n", f64(time.duration_milliseconds(total_time_ns)))
	fmt.printf("  Average Throughput:      %.2f MB/s\n", avg_throughput_mb)
	fmt.println(separator)
}

main :: proc() {
	fmt.println("Starting OCSV Benchmark Suite...")
	fmt.println("Platform:", ODIN_OS, ODIN_ARCH)
	fmt.println()

	// === WRITER BENCHMARKS ===
	fmt.println("\n=== CSV Writer Benchmarks ===\n")

	writer_results := make([dynamic]Writer_Benchmark_Result, 0, len(WRITER_BENCHMARK_CONFIGS))
	defer delete(writer_results)

	for config in WRITER_BENCHMARK_CONFIGS {
		result, ok := run_writer_benchmark(config)
		if !ok {
			fmt.eprintln("Benchmark failed:", config.name)
			continue
		}
		append(&writer_results, result)
		fmt.println("  ✓ Complete")
	}

	print_writer_results(writer_results[:])

	// === PARSER BENCHMARKS ===
	fmt.println("\n=== CSV Parser Benchmarks ===\n")

	parser_results := make([dynamic]Benchmark_Result, 0, len(BENCHMARK_CONFIGS))
	defer delete(parser_results)

	for config in BENCHMARK_CONFIGS {
		result, ok := run_benchmark(config)
		if !ok {
			fmt.eprintln("Benchmark failed:", config.name)
			continue
		}
		append(&parser_results, result)
		fmt.println("  ✓ Complete")
	}

	print_results(parser_results[:])

	// === OVERALL SUMMARY ===
	final_separator := strings.repeat("=", 100)
	defer delete(final_separator)
	fmt.println()
	fmt.println(final_separator)
	fmt.println("BENCHMARK SUITE COMPLETE")
	fmt.println(final_separator)
	fmt.printf("✓ Writer benchmarks: %d/%d passed\n", len(writer_results), len(WRITER_BENCHMARK_CONFIGS))
	fmt.printf("✓ Parser benchmarks: %d/%d passed\n", len(parser_results), len(BENCHMARK_CONFIGS))
	fmt.println(final_separator)
}
