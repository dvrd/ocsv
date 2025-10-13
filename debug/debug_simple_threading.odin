package main

import "core:fmt"
import "core:thread"

main :: proc() {
    fmt.println("=== Testing Simple Threading ===\n")

    // Simple data structure
    Worker_Data :: struct {
        id:         int,
        result_ptr: ^int,
    }

    // Worker function
    worker :: proc(data: Worker_Data) {
        fmt.printfln("[Thread %d] Started", data.id)
        data.result_ptr^ = data.id * 10
        fmt.printfln("[Thread %d] Set result to %d", data.id, data.result_ptr^)
    }

    // Pre-allocate results
    results := make([]int, 2)
    defer delete(results)

    fmt.println("Initial results:", results)

    // Create worker data
    worker_data := make([]Worker_Data, 2, context.temp_allocator)
    worker_data[0] = Worker_Data{id = 0, result_ptr = &results[0]}
    worker_data[1] = Worker_Data{id = 1, result_ptr = &results[1]}

    // Start threads
    threads := make([dynamic]^thread.Thread, 0, 2, context.temp_allocator)
    defer {
        for t in threads {
            if t != nil do thread.destroy(t)
        }
    }

    fmt.println("\nStarting threads...")
    for wd in worker_data {
        t := thread.create_and_start_with_poly_data(wd, worker)
        if t == nil {
            fmt.printfln("ERROR: Failed to create thread for worker %d", wd.id)
        } else {
            fmt.printfln("Created thread for worker %d", wd.id)
        }
        append(&threads, t)
    }

    fmt.println("\nWaiting for threads...")
    for t, i in threads {
        if t != nil {
            fmt.printfln("Joining thread %d...", i)
            thread.join(t)
            fmt.printfln("Thread %d joined", i)
        } else {
            fmt.printfln("Thread %d was nil!", i)
        }
    }

    fmt.println("\nFinal results:", results)
    fmt.printfln("Expected: [0, 10]")
}
