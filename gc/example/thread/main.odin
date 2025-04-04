package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:sync"
import "core:thread"
import "core:time"
import "../../"

TaskData :: struct {
    job_id:  int,
    task_wg: ^sync.Wait_Group,
}

// Procedure executed by each worker thread in the pool
worker_task :: proc(t: thread.Task) {
    // CRITICAL: Each thread using the GC MUST register itself
    ok := gc.register_thread()
    if !ok {
        fmt.eprintf("Error: Failed to register thread for GC in task %d\n", t.user_index)
        // Decide how to handle this - maybe exit thread or skip task?
        // NOTE: production would need robust handling
    }
    defer gc.unregister_thread()

    data := cast(^TaskData)t.data
    worker_id := t.user_index // Pool assigns unique index

    fmt.printf("[Worker %d / Job %d] Started.\n", worker_id, data.job_id)

    // Create a dedicated memory region for this specific job/task
    task_region := gc.create_region()
    // IMPORTANT: Ensure the region is destroyed when the task finishes.
    // This will free all memory allocated within this region using region_alloc.
    defer gc.destroy_region(task_region)
    fmt.printf("[Worker %d / Job %d] Created region %p.\n", worker_id, data.job_id, task_region)

    alloc_size := (data.job_id % 5 + 1) * 256 // Allocate some data based on job_id
    work_buffer: rawptr
    work_buffer = gc.region_alloc(task_region, alloc_size)

    if work_buffer == nil {
        fmt.eprintf("[Worker %d / Job %d] Error: Failed to allocate %d bytes in region %p.\n",
            worker_id, data.job_id, alloc_size, task_region)
        // Can't proceed with work if allocation failed
    } else {
        fmt.printf("[Worker %d / Job %d] Allocated %d bytes at %p within region %p.\n",
            worker_id, data.job_id, alloc_size, work_buffer, task_region)

        // Do some work with the allocated buffer
        mem.set(work_buffer, byte(data.job_id % 255), alloc_size) // Fill buffer
        time.sleep(time.Duration(50 + data.job_id * 15) * time.Millisecond) // Simulate work

        fmt.printf("[Worker %d / Job %d] Processing complete.\n", worker_id, data.job_id)
    }
    fmt.printf("[Worker %d / Job %d] Finishing. Region %p will be destroyed.\n", worker_id, data.job_id, task_region)
    sync.wait_group_done(data.task_wg)
}


main :: proc() {
    gc_config := gc.DEFAULT_CONFIG
    gc_config.log_level = .Info
    gc_context := gc.initialize(gc_config)

    // NOTE: Can replace the global context with the GC-aware context so
    // `new`, `make`, etc. would use the GC allocator by default
    context = gc_context
    fmt.println("GC Initialized with global context.")
    num_jobs := 15
    num_workers := os.processor_core_count() - 1
    task_wg: sync.Wait_Group

    // Initialize the pool, using the GC allocator context
    pool: thread.Pool
    thread.pool_init(&pool, allocator = context.allocator, thread_count = num_workers)
    defer thread.pool_destroy(&pool)
    fmt.printf("Thread pool initialized with %d workers.\n", num_workers)

    fmt.printf("Adding %d jobs to the thread pool...\n", num_jobs)
    sync.wait_group_add(&task_wg, num_jobs)

    for i in 0 ..< num_jobs {
        // Allocate TaskData - using `new` which uses the GC allocator
        // This TaskData struct itself is managed by the GC now.
        // It will be collected eventually after the task finishes and no longer references it.
        data := new(TaskData)
        data^ = TaskData {
            job_id = i + 1, // Job IDs 1 to num_jobs
            task_wg = &task_wg,
        }
        thread.pool_add_task(
            pool = &pool,
            allocator = context.allocator,
            procedure = worker_task,
            data = rawptr(data),
            user_index = i + 1,
        )
    }
    gc.sprintf("%d jobs added.\n", num_jobs)

    gc.sprintln("Starting thread pool workers...")
    thread.pool_start(&pool)

    gc.sprintln("Main thread waiting for all jobs to complete...")
    sync.wait_group_wait(&task_wg) // Block until all tasks called wait_group_done
    gc.sprintln("All jobs completed.")
    gc.sprintln("Requesting final garbage collection...")
    gc.collect() // trigger a collection to see final state
    stats := gc.get_stats()
    fmt.printf("Final GC Stats: HeapSize=%d, FreeBytes=%d, TotalAllocated=%d\n",
        stats.heap_size, stats.free_bytes, stats.total_allocated)
    gc.sprintln("Finishing thread pool (joins threads)...")
    thread.pool_finish(&pool)
    gc.sprintln("All good!")
}