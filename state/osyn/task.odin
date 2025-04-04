package osyn

import "core:log"
import "core:c/libc"
import "core:container/queue"
import vmem "core:mem/virtual"
import "core:sync"
import "core:thread"
import "core:time"
import "../callback"

// Modify Task to use Callback
Task :: union {
    Task_With_Param,
    Task_Without_Param,
}

Task_With_Param :: struct {
    callback: callback.Callback(rawptr, callback.Void),
    data: rawptr,
}

Task_Without_Param :: struct {
    callback: callback.Callback(callback.Void, callback.Void),
}

// Replace the existing make_task functions
make_task_with_param :: proc(cb: callback.Callback(rawptr, callback.Void), data: rawptr) -> Task {
    return Task_With_Param{
        callback = cb,
        data = data,
    }
}

make_task_without_param :: proc(cb: callback.Callback(callback.Void, callback.Void)) -> Task {
    return Task_Without_Param{
        callback = cb,
    }
}

make_task :: proc {
    make_task_with_param,
    make_task_without_param,
}

// Replace run_task
run_task :: proc(t: Task) {
    switch tsk in t {
    case Task_With_Param:
        callback.exec(tsk.callback, tsk.data)
    case Task_Without_Param:
        callback.exec(tsk.callback)
    }
}

suspend_task :: proc(w: ^Worker) -> i64 {
    id := time.tick_now()._nsec
    w.scheduler.buf[id] = libc.jmp_buf{}
    
    if libc.setjmp(&w.scheduler.buf[id]) == 1 {
        return id  // Return after resumption
    }
    
    // Record that we're pausing this task
    queue.push_back(&w.scheduler.queue, id)
    
    // Return to the worker runloop
    if w.scheduler.anchor != {} {
        libc.longjmp(&w.scheduler.anchor, 1)
    }
    
    return id
}

resume_task :: proc(worker: ^Worker, id: i64) -> bool {
    buf, ok := worker.scheduler.buf[id]
    if !ok {
        return false  // Context not found
    }
    
    // Mark for cleanup
    append(&worker.scheduler.cleanup, id)
    
    // Jump back to the suspended context
	libc.longjmp(&buf, 1)
}


// Cleanup when tasks are done
cleanup_task :: proc(t: Task) {
    switch tsk in t {
    case Task_With_Param:
        callback.free(tsk.callback)
    case Task_Without_Param:
        callback.free(tsk.callback)
    }
}

free_memory :: proc(ptr: rawptr) {
    free(ptr)
}

// Helper functions to create common tasks
go_unit :: proc(p: proc()) {
    callback_fn :: proc(capture: rawptr, _: callback.Void) -> callback.Void {
        fn := cast(^proc())capture
        fn^()
        return .Nil
    }
    
    cb := callback.make_with_cleanup(new_clone(p), callback_fn, free_memory)
    spawn_task(make_task_without_param(cb))
}

go_rawptr :: proc(p: proc(supply: rawptr), data: rawptr) {
    callback_fn :: proc(capture: rawptr, param: rawptr) -> callback.Void {
        fn := cast(^proc(rawptr))capture
        fn^(param)
        return .Nil
    }
    
    cb := callback.make_with_cleanup(new_clone(p), callback_fn, free_memory)
    spawn_task(make_task_with_param(cb, data))
}

go :: proc {
    go_unit,
    go_rawptr,
}

// These functions should be similarly updated for blocking tasks
gob_unit :: proc(p: proc()) {
    callback_fn :: proc(capture: rawptr, _: callback.Void) -> callback.Void {
        fn := cast(^proc())capture
        fn^()
        return .Nil
    }
    
    cb := callback.make_with_cleanup(new_clone(p), callback_fn, free_memory)
    spawn_blocking_task(make_task_without_param(cb))
}

gob_rawptr :: proc(p: proc(supply: rawptr), data: rawptr) {
    callback_fn :: proc(capture: rawptr, param: rawptr) -> callback.Void {
        fn := cast(^proc(rawptr))capture
        fn^(param)
        return .Nil
    }
    
    cb := callback.make_with_cleanup(new_clone(p), callback_fn, free_memory)
    spawn_blocking_task(make_task_with_param(cb, data))
}

gob :: proc {
    gob_unit,
    gob_rawptr,
}

// Original worker_runloop should be updated to include cleanup
worker_runloop :: proc(t: ^thread.Thread) {
    worker := get_worker()
    log.debug("awaiting barrier started")
    sync.barrier_wait(worker.barrier_ref)
    log.debug("runloop started")
    for {
        // wipe the arena every loop
        arena := worker.arena
        defer vmem.arena_free_all(&arena)
        tsk, exist := queue_pop(&worker.localq)
        if exist {
            log.debug("pulled from local queue, running")
            run_task(tsk)
            cleanup_task(tsk)  // Clean up after task execution
            continue
        }
        if worker.type == .Blocking {
            tsk, exist = gqueue_pop(&worker.coordinator.global_blockingq)
            if exist {
                log.debug("got item from global blocking channel")
                run_task(tsk)
                cleanup_task(tsk)  // Clean up after task execution
                continue
            }
        }
        // local queue seems to be empty at this point, take a look at the global channel
        tsk, exist = gqueue_pop(&worker.coordinator.globalq)
        if exist {
            log.debug("got item from global channel")
            run_task(tsk)
            cleanup_task(tsk)  // Clean up after task execution
            continue
        }

        // global queue seems to be empty too, enter stealing mode 
        // increment the stealing count
        scount := sync.atomic_load(&worker.coordinator.search_count)
        if scount < (worker.coordinator.worker_count / 2) {  // throttle stealing to half the total thread count
            sync.atomic_add(&worker.coordinator.search_count, 1) // register the stealing
            steal(worker) // start stealing
            sync.atomic_sub(&worker.coordinator.search_count, 1) // register the stealing
        }
    }
}