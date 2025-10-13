package main

import "core:fmt"
import "core:strings"
import "core:thread"
import "core:sync"
import ocsv "../src"

main :: proc() {
    fmt.println("=== Testing Results Array Collection ===\n")

    // Create test CSV
    builder := strings.builder_make(0, 15 * 1024 * 1024)
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "id,name\n")
    for i in 0..<150000 {
        strings.write_string(&builder, fmt.tprintf("%d,Name%d\n", i, i))
    }

    csv_data := strings.to_string(builder)
    fmt.printfln("CSV data: %.2f MB\n", f64(len(csv_data)) / (1024.0 * 1024.0))

    // Manually test threading like parse_parallel does
    chunks := ocsv.find_safe_chunks(csv_data, 2)
    defer delete(chunks)

    fmt.printfln("Created %d chunks", len(chunks))
    for chunk, i in chunks {
        fmt.printfln("  Chunk %d: %d bytes", i, len(chunk))
    }
    fmt.println()

    // Create results array and mutex exactly like parse_parallel
    Parse_Worker_Result :: struct {
        parser:      ^ocsv.Parser,
        chunk_index: int,
        success:     bool,
    }

    Parse_Job :: struct {
        data:          string,
        chunk_index:   int,
        results:       ^[dynamic]Parse_Worker_Result,
        results_mutex: ^sync.Mutex,
    }

    worker_proc :: proc(job: Parse_Job) {
        fmt.printfln("[Thread %d] Started", job.chunk_index)

        parser := ocsv.parser_create()
        ok := ocsv.parse_csv(parser, job.data)

        fmt.printfln("[Thread %d] Parsed %d rows, success: %v",
            job.chunk_index, len(parser.all_rows), ok)

        result := Parse_Worker_Result{
            parser      = parser,
            chunk_index = job.chunk_index,
            success     = ok,
        }

        sync.mutex_lock(job.results_mutex)
        fmt.printfln("[Thread %d] Adding result to array (current len: %d)",
            job.chunk_index, len(job.results))
        append(job.results, result)
        fmt.printfln("[Thread %d] Result added (new len: %d)",
            job.chunk_index, len(job.results))
        sync.mutex_unlock(job.results_mutex)

        fmt.printfln("[Thread %d] Finished", job.chunk_index)
    }

    results := make([dynamic]Parse_Worker_Result, 0, len(chunks))
    results_mutex: sync.Mutex

    threads := make([dynamic]^thread.Thread, 0, len(chunks), context.temp_allocator)
    defer {
        for t in threads {
            if t != nil do thread.destroy(t)
        }
    }

    fmt.println("Starting threads...")
    for chunk, i in chunks {
        job := Parse_Job{
            data          = chunk,
            chunk_index   = i,
            results       = &results,
            results_mutex = &results_mutex,
        }

        t := thread.create_and_start_with_poly_data(job, worker_proc)
        append(&threads, t)
    }

    fmt.println("Waiting for threads to complete...")
    for t in threads {
        if t != nil do thread.join(t)
    }

    fmt.println("\n=== Results ===")
    fmt.printfln("Results array length: %d (expected: %d)", len(results), len(chunks))

    total_rows := 0
    for result, i in results {
        fmt.printfln("Result %d: chunk_index=%d, rows=%d, success=%v",
            i, result.chunk_index, len(result.parser.all_rows), result.success)
        total_rows += len(result.parser.all_rows)
    }

    fmt.printfln("\nTotal rows across all results: %d (expected: 150001)", total_rows)

    // Cleanup
    for result in results {
        if result.parser != nil {
            ocsv.parser_destroy(result.parser)
        }
    }
    delete(results)
}
