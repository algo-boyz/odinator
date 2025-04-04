package osyn_test

import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"
import "../../osyn"
import "../../callback"

// Basic task example
basic_task_example :: proc() {
    fmt.println("=== Basic Task Example ===")
    
    // Create a coordinator with configuration
    coord: osyn.Coordinator
    config := osyn.Config{
        worker_count = 2,
        blocking_worker_count = 1,
        use_main_thread = false,
    }
    
    // Define a simple task to be executed
    hello_task :: proc() {
        fmt.println("Hello from a task!")
    }
    
    // Create a callback for the initial task
    initial_task_cb :: proc(capture: rawptr, _: callback.Void) -> callback.Void {
        fmt.println("Initial task running")
        
        // Spawn 5 hello tasks
        for i in 0..<5 {
            osyn.go(hello_task)
        }
        
        // Give time for tasks to execute
        time.sleep(time.Second)
        fmt.println("All tasks should be done")
        return .Nil
    }
    
    // Create the initial task
    initial_cb := callback.exec_no_param(initial_task_cb)
    initial_task := osyn.make_task_without_param(initial_cb)
    
    // Initialize the system with the initial task
    osyn._init(&coord, config, initial_task)
}

// // Parameterized task example
// param_task_example :: proc() {
//     fmt.println("\n=== Parameterized Task Example ===")
    
//     // Create a coordinator with configuration
//     coord: osyn.Coordinator
//     config := osyn.Config{
//         worker_count = 2,
//         blocking_worker_count = 1,
//         use_main_thread = false,
//     }
    
//     // Define a task that uses a parameter
//     print_number :: proc(data: rawptr) {
//         number := cast(^int)data
//         fmt.printf("Task received number: %d\n", number^)
//     }
    
//     // Create a callback for the initial task
//     initial_task_cb :: proc(capture: rawptr, _: callback.Void) -> callback.Void {
//         fmt.println("Spawning tasks with parameters")
        
//         // Create 5 numbers and pass them to tasks
//         for i in 0..<5 {
//             num := new_clone(i)
//             osyn.go(print_number, num)
//         }
        
//         // Give time for tasks to execute
//         time.sleep(time.Second)
//         fmt.println("All parameterized tasks should be done")
//         return .Nil
//     }
    
//     // Create the initial task
//     initial_cb := callback.make(nil, initial_task_cb)
//     initial_task := osyn.make_task_without_param(initial_cb)
    
//     // Initialize the system with the initial task
//     osyn._init(&coord, config, initial_task)
// }

// // Blocking task example
// blocking_task_example :: proc() {
//     fmt.println("\n=== Blocking Task Example ===")
    
//     // Create a coordinator with configuration
//     coord: osyn.Coordinator
//     config := osyn.Config{
//         worker_count = 2,
//         blocking_worker_count = 1,
//         use_main_thread = false,
//     }
    
//     // Define a blocking task
//     blocking_work :: proc() {
//         fmt.println("Starting blocking work")
//         time.sleep(time.Second)
//         fmt.println("Blocking work completed")
//     }
    
//     // Define a non-blocking task
//     quick_work :: proc() {
//         fmt.println("Doing quick work")
//     }
    
//     // Create a callback for the initial task
//     initial_task_cb :: proc(capture: rawptr, _: callback.Void) -> callback.Void {
//         fmt.println("Spawning blocking and non-blocking tasks")
        
//         // Spawn a few blocking tasks
//         for i in 0..<3 {
//             osyn.gob(blocking_work)
//         }
        
//         // Spawn some quick tasks
//         for i in 0..<5 {
//             osyn.go(quick_work)
//         }
        
//         // Give time for tasks to execute
//         time.sleep(time.Second * 2)
//         fmt.println("All tasks should be done")
//         return .Nil
//     }
    
//     // Create the initial task
//     initial_cb := callback.make(nil, initial_task_cb)
//     initial_task := osyn.make_task_without_param(initial_cb)
    
//     // Initialize the system with the initial task
//     osyn._init(&coord, config, initial_task)
// }

// // Task suspension and resumption example
// suspension_example :: proc() {
//     fmt.println("\n=== Task Suspension Example ===")
    
//     // Create a coordinator with configuration
//     coord: osyn.Coordinator
//     config := osyn.Config{
//         worker_count = 2,
//         blocking_worker_count = 1,
//         use_main_thread = false,
//     }
    
//     // Define a task that suspends and gets resumed
//     suspended_task_id: i64
//     suspended_worker: ^osyn.Worker
    
//     suspending_task :: proc() {
//         fmt.println("Task starting and about to suspend")
//         worker := osyn.get_worker()
//         suspended_worker = worker
//         suspended_task_id = osyn.suspend_task(worker)
//         fmt.println("Task resumed after suspension!")
//     }
    
//     // Create a callback for the initial task
//     initial_task_cb :: proc(capture: rawptr, _: callback.Void) -> callback.Void {
//         fmt.println("Spawning a task that will suspend")
        
//         // Spawn a task that will suspend
//         osyn.go(suspending_task)
        
//         // Give time for task to execute and suspend
//         time.sleep(time.Millisecond * 500)
        
//         // Resume the suspended task
//         fmt.println("Resuming suspended task")
//         if suspended_worker != nil {
//             osyn.resume_task(suspended_worker, suspended_task_id)
//         }
        
//         // Give time for resumed task to complete
//         time.sleep(time.Millisecond * 500)
//         fmt.println("Suspension example completed")
//         return .Nil
//     }
    
//     // Create the initial task
//     initial_cb := callback.make(nil, initial_task_cb)
//     initial_task := osyn.make_task_without_param(initial_cb)
    
//     // Initialize the system with the initial task
//     osyn._init(&coord, config, initial_task)
// }

// // Complex example demonstrating producer-consumer pattern
// producer_consumer_example :: proc() {
//     fmt.println("\n=== Producer-Consumer Example ===")
    
//     // Create a coordinator with configuration
//     coord: osyn.Coordinator
//     config := osyn.Config{
//         worker_count = 3,
//         blocking_worker_count = 1,
//         use_main_thread = false,
//     }
    
//     // Create a shared queue and synchronization
//     Queue :: struct {
//         items:  [dynamic]int,
//         mutex:  sync.Mutex,
//         signal: sync.Condition,
//     }
    
//     // Setup the queue
//     queue := new(Queue)
//     queue.items = make([dynamic]int)
//     sync.mutex_init(&queue.mutex)
//     sync.condition_init(&queue.signal, &queue.mutex)
    
//     // Producer task
//     producer :: proc(data: rawptr) {
//         q := cast(^Queue)data
        
//         for i in 1..=10 {
//             sync.mutex_lock(&q.mutex)
//             fmt.printf("Producing item: %d\n", i)
//             append(&q.items, i)
//             sync.condition_signal(&q.signal)
//             sync.mutex_unlock(&q.mutex)
            
//             // Sleep a bit to simulate work
//             time.sleep(time.Millisecond * 200)
//         }
        
//         // Signal we're done producing
//         sync.mutex_lock(&q.mutex)
//         append(&q.items, -1)  // -1 is our sentinel value
//         sync.condition_signal(&q.signal)
//         sync.mutex_unlock(&q.mutex)
        
//         fmt.println("Producer finished")
//     }
    
//     // Consumer task
//     consumer :: proc(data: rawptr) {
//         q := cast(^Queue)data
        
//         for {
//             sync.mutex_lock(&q.mutex)
            
//             // Wait until there's something in the queue
//             for len(q.items) == 0 {
//                 sync.condition_wait(&q.signal)
//             }
            
//             // Get the item
//             item := q.items[0]
//             q.items = q.items[1:]
            
//             sync.mutex_unlock(&q.mutex)
            
//             // Check if we're done
//             if item == -1 {
//                 fmt.println("Consumer received end signal")
//                 break
//             }
            
//             fmt.printf("Consumed item: %d\n", item)
            
//             // Process the item (simulate work)
//             time.sleep(time.Millisecond * 300)
//         }
        
//         fmt.println("Consumer finished")
//     }
    
//     // Create a callback for the initial task
//     initial_task_cb :: proc(capture: rawptr, _: callback.Void) -> callback.Void {
//         q := new(Queue)
//         q.items = make([dynamic]int)
//         sync.mutex_init(&q.mutex)
//         sync.condition_init(&q.signal, &q.mutex)
        
//         fmt.println("Starting producer and consumer tasks")
        
//         // Start producer (blocking task)
//         osyn.gob(producer, q)
        
//         // Start consumers (normal tasks)
//         for i in 0..<2 {
//             osyn.go(consumer, q)
//         }
        
//         // Give time for tasks to complete
//         time.sleep(time.Second * 5)
//         fmt.println("Producer-consumer example completed")
        
//         // Cleanup
//         delete(q.items)
//         free(q)
        
//         return .Nil
//     }
    
//     // Create the initial task
//     initial_cb := callback.make(nil, initial_task_cb)
//     initial_task := osyn.make_task_without_param(initial_cb)
    
//     // Initialize the system with the initial task
//     osyn._init(&coord, config, initial_task)
// }

// Run all examples
main :: proc() {
    fmt.println("Running osyn test examples")
    
    // Run basic example
    basic_task_example()
    
    // Run parameterized task example
    // param_task_example()
    
    // // Run blocking task example
    // blocking_task_example()
    
    // // Run suspension example
    // suspension_example()
    
    // // Run producer-consumer example
    // producer_consumer_example()
    
    fmt.println("\nAll examples completed")
}