package tests

import "core:testing"
import cb ".."

/*
# Callbacks in Odin source: https://github.com/saenai255/odin-callback
package main

import "callback"

make_adder :: proc(base: int) -> cb.Callback(int, int) {
    return cb.make(
        capture = new_clone(base),
        callback = proc(capture: ^int, param: int) -> int {
            capture^ += param
            return capture^
        },
        free = proc(capture: rawptr) {
            free(cast(^int)capture)
        },
    )
}

main :: proc() {
    adder := make_adder(10)
    defer cb.free(adder) // Cleanup

    cb.exec(adder, 5) // 15
    cb.exec(adder, 6) // 21
    cb.exec(adder, 7) // 28
}
*/

@(test)
callback_gets_called :: proc(t: ^testing.T) {
    capture := new_clone(42)
    fn := cb.make(
        capture = capture,
        callback = proc(capture: ^int, param: cb.Void) -> cb.Void {
            capture^ += 1
            return .Nil
        },
        free = proc(capture: rawptr) {
            free(cast(^int)capture)
        },
    )
    defer cb.free(fn)

    cb.exec(fn)
    testing.expect_value(t, capture^, 43)
    cb.exec(fn)
    testing.expect_value(t, capture^, 44)
}

@(test)
callback_free_gets_called :: proc(t: ^testing.T) {
    capture := new_clone(42)
    fn := cb.make(
        capture = capture,
        callback = proc(state: ^int, param: cb.Void) -> cb.Void {
            state^ += 1
            return .Nil
        },
        free = proc(capture: rawptr) {
            free(cast(^int)capture)
        },
    )
    defer cb.free(fn)

    cb.exec(fn)
    testing.expect_value(t, capture^, 43)
    cb.exec(fn)
    testing.expect_value(t, capture^, 44)
}

@(test)
callback_computes_value :: proc(t: ^testing.T) {
    capture := new_clone(42)
    fn := cb.make(
        capture = capture,
        callback = proc(capture: ^int, param: cb.Void) -> int {
            return capture^ * 2
        },
        free = proc(capture: rawptr) {
            free(cast(^int)capture)
        },
    )
    defer cb.free(fn)

    result := cb.exec(fn)
    testing.expect_value(t, result, 84)
}

make_adder :: proc(base: int) -> cb.Callback(int, int) {
    return cb.make(
        capture = new_clone(base),
        callback = proc(state: ^int, param: int) -> int {
            state^ += param
            return state^
        },
        free = proc(state: rawptr) {
            free(cast(^int)state)
        },
    )
}

@(test)
callback_with_param :: proc(t: ^testing.T) {
    adder := make_adder(10)
    defer cb.free(adder)

    testing.expect_value(t, cb.exec(adder, 5), 15)
    testing.expect_value(t, cb.exec(adder, 7), 22)
    testing.expect_value(t, cb.exec(adder, 3), 25)
}