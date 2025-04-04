package exceptions

import "core:fmt"
import "core:c/libc"
import "base:runtime"

Error :: struct {
    code: i32,
    message: string,
    location: runtime.Source_Code_Location,
}

// Thread-local storage for exception context avoids issues with nested exceptions and concurrency
Thread_Context :: struct {
    buf: libc.jmp_buf,
    error: Error,
    is_handling: bool,
}

thread_ctx: Thread_Context

throw :: proc(err: i32, message := "", loc := #caller_location) {
    if thread_ctx.is_handling {
        panic("Nested exception detected", loc)
    }
    thread_ctx.error = Error{
        code = err,
        message = message,
        location = loc,
    }
    libc.longjmp(&thread_ctx.buf, err)
}

get_error :: proc() -> Error {
    return thread_ctx.error
}

@(init)
init :: proc() {
    reset()
}

// Reset exception context
reset :: proc(loc := #caller_location) {
    if err := libc.setjmp(&thread_ctx.buf); err != 0 {
        err_info := thread_ctx.error
        msg := err_info.message != "" ? fmt.tprintf("Exception %d: %s", err, err_info.message) : fmt.tprintf("Exception %d", err)
        thread_ctx.is_handling = false
        thread_ctx.error = Error{} // Clear err state before panic
        panic(msg, loc)
    }
}

try :: proc(
    try_proc: proc(), 
    catch_proc: proc(err: Error) = nil, 
    finally_proc: proc() = nil, 
    loc := #caller_location,
) {
    err := libc.setjmp(&thread_ctx.buf)
    defer {
        if finally_proc != nil {
            finally_proc()
        }
        reset(loc)
    }
    if err == 0 {
        thread_ctx.is_handling = false
        try_proc()
    } else if catch_proc != nil {
        thread_ctx.is_handling = true
        catch_proc(thread_ctx.error)
    }
}

try_or_panic :: proc(try_proc: proc(), loc := #caller_location) {
    try(try_proc, nil, nil, loc) // Will automatically panic via reset() if an error occurs
}

try_with_default :: proc(try_proc: proc() -> $T, default_val: T, loc := #caller_location) -> T {
    result: T = default_val
    success:bool
    try(
        proc() {
            result = try_proc()
            success = true
        },
        proc(e: Error) {
            result = default_val // Reset to default value on exception
            success = false
        },
        nil,
        loc,
    )
    return result
}