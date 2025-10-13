package ocsv

// Parallel CSV parsing for multi-threaded performance
// Provides speedup on very large files (>10 MB) by processing chunks concurrently

import "core:thread"
import "core:sync"
import "core:os"
import "core:mem"
import "core:strings"
import "base:runtime"

// Parse_Worker_Result represents the result from a worker thread
Parse_Worker_Result :: struct {
    parser:      ^Parser,
    chunk_index: int,
    success:     bool,
}

// Parallel_Config contains configuration for parallel parsing
Parallel_Config :: struct {
    num_threads:  int,  // Number of worker threads (0 = auto-detect)
    min_file_size: int,  // Minimum file size for parallel (0 = 10 MB default)
}

// default_parallel_config returns sensible defaults for parallel parsing
default_parallel_config :: proc() -> Parallel_Config {
    return Parallel_Config{
        num_threads    = 0,         // Auto-detect (use intelligent heuristic)
        min_file_size  = 2 * 1024 * 1024,  // 2 MB minimum (optimized threshold)
    }
}

// parse_parallel parses CSV data in parallel using multiple threads
// Best for very large files (>10 MB). Automatically falls back to sequential for smaller files.
// Returns a new parser with merged results from all threads
parse_parallel :: proc(data: string, config: Parallel_Config = {}, allocator := context.allocator) -> (^Parser, bool) {
    // Determine minimum file size
    min_size := config.min_file_size
    if min_size <= 0 {
        min_size = 2 * 1024 * 1024 // 2 MB default (optimized based on benchmarks)
    }

    // Determine number of threads using intelligent heuristic
    num_threads := config.num_threads
    if num_threads <= 0 {
        num_threads = get_optimal_thread_count(len(data))
    }

    // Check file size threshold - use sequential for small files
    if len(data) < min_size || num_threads <= 1 {
        parser := parser_create()
        ok := parse_csv(parser, data)
        return parser, ok
    }

    // Ensure at least 512 KB per thread to avoid excessive overhead
    min_chunk_size := 512 * 1024 // 512 KB minimum per thread
    max_threads := len(data) / min_chunk_size
    if max_threads < num_threads {
        num_threads = max(max_threads, 1)
    }

    // Final check: if only 1 thread needed, use sequential
    if num_threads <= 1 {
        parser := parser_create()
        ok := parse_csv(parser, data)
        return parser, ok
    }

    // Find safe chunk boundaries (on row boundaries)
    chunks := find_safe_chunks(data, num_threads)
    if len(chunks) == 0 {
        // Failed to split, use sequential
        parser := parser_create()
        ok := parse_csv(parser, data)
        return parser, ok
    }

    // Verify all data is covered
    total_chunk_size := 0
    for chunk in chunks {
        total_chunk_size += len(chunk)
    }
    if total_chunk_size != len(data) {
        // Chunks don't cover all data, fall back to sequential
        parser := parser_create()
        ok := parse_csv(parser, data)
        return parser, ok
    }

    // Pre-allocate results array with correct size
    results := make([]Parse_Worker_Result, len(chunks))

    threads := make([dynamic]^thread.Thread, 0, len(chunks), context.temp_allocator)

    defer {
        for t in threads {
            if t != nil do thread.destroy(t)
        }
    }

    // Worker proc that writes directly to results array by index
    Worker_Data :: struct {
        chunk:       string,
        index:       int,
        results_ptr: ^Parse_Worker_Result,
    }

    worker :: proc(data: Worker_Data) {
        context = runtime.default_context()  // Essential for proper memory allocation in threads

        parser := parser_create()
        ok := parse_csv(parser, data.chunk)

        // Write result directly to pre-allocated slot (thread-safe since each index is unique)
        data.results_ptr^ = Parse_Worker_Result{
            parser      = parser,
            chunk_index = data.index,
            success     = ok,
        }
    }

    // Start worker threads
    worker_data := make([]Worker_Data, len(chunks), context.temp_allocator)
    for chunk, i in chunks {
        worker_data[i] = Worker_Data{
            chunk       = chunk,
            index       = i,
            results_ptr = &results[i],
        }

        t := thread.create_and_start_with_poly_data(worker_data[i], worker)
        if t == nil {
            // Thread creation failed, fall back to sequential
            for existing_t in threads {
                if existing_t != nil do thread.join(existing_t)
            }
            delete(results)
            parser := parser_create()
            ok := parse_csv(parser, data)
            return parser, ok
        }
        append(&threads, t)
    }

    // Wait for all threads to complete
    for t in threads {
        if t != nil do thread.join(t)
    }

    // Check if all chunks parsed successfully
    all_success := true
    for result in results {
        // Check if parser is nil (thread didn't write result) or parse failed
        if result.parser == nil || !result.success {
            all_success = false
            break
        }
    }

    // Merge results into final parser
    final_parser := merge_worker_results(results[:], allocator)

    // Clean up results array
    delete(results)

    return final_parser, all_success && final_parser != nil
}

// Chunk represents a slice of the input data
Chunk :: string

// find_safe_chunks splits data into chunks at row boundaries
// Ensures no rows are split across chunks by tracking quote state from the beginning
find_safe_chunks :: proc(data: string, num_chunks: int) -> []Chunk {
    if num_chunks <= 1 || len(data) == 0 {
        return nil
    }

    chunks := make([dynamic]Chunk, 0, num_chunks, context.temp_allocator)
    approx_chunk_size := len(data) / num_chunks

    start := 0

    for i in 0..<(num_chunks - 1) {
        // Start looking for a newline after the approximate chunk size
        search_start := start + approx_chunk_size
        if search_start >= len(data) {
            break
        }

        // Find the next newline to ensure we split on row boundaries
        // IMPORTANT: Must track quote state from the START of this chunk
        boundary := find_row_boundary_from_start(data, start, search_start)
        if boundary == -1 || boundary >= len(data) {
            // No more boundaries found, add remaining data to last chunk
            break
        }

        // Add chunk
        chunk := data[start:boundary]
        append(&chunks, chunk)
        start = boundary
    }

    // Add final chunk (remaining data)
    if start < len(data) {
        chunk := data[start:]
        append(&chunks, chunk)
    }

    // Convert to slice
    result := make([]Chunk, len(chunks))
    copy(result, chunks[:])
    return result
}

// find_row_boundary_from_start finds the next row boundary after search_start
// but tracks quote state from chunk_start to ensure correctness
// Returns the position after the newline, or -1 if not found
find_row_boundary_from_start :: proc(data: string, chunk_start: int, search_start: int) -> int {
    if search_start >= len(data) {
        return -1
    }

    // Track quote state from the beginning of this chunk
    in_quotes := false

    // First, determine quote state up to search_start
    i := chunk_start
    for i < search_start {
        c := data[i]
        if c == '"' {
            // Check for escaped quote (two quotes in a row)
            if i + 1 < len(data) && data[i + 1] == '"' {
                i += 2 // Skip both quotes (BUG FIX: was i += 1 causing double increment)
                continue
            }
            in_quotes = !in_quotes
        }
        i += 1
    }

    // Now search for newline from search_start, continuing quote state tracking
    i = search_start
    for i < len(data) {
        c := data[i]

        // Track quote state
        if c == '"' {
            // Check for escaped quote
            if i + 1 < len(data) && data[i + 1] == '"' {
                i += 2 // Skip both quotes (BUG FIX: was i += 1 causing double increment)
                continue
            }
            in_quotes = !in_quotes
            i += 1
            continue
        }

        // Only consider newlines outside of quotes
        if !in_quotes {
            if c == '\n' {
                // Found newline, return position after it
                return i + 1
            } else if c == '\r' && i + 1 < len(data) && data[i + 1] == '\n' {
                // Found CRLF, return position after it
                return i + 2
            }
        }

        i += 1
    }

    return -1
}

// find_next_row_boundary finds the next row boundary after the given position
// Returns the position after the newline, or -1 if not found
// Note: This assumes we're starting from a valid position (not mid-quoted-field)
find_next_row_boundary :: proc(data: string, start: int) -> int {
    if start >= len(data) {
        return -1
    }

    // Look for newline, but skip quoted regions
    in_quotes := false

    i := start
    for i < len(data) {
        c := data[i]

        // Track quote state
        if c == '"' {
            // Check for escaped quote
            if i + 1 < len(data) && data[i + 1] == '"' {
                i += 2 // Skip both quotes (BUG FIX: was i += 1 causing double increment)
                continue
            }
            in_quotes = !in_quotes
            i += 1
            continue
        }

        // Only consider newlines outside of quotes
        if !in_quotes {
            if c == '\n' {
                // Found newline, return position after it
                return i + 1
            } else if c == '\r' && i + 1 < len(data) && data[i + 1] == '\n' {
                // Found CRLF, return position after it
                return i + 2
            }
        }

        i += 1
    }

    return -1
}

// merge_worker_results merges results from multiple parsers into a single parser
merge_worker_results :: proc(results: []Parse_Worker_Result, allocator := context.allocator) -> ^Parser {
    if len(results) == 0 {
        return nil
    }

    // Create final parser
    final := parser_create()

    // Count total rows
    total_rows := 0
    for result in results {
        if result.parser != nil {
            total_rows += len(result.parser.all_rows)
        }
    }

    // Pre-allocate space for all rows
    if cap(final.all_rows) < total_rows {
        reserve(&final.all_rows, total_rows)
    }

    // Sort results by chunk_index to maintain order
    // Simple bubble sort for small number of chunks
    sorted_results := make([]Parse_Worker_Result, len(results), context.temp_allocator)
    copy(sorted_results, results)

    for i in 0..<len(sorted_results) {
        for j in 0..<len(sorted_results)-i-1 {
            if sorted_results[j].chunk_index > sorted_results[j+1].chunk_index {
                sorted_results[j], sorted_results[j+1] = sorted_results[j+1], sorted_results[j]
            }
        }
    }

    // Merge all rows from all parsers in order
    for result in sorted_results {
        if result.parser == nil do continue

        for row in result.parser.all_rows {
            // Clone the row for the final parser
            cloned_row := make([]string, len(row), allocator)
            for field, i in row {
                cloned_row[i] = strings.clone(field, allocator)
            }
            append(&final.all_rows, cloned_row)
        }

        // Clean up worker parser
        parser_destroy(result.parser)
    }

    return final
}

// get_optimal_thread_count returns the optimal number of threads for a given data size
// Uses intelligent heuristics based on file size and available cores
get_optimal_thread_count :: proc(data_size: int) -> int {
    cpu_count := os.processor_core_count()
    if cpu_count <= 0 do cpu_count = 4

    // Heuristic: Use parallel only when benefit outweighs overhead
    // Based on benchmarking:
    // - <2 MB:  Sequential is faster (overhead dominates)
    // - 2-5 MB: 2 threads optimal (minimal overhead, some speedup)
    // - 5-10 MB: 4 threads optimal (good speedup, manageable overhead)
    // - >10 MB: Scale with CPU count (up to 8 threads for best results)

    mb := data_size / (1024 * 1024)

    // Apply heuristic based on file size
    if mb < 2 {
        return 1  // Too small, overhead dominates
    } else if mb < 5 {
        return min(2, cpu_count)  // Minimal parallelism
    } else if mb < 10 {
        return min(4, cpu_count)  // Medium parallelism
    } else if mb < 50 {
        return min(max(cpu_count / 2, 4), 8)  // Scale with file size
    } else {
        return min(cpu_count, 8)  // Full parallelism (cap at 8 for diminishing returns)
    }
}
