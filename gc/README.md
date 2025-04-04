# Garbage Collector
This is a wrapper around libgc, providing garbage collection for Odin.

## Prerequisites

For macos install (Boehm GC):
```bash
brew install bdw-gc
```

## How to use 

Multi threaded:
```odin
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
```