package main

import "core:sync"
import "core:mem"
import "core:thread"
import "core:fmt"
import "core:time"
import "core:math/rand"
import "../"

// Demo thread data
Thread_Data :: struct {
    list: ^cdl.Concurrent_Array_List(int),
    thread_id: int,
    operation_count: int,
}

// Producer thread - adds numbers to the list
producer_worker :: proc(data: rawptr) {
    thread_data := cast(^Thread_Data)data
    
    for i in 0..<thread_data.operation_count {
        value := thread_data.thread_id * 1000 + i
        
        // Try to push, if it fails due to lock contention, try again
        for {
            success, err := cdl.try_push(thread_data.list, value)
            if success {
                if err == nil {
                    fmt.printf("Producer %d: Added %d\n", thread_data.thread_id, value)
                    break
                } else {
                    fmt.printf("Producer %d: Failed to add %d (memory error)\n", thread_data.thread_id, value)
                    break
                }
            }
            // Brief pause before retrying
            time.sleep(time.Millisecond)
        }
        
        // Random delay to simulate work
        time.sleep(time.Duration(rand.int_max(10)) * time.Millisecond)
    }
    
    fmt.printf("Producer %d: Finished\n", thread_data.thread_id)
}

// Consumer thread - removes numbers from the list
consumer_worker :: proc(data: rawptr) {
    thread_data := cast(^Thread_Data)data
    consumed := 0
    
    for consumed < thread_data.operation_count {
        if value, ok := cdl.pop_or_null(thread_data.list); ok {
            fmt.printf("Consumer %d: Removed %d\n", thread_data.thread_id, value)
            consumed += 1
        } else {
            // No items available, brief pause
            time.sleep(time.Millisecond * 5)
        }
    }
    
    fmt.printf("Consumer %d: Finished\n", thread_data.thread_id)
}

// Reader thread - reads random items from the list
reader_worker :: proc(data: rawptr) {
    thread_data := cast(^Thread_Data)data
    
    for i in 0..<thread_data.operation_count {
        count := cdl.count(thread_data.list)
        if count > 0 {
            index := rand.int_max(count)
            if value, ok := cdl.try_get(thread_data.list, index); ok {
                fmt.printf("Reader %d: Read value %d at index %d\n", thread_data.thread_id, value, index)
            } else {
                fmt.printf("Reader %d: Failed to read at index %d (lock contention)\n", thread_data.thread_id, index)
            }
        } else {
            fmt.printf("Reader %d: List is empty\n", thread_data.thread_id)
        }
        
        time.sleep(time.Duration(rand.int_max(20)) * time.Millisecond)
    }
    
    fmt.printf("Reader %d: Finished\n", thread_data.thread_id)
}

main :: proc() {
    // Initialize allocator
    allocator := context.allocator
    
    // Create concurrent array list
    list := cdl.init(allocator, int)
    defer cdl.deinit(&list)
    
    fmt.println("=== Concurrent Array List Demo ===\n")
    
    // Create thread data
    num_producers := 2
    num_consumers := 1  
    num_readers := 2
    operations_per_thread := 5
    
    producer_data := make([]Thread_Data, num_producers, allocator)
    consumer_data := make([]Thread_Data, num_consumers, allocator)
    reader_data := make([]Thread_Data, num_readers, allocator)
    
    defer delete(producer_data)
    defer delete(consumer_data)
    defer delete(reader_data)
    
    // Initialize thread data
    for i in 0..<num_producers {
        producer_data[i] = Thread_Data{
            list = &list,
            thread_id = i,
            operation_count = operations_per_thread,
        }
    }
    
    for i in 0..<num_consumers {
        consumer_data[i] = Thread_Data{
            list = &list,
            thread_id = i,
            operation_count = operations_per_thread,
        }
    }
    
    for i in 0..<num_readers {
        reader_data[i] = Thread_Data{
            list = &list,
            thread_id = i,
            operation_count = operations_per_thread,
        }
    }
    
    // Start threads
    threads := make([]^thread.Thread, num_producers + num_consumers + num_readers, allocator)
    defer delete(threads)
    
    thread_idx := 0
    
    // Start producer threads
    for i in 0..<num_producers {
        threads[thread_idx] = thread.create_and_start_with_data(&producer_data[i], producer_worker)
        thread_idx += 1
    }
    
    // Start consumer threads (with a small delay)
    time.sleep(50 * time.Millisecond)
    for i in 0..<num_consumers {
        threads[thread_idx] = thread.create_and_start_with_data(&consumer_data[i], consumer_worker)
        thread_idx += 1
    }
    
    // Start reader threads
    for i in 0..<num_readers {
        threads[thread_idx] = thread.create_and_start_with_data(&reader_data[i], reader_worker)
        thread_idx += 1
    }
    
    // Wait for all threads to complete
    for t in threads {
        thread.join(t)
    }
    
    fmt.printf("\n=== Final Results ===\n")
    fmt.printf("Final list size: %d\n", cdl.count(&list))
    
    // Print remaining items
    final_count := cdl.count(&list)
    if final_count > 0 {
        fmt.printf("Remaining items: ")
        for i in 0..<final_count {
            value := cdl.get(&list, i)
            fmt.printf("%d ", value)
        }
        fmt.println()
    }
    
    fmt.println("\nDemo completed!")
}