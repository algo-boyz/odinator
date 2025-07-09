# Signals Library

A lightweight, type-safe signal/slot implementation for the Odin programming language. This library provides a simple and efficient way to implement the observer pattern, allowing components to communicate through loosely coupled events.

## Features

- **Type Safety**: Generic implementation ensures compile-time type checking
- **Context Support**: Optional context parameter for additional data in callbacks
- **Automatic Cleanup**: Built-in cleanup functions for resource management
- **Memory Management**: Proper allocation and deallocation of signal instances
- **Simple API**: Easy-to-use connect/disconnect/emit interface

## Quick Start

```odin
import signals "path/to/signals"

// Create a signal that emits strings
signal := signals.init(string)

// Connect a listener
listener_id := signals.connect(signal, nil, proc(payload: signals.Signal_Payload(string, rawptr)) {
    fmt.printf("Received: %s\n", payload.value)
})

// Emit a value
signals.emit(signal, "Hello, World!")

// Clean up
signals.deinit(signal)
```

## API Reference

### Core Types

```odin
Signal_Id :: int

Signal :: struct($T, $C: typeid) {
    listeners: map[int](Signal_Listener(T, C)),
    _last_id:  Signal_Id,
}
```

### Initialization

#### `init_with_value`
Creates a signal with a specific value type and `rawptr` context.

```odin
init_with_value :: proc($T: typeid) -> ^Signal(T, rawptr)
```

#### `init_with_value_and_ctx`
Creates a signal with both value and context types.

```odin
init_with_value_and_ctx :: proc($T, $C: typeid) -> ^Signal(T, C)
```

#### `init`
Generic procedure that can be called with either one or two type parameters.

### Connection

#### `connect_simple`
Connects a listener with a simple callback function.

```odin
connect_simple :: proc(
    self: ^Signal($T, $C),
    ctx: C,
    fn: proc(payload: Signal_Payload(T, C)),
) -> Signal_Id
```

#### `connect_with_cleanup`
Connects a listener with an optional cleanup function.

```odin
connect_with_cleanup :: proc(
    self: ^Signal($T, $C),
    ctx: C,
    fn: proc(payload: Signal_Payload(T, C)),
    cleanup: proc(ctx: C),
) -> Signal_Id
```

#### `connect`
Generic procedure that can be called with or without cleanup.

### Emission

#### `emit`
Emits a value to all connected listeners.

```odin
emit :: proc(self: ^Signal($T, $C), value: T)
```

### Disconnection

#### `disconnect`
Disconnects a listener by its ID and calls cleanup if provided.

```odin
disconnect :: proc(self: ^Signal($T, $C), id: Signal_Id)
```

### Cleanup

#### `deinit`
Properly cleans up a signal instance, disconnecting all listeners.

```odin
deinit :: proc(self: ^Signal($T, $C))
```

## Usage Examples

### Basic Usage

```odin
import signals "path/to/signals"
import "core:fmt"

main :: proc() {
    // Create a signal that emits integers
    counter_signal := signals.init(int)
    defer signals.deinit(counter_signal)

    // Connect multiple listeners
    id1 := signals.connect(counter_signal, nil, proc(payload: signals.Signal_Payload(int, rawptr)) {
        fmt.printf("Listener 1: Count is %d\n", payload.value)
    })

    id2 := signals.connect(counter_signal, nil, proc(payload: signals.Signal_Payload(int, rawptr)) {
        fmt.printf("Listener 2: Count is %d\n", payload.value)
    })

    // Emit values
    signals.emit(counter_signal, 42)
    signals.emit(counter_signal, 100)

    // Disconnect one listener
    signals.disconnect(counter_signal, id1)

    // Emit again - only listener 2 will receive
    signals.emit(counter_signal, 200)
}
```

### With Context

```odin
import signals "path/to/signals"
import "core:fmt"

User :: struct {
    name: string,
    age:  int,
}

main :: proc() {
    // Create a signal with User context
    user_signal := signals.init_with_value_and_ctx(string, User)
    defer signals.deinit(user_signal)

    user := User{name = "Alice", age = 30}

    // Connect with context
    signals.connect(user_signal, user, proc(payload: signals.Signal_Payload(string, User)) {
        fmt.printf("User %s (age %d) says: %s\n",
                   payload.ctx.name, payload.ctx.age, payload.value)
    })

    signals.emit(user_signal, "Hello from context!")
}
```

### With Cleanup

```odin
import signals "path/to/signals"
import "core:fmt"

main :: proc() {
    signal := signals.init(string)
    defer signals.deinit(signal)

    // Connect with cleanup function
    signals.connect_with_cleanup(
        signal,
        nil,
        proc(payload: signals.Signal_Payload(string, rawptr)) {
            fmt.printf("Received: %s\n", payload.value)
        },
        proc(ctx: rawptr) {
            fmt.println("Cleanup called!")
        },
    )

    signals.emit(signal, "Test message")
    // Cleanup will be called when disconnecting or deinitializing
}
```

## Memory Management

The library handles memory management automatically:

- `init` procedures allocate memory for the signal
- `deinit` properly cleans up all listeners and frees the signal memory
- `disconnect` calls cleanup functions if provided
- Always call `deinit` when you're done with a signal to prevent memory leaks

## Thread Safety

This implementation is **not thread-safe**. If you need thread-safe signals, you'll need to add appropriate synchronization mechanisms around the signal operations.

## Performance Considerations

- Signal emission is O(n) where n is the number of connected listeners
- Connection and disconnection are O(1) operations
- Memory overhead is minimal with efficient map-based storage

## License

[MIT](./LICENSE)
