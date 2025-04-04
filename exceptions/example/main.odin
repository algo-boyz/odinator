package main

import "core:fmt"
import "../"

// Function that might throw an exception
divide :: proc(a, b: int) -> int {
    if b == 0 {
        exceptions.throw(1, "Division by zero")
    }
    return a / b
}

// Function with multiple potential exceptions
process :: proc(data: []int) -> int {
    if len(data) == 0 {
        exceptions.throw(2, "Empty data array")
    }
    
    result := 0
    for value in data {
        // This could throw an exception if value is 0
        result += 100 / value
    }
    return result
}

// Demonstrates nested try blocks
nested_operations :: proc() {
    fmt.println("Nested operations example")
    
    exceptions.try(
        proc() {
            fmt.println("Outer try block")
            
            exceptions.try(
                proc() {
                    fmt.println("Inner try block")
                    exceptions.throw(5, "Inner exception")
                    fmt.println("Never prints")
                },
                proc(e: exceptions.Error) {
                    fmt.printf("Caught inner exception: %d - %s at %v\n", 
                              e.code, e.message, e.location)
                },
            )
            
            fmt.println("Back to outer try block")
            exceptions.throw(6, "Outer exception")
            fmt.println("Never prints")
        },
        proc(e: exceptions.Error) {
            fmt.printf("Caught outer exception: %d - %s at %v\n", 
                      e.code, e.message, e.location)
        },
    )
}

main :: proc() {
    fmt.println("Exception Handlers\n=====================")
    
    fmt.println("\ntry_catch\n")
    exceptions.try(
        proc() {
            fmt.println("Trying to divide 10 by 2...")
            result := divide(10, 2)
            fmt.println("Result:", result)
            
            fmt.println("Trying to divide 10 by 0...")
            result = divide(10, 0)
            fmt.println("Never prints")
        },
        proc(e: exceptions.Error) {
            fmt.printf("Caught exception: %d - %s at %v\n\n",  e.code, e.message, e.location)
        },
    )
    fmt.println("\nmulti_exceptions\n")
    exceptions.try(
        proc() {
            data := []int{5, 10, 0, 20}  // Note 0 value will throw an exception
            fmt.println("Processing data:", data)
            fmt.println("Result:", process(data))
        },
        proc(e: exceptions.Error) {
            fmt.printf("Caught exception: %d - %s\n\n", e.code, e.message)
        },
    )
    fmt.println("\ntry_or_panic\n")
    exceptions.try_or_panic(proc() {
        fmt.println("This operation will succeed")
    })
    fmt.println("\nnested_exceptions\n")
    nested_operations()
    fmt.println("All good!")
}