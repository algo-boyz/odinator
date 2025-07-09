package callback

Void :: enum {
    Nil,
}

Callback :: struct($P, $R: typeid) {
    callback: proc(rawptr, P) -> R,
    capture: rawptr,
    free: proc(rawptr),
}

// Creates a callback that does not require cleanup.
make_without_cleanup :: proc(
    capture: $T,
    callback: proc(rawptr, $P) -> $R,
) -> Callback(P, R) {
    return {
        callback = callback,
        capture = capture,
        free = nil,
    }
}

// Creates a callback that requires cleanup.
make_with_cleanup :: proc(
    capture: $T,
    callback: proc(rawptr, $P) -> $R,
    free: proc(rawptr),
) -> Callback(P, R) {
    return {
        callback = callback,
        capture = capture,
        free = free,
    }
}

// Executes a callback and returns its result.
exec_with_param :: proc(c: Callback($P, $R), param: P) -> R {
    return c.callback(c.capture, param)
}

// Executes a callback and returns its result. The callback must not take any parameters.
exec_no_param :: proc(c: Callback(Void, $R)) -> R {
    return c.callback(c.capture, .Nil)
}

exec :: proc { exec_no_param, exec_with_param }

// Frees resources associated with a callback.
free :: proc(c: Callback($P, $R)) {
    if c.free != nil {
        c.free(c.capture)
    }
}