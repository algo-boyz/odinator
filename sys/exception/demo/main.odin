package main

import "core:fmt"
import "../"

divide :: proc(a, b: int) -> int {
    if b == 0 {
        exception.throw(1, "Division by zero")
    }
    return a / b
}

process :: proc(data: []int) -> (result: int) {
    if len(data) == 0 {
        exception.throw(2, "Empty data array")
    }
    for value in data {
        result += 100 / value // This might throw an exception if value is 0
    }
    return result
}

nested_operations :: proc() {
    fmt.println("Nested operations")
    exception.try(
        proc() {
            fmt.println("Outer try block")
            exception.try(
                proc() {
                    fmt.println("Inner try block")
                    exception.throw(5, "Inner exception")
                    fmt.println("Never prints")
                },
                proc(e: exception.Error) {
                    fmt.printf("Caught inner exception: %d - %s at %v\n", 
                              e.code, e.message, e.location)
                },
            )
            fmt.println("Back to outer try block")
            exception.throw(6, "Outer exception")
            fmt.println("Never prints")
        },
        proc(e: exception.Error) {
            fmt.printf("Caught outer exception: %d - %s at %v\n", 
                      e.code, e.message, e.location)
        },
    )
}

main :: proc() {
    fmt.println("Exception Handlers\n=====================")
    fmt.println("\ntry_catch\n")
    exception.try(
        proc() {
            fmt.println("Trying to divide 10 by 2...")
            result := divide(10, 2)
            fmt.println("Result:", result)
            
            fmt.println("Trying to divide 10 by 0...")
            result = divide(10, 0)
            fmt.println("Never prints")
        },
        proc(e: exception.Error) {
            fmt.printf("Caught exception: %d - %s at %v\n\n",  e.code, e.message, e.location)
        },
    )
    fmt.println("\nmulti_exceptions\n")
    exception.try(
        proc() {
            data := []int{5, 10, 0, 20}  // NOTE: 0 will throw an exception
            fmt.println("Processing data:", data)
            fmt.println("Result:", process(data))
        },
        proc(e: exception.Error) {
            fmt.printf("Caught exception: %d - %s\n\n", e.code, e.message)
        },
    )
    fmt.println("\ntry_or_panic\n")
    exception.try_or_panic(proc() {
        fmt.println("This operation will succeed")
    })
    fmt.println("\nnested_exceptions\n")
    nested_operations()
    fmt.println("All good!")
}