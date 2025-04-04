package main

import "core:fmt"
import "core:sync"
import "core:time"
import "../../osyn"
import "../../callback"

// Task scheduler that allows scheduling tasks to run after a delay

Scheduler :: struct {
    tasks:       map[i64]Task_Info,
    mutex:       sync.Mutex,
    running:     bool,
    coordinator: ^osyn.Coordinator,
}

Task_Info :: struct {
    id:          i64,
    execute_at:  time.Time,
    callback:    osyn.Task,
    repeat_ms:   i64,  // If > 0, task repeats every repeat_ms milliseconds
}

new_scheduler :: proc() -> ^Scheduler {
    scheduler := new(Scheduler)
    scheduler.tasks = make(map[i64]Task_Info)
    sync.mutex_init(&scheduler.mutex)
    return scheduler
}

// Schedule a task to run after a delay
schedule_task :: proc(scheduler: ^Scheduler, task: osyn.Task, delay_ms: i64, repeat_ms: i64 = 0) -> i64 {
    sync.mutex_lock(&scheduler.mutex)
    defer sync.mutex_unlock(&scheduler.mutex)
    
    task_id := time.tick_now()._nsec
    now := time.now()
    execute_at := time.add_duration(now, time.Duration(delay_ms * 1000 * 1000))
    
    task_info := Task_Info{
        id = task_id,
        execute_at = execute_at,
        callback = task,
        repeat_ms = repeat_ms,
    }
    
    scheduler.tasks[task_id] = task_info
    return task_id
}

// Cancel a scheduled task
cancel_task :: proc(scheduler: ^Scheduler, task_id: i64) -> bool {
    sync.mutex_lock(&scheduler.mutex)
    defer sync.mutex_unlock(&scheduler.mutex)
    
    _, exists := scheduler.tasks[task_id]
    if exists {
        delete_key(&scheduler.tasks, task_id)
        return true
    }
    return false
}

// Scheduler runner that periodically checks for tasks to run
scheduler_runner :: proc(scheduler_ptr: rawptr) {
    scheduler := cast(^Scheduler)scheduler_ptr
    
    fmt.println("Scheduler runner started")
    
    for scheduler.running {
        // Sleep for a short time
        time.sleep(time.Millisecond * 50)
        
        sync.mutex_lock(&scheduler.mutex)
        
        now := time.now()
        tasks_to_run: [dynamic]Task_Info
        
        // Find tasks that need to be executed
        for task_id, task_info in scheduler.tasks {
            if time.diff(now, task_info.execute_at) >= 0 {
                append(&tasks_to_run, task_info)
                
                // If task repeats, update its next execution time
                if task_info.repeat_ms > 0 {
                    next_time := time.add_duration(task_info.execute_at, time.Duration(task_info.repeat_ms * 1000 * 1000))
                    
                    // If we missed several executions, find the next valid time
                    for time.diff(now, next_time) > 0 {
                        next_time = time.add_duration(next_time, time.Duration(task_info.repeat_ms * 1000 * 1000))
                    }
                    
                    task_info.execute_at = next_time
                    scheduler.tasks[task_id] = task_info
                } else {
                    // One-time task, remove it
                    delete_key(&scheduler.tasks, task_id)
                }
            }
        }
        
        sync.mutex_unlock(&scheduler.mutex)
        
        // Execute tasks outside the lock
        for task in tasks_to_run {
            osyn.spawn_task(task.callback)
        }
        
        delete(tasks_to_run)
    }
    
    fmt.println("Scheduler runner stopped")
}

// Start the scheduler
start_scheduler :: proc(scheduler: ^Scheduler, coordinator: ^osyn.Coordinator) {
    if scheduler.running {
        return
    }
    
    scheduler.running = true
    scheduler.coordinator = coordinator
    
    runner_task :: proc(data: rawptr) {
        scheduler := cast(^Scheduler)data
        scheduler_runner(scheduler)
    }
    
    // Start the scheduler runner in a blocking task
    osyn.gob(runner_task, scheduler)
}

// Stop the scheduler
stop_scheduler :: proc(scheduler: ^Scheduler) {
    sync.mutex_lock(&scheduler.mutex)
    scheduler.running = false
    clear(&scheduler.tasks)
    sync.mutex_unlock(&scheduler.mutex)
}

// Example tasks
print_message :: proc(msg_ptr: rawptr) {
    msg := cast(^string)msg_ptr
    fmt.println(msg^)
}

// Main example
main :: proc() {
    // Create a coordinator with configuration
    coord: osyn.Coordinator
    config := osyn.Config{
        worker_count = 2,
        blocking_worker_count = 1,
        use_main_thread = true,  // Use main thread as a worker
    }
    
    // Create initial task
    initial_task_cb :: proc(capture: rawptr, _: callback.Void) -> callback.Void {
        fmt.println("Starting scheduler example")
        
        // Create a scheduler
        scheduler := new_scheduler()
        defer {
            stop_scheduler(scheduler)
            delete(scheduler.tasks)
            free(scheduler)
        }
        
        // Start the scheduler
        start_scheduler(scheduler, cast(^osyn.Coordinator)capture)
        
        // Schedule some tasks
        msg1 := new_clone(string("Task 1: Executes after 1 second"))
        callback1 := callback.make_with_cleanup(msg1, proc(capture: rawptr, param: rawptr) -> callback.Void {
            print_message(param)
            return .Nil
        }, osyn.free_memory)
        task1 := osyn.make_task_with_param(callback1, msg1)
        id1 := schedule_task(scheduler, task1, 1000)
        
        msg2 := new_clone(string("Task 2: Repeats every 500ms"))
        callback2 := callback.make_with_cleanup(msg2, proc(capture: rawptr, param: rawptr) -> callback.Void {
            print_message(param)
            return .Nil
        }, osyn.free_memory)
        task2 := osyn.make_task_with_param(callback2, msg2)
        id2 := schedule_task(scheduler, task2, 500, 500)
        
        // Let tasks run for a while
        time.sleep(time.Second * 3)
        
        // Cancel the repeating task
        fmt.println("Cancelling repeating task")
        cancel_task(scheduler, id2)
        
        // Schedule one more task
        msg3 := new_clone(string("Task 3: Final task after cancellation"))
        callback3 := callback.make_with_cleanup(msg3, proc(capture: rawptr, param: rawptr) -> callback.Void {
            print_message(param)
            return .Nil
        }, osyn.free_memory)
        task3 := osyn.make_task_with_param(callback3, msg3)
        id3 := schedule_task(scheduler, task3, 500)
        
        // Wait for the final task
        time.sleep(time.Second * 1)
        
        fmt.println("Scheduler example completed")
        return .Nil
    }
    
    // Create the initial task with the coordinator as parameter
    initial_cb := callback.make(&coord, initial_task_cb)
    initial_task := osyn.make_task_with_param(initial_cb, &coord)
    
    // Initialize the system with the initial task
    osyn._init(&coord, config, initial_task)
}