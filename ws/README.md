# Odin-wsServer

Odin bindings for the [wsServer](https://github.com/Theldus/wsServer) C WebSocket library.

## Overview

**Odin-wsServer** provides bindings to the lightweight and efficient [wsServer](https://github.com/Theldus/wsServer) WebSocket server library, enabling seamless WebSocket support in Odin applications. This library allows Odin developers to create WebSocket servers with minimal overhead and strong performance.

## Features

- Lightweight and efficient WebSocket server implementation.
- Direct bindings to `wsServer`, maintaining C-level performance.
- Supports multiple concurrent connections.
- Easy-to-use API for handling WebSocket messages.

## Installation

To use **odin-wsServer**, ensure that you have a copy of the static `wsServer` library (`libws.a`) in your working directory.

Follow these instructions to compile the library: [wsServer CMake Instructions](https://github.com/Theldus/wsServer/tree/master?tab=readme-ov-file#cmake)

## Usage

### Example WebSocket Server

```odin
server := Server{
    host = "0.0.0.0",
    port = 8080,
    thread_loop = false,
    timeout_ms = 5000,
    evs = Events{
        onopen = proc(client: Client_Connection) {
            fmt.println("Client connected")
        },
        onclose = proc(client: Client_Connection) {
            fmt.println("Client disconnected")
        },
        onmessage = proc(client: Client_Connection, msg: []u8, type: Frame_Type) {
            fmt.println("Received message: ", string(msg))
        },
    },
}
listen(&server)
```

## API Documentation

- [Chat Server](./server/main.odin)

- [Chat Client](./client/main.odin)

### Structures

```odin
Server :: struct {
    host:        string, // Server hostname or IP
    port:        u16,    // Port to listen on
    thread_loop: bool,   // Run accept loop in a separate thread
    timeout_ms:  u32,    // Connection timeout in milliseconds
    evs:         Events, // Event handlers
    ctx:         rawptr, // User-defined context
}
```

```odin
Connection_State :: enum (c.int) {
    Invalid_Client = -1,
    Connecting     = 0,
    Open           = 1,
    Closing        = 2,
    Closed         = 3,
}
```

```odin
Frame_Type :: enum (c.int) {
    Continuation = 0,
    Text         = 1,
    Binary       = 2,
    Close        = 8,
    Ping         = 9,
    Pong         = 10,
}
```

### Functions

#### `listen`
Starts the WebSocket server and listens for connections.

```odin
listen :: proc(server: ^Server) -> int
```

#### `send_frame`
Sends a WebSocket frame to a specific client.

```odin
send_frame :: proc(client: Client_Connection, data: []byte, type: Frame_Type) -> int
```

#### `send_frame_broadcast`
Broadcasts a WebSocket frame to all clients on a specified port.

```odin
send_frame_broadcast :: proc(port: u16, data: []byte, type: Frame_Type) -> int
```

#### `send_text_frame`
Sends a text message frame to a specific client.

```odin
send_text_frame :: proc(client: Client_Connection, msg: string) -> int
```

#### `send_text_frame_broadcast`
Broadcasts a text message frame to all clients on a specified port.

```odin
send_text_frame_broadcast :: proc(port: u16, msg: string) -> int
```

#### `send_binary_frame`
Sends a binary data frame to a specific client.

```odin
send_binary_frame :: proc(client: Client_Connection, data: []byte) -> int
```

#### `send_binary_frame_broadcast`
Broadcasts a binary data frame to all clients on a specified port.

```odin
send_binary_frame_broadcast :: proc(port: u16, data: []byte) -> int
```

#### `get_global_context`
Retrieves the user-defined context from the `Server` struct.

```odin
get_global_context :: proc(client: Client_Connection, $T: typeid) -> ^T
```

#### `get_connection_context`
Retrieves the user-defined context of the current connection.

**TODO:** Create a wrapper function that auto casts.

```odin
get_connection_context :: proc(client: Client_Connection) -> rawptr
```

#### `set_connection_context`
Sets the user-defined context of the current connection.

```odin
set_connection_context :: proc(client: Client_Connection, ptr: rawptr)
```

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests to improve this library.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

For more details on `wsServer`, visit the official repository: [Theldus/wsServer](https://github.com/Theldus/wsServer).
