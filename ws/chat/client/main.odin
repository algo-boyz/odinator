package main

import "core:c"
import "core:fmt"
import "core:mem"
import "core:net"
import "core:os"
import "core:strings"
import "core:sync"
import "core:thread"

// WsServer frame types
FRM_CONT :: 0x0
FRM_TXT  :: 0x1
FRM_BIN  :: 0x2
FRM_CLSE :: 0x8
FRM_PING :: 0x9
FRM_PONG :: 0xA
FRM_FIN  :: 0x80
FRM_MSK  :: 0x80

// Client status
TWS_ST_DISCONNECTED :: 0
TWS_ST_CONNECTED    :: 1
Ctx :: struct {
    frm:      [4096]u8,      // Frame buffer
    amt_read: int,           // Amount of bytes read from buffer
    cur_pos:  int,           // Current buffer position
    fd:       net.TCP_Socket,// Socket descriptor
    status:   int,           // Connection status
}

// Handshake header
REQUEST :: "GET / HTTP/1.1\r\n" +
          "Host: localhost:8080\r\n" +
          "Connection: Upgrade\r\n" +
          "Upgrade: websocket\r\n" +
          "Sec-WebSocket-Version: 13\r\n" +
          "Sec-WebSocket-Key: uaGPoPbZRzHcWDXiNQ5dyg==\r\n\r\n"

// Connect to a given IP address and port
tws_connect :: proc(ctx: ^Ctx, ip: string, port: u16) -> (net.TCP_Socket, bool) {
    // Init context
    ctx^ = {}
    // Create socket
    socket, socket_err := net.dial_tcp_from_hostname_and_port_string(fmt.tprintf("%s:%d", ip, port))
    if socket_err != nil {
        fmt.eprintln("Error connecting:", socket_err)
        return 0, false
    }
    // Send handshake
    request_bytes := transmute([]u8)strings.clone(REQUEST)
    bytes_sent, send_err := net.send_tcp(socket, request_bytes)
    if send_err != nil || bytes_sent != len(request_bytes) {
        fmt.eprintln("Error sending handshake:", send_err)
        net.close(socket)
        return 0, false
    }
    // Wait for protocol switch
    bytes_read, recv_err := net.recv(socket, ctx.frm[:])
    if recv_err != nil || bytes_read <= 0 {
        fmt.eprintln("Error receiving handshake response:", recv_err)
        net.close(socket)
        return 0, false
    }
    // Find end of headers
    headers := string(ctx.frm[:bytes_read])
    end_of_headers := strings.index(headers, "\r\n\r\n")
    if end_of_headers < 0 {
        fmt.eprintln("Invalid handshake response")
        net.close(socket)
        return 0, false
    }
    // Setup context
    ctx.amt_read = bytes_read
    ctx.cur_pos = end_of_headers + 4
    ctx.fd = socket
    ctx.status = TWS_ST_CONNECTED
    return socket, true
}

// Close the connection
tws_close :: proc(ctx: ^Ctx) {
    if ctx.status == TWS_ST_DISCONNECTED {
        return
    }
    net.close(ctx.fd)
    ctx.status = TWS_ST_DISCONNECTED
}

// Send a frame
tws_sendframe :: proc(ctx: ^Ctx, msg: []u8, type: int) -> bool {
    header: [10]u8
    masks: [4]u8
    header_len: int
    size := len(msg)
    // Set first byte: FIN bit and opcode
    header[0] = u8(FRM_FIN | type)
    // Set second byte: MASK bit and payload length
    header[1] = FRM_MSK
    // Determine header length based on payload size
    if size <= 125 {
        header[1] |= u8(size & 0x7F)
        header_len = 2
    } else if size <= 65535 {
        header[1] |= 126
        header[2] = u8((size >> 8) & 255)
        header[3] = u8(size & 255)
        header_len = 4
    } else {
        header[1] |= 127
        header[2] = u8((size >> 56) & 255)
        header[3] = u8((size >> 48) & 255)
        header[4] = u8((size >> 40) & 255)
        header[5] = u8((size >> 32) & 255)
        header[6] = u8((size >> 24) & 255)
        header[7] = u8((size >> 16) & 255)
        header[8] = u8((size >> 8) & 255)
        header[9] = u8(size & 255)
        header_len = 10
    }
    // Send header
    bytes_sent, send_err := net.send(ctx.fd, header[:header_len])
    if send_err != nil || bytes_sent != header_len {
        return false
    }
    // Send masks (using fixed mask for simplicity)
    masks = {0xAA, 0xAA, 0xAA, 0xAA}
    bytes_sent, send_err = net.send(ctx.fd, masks[:])
    if send_err != nil || bytes_sent != 4 {
        return false
    }
    // Mask message and send it
    masked_msg := make([]u8, size)
    defer delete(masked_msg)
    
    for i := 0; i < size; i += 1 {
        masked_msg[i] = msg[i] ~ masks[i % 4]
    }
    bytes_sent, send_err = net.send(ctx.fd, masked_msg)
    if send_err != nil || bytes_sent != size {
        return false
    }
    return true
}

// Read next byte from buffer or from socket if buffer is empty
next_byte :: proc(ctx: ^Ctx) -> (byte: int, ok: bool) {
    // If buffer is empty or full, read more data
    if ctx.cur_pos == 0 || ctx.cur_pos >= ctx.amt_read {
        bytes_read, recv_err := net.recv_tcp(ctx.fd, ctx.frm[:])
        if recv_err != nil || bytes_read <= 0 {
            return -1, false
        }
        ctx.amt_read = bytes_read
        ctx.cur_pos = 0
    }
    byte = int(ctx.frm[ctx.cur_pos])
    ctx.cur_pos += 1
    return byte, true
}

// Skip bytes in the current frame
skip_frame :: proc(ctx: ^Ctx, frame_size: int) -> bool {
    for i := 0; i < frame_size; i += 1 {
        byte, ok := next_byte(ctx)
        if !ok || byte == -1 {
            return false
        }
    }
    return true
}

// Receive a frame
tws_receiveframe :: proc(ctx: ^Ctx, buff: ^[]u8) -> (frame_length: int, frm_type: int, ok: bool) {
    // Buffer should be valid
    if buff == nil {
        return 0, 0, false
    }
    // Read first byte (FIN bit and opcode)
    cur_byte, ok_byte := next_byte(ctx)
    if !ok_byte {
        return 0, 0, false
    }
    opcode := cur_byte & 0xF
    
    // Handle close frame
    if opcode == FRM_CLSE {
        tws_close(ctx)
        return 0, FRM_CLSE, false
    }
    // Read masked bit and payload length
    cur_byte, ok_byte = next_byte(ctx)
    if !ok_byte {
        return 0, 0, false
    }
    frame_length = int(cur_byte & 0x7F)
    is_masked := (cur_byte & 0x80) != 0
    // Read extended payload length if needed
    if frame_length == 126 {
        high_byte, ok_high := next_byte(ctx)
        if !ok_high {
            return 0, 0, false
        }
        low_byte, ok_low := next_byte(ctx)
        if !ok_low {
            return 0, 0, false
        }
        frame_length = (int(high_byte) << 8) | int(low_byte)
    } else if frame_length == 127 {
        frame_length = 0
        for i := 0; i < 8; i += 1 {
            next_val, ok_val := next_byte(ctx)
            if !ok_val {
                return 0, 0, false
            }
            frame_length = (frame_length << 8) | int(next_val)
        }
    }
    // Read mask if present
    mask: [4]u8
    if is_masked {
        for i := 0; i < 4; i += 1 {
            mask_byte, ok_mask := next_byte(ctx)
            if !ok_mask {
                return 0, 0, false
            }
            mask[i] = u8(mask_byte)
        }
    }
    // Skip non-text and non-binary frames
    if opcode != FRM_TXT && opcode != FRM_BIN {
        if !skip_frame(ctx, frame_length) {
            return 0, 0, false
        }
        return frame_length, opcode, true
    }
    // Ensure buffer size
    if len(buff^) < frame_length + 1 {
        if buff^ != nil {
            delete(buff^)
        }
        buff^ = make([]u8, frame_length + 1)
    } else if len(buff^) != frame_length + 1 {
        buff^ = buff^[:frame_length + 1]
    }
    // Receive frame content
    for i := 0; i < frame_length; i += 1 {
        cur_byte, ok_read := next_byte(ctx)
        if !ok_read {
            return i, opcode, false
        }
        // Apply mask if present
        if is_masked {
            buff^[i] = u8(cur_byte) ~ mask[i % 4]
        } else {
            buff^[i] = u8(cur_byte)
        }
    }
    // Null terminate
    buff^[frame_length] = 0
    return frame_length, opcode, true
}

ThreadData :: struct {
    ctx: ^Ctx,
    mutex: ^sync.Mutex,
    stop: ^bool,
}

receive_proc :: proc(t: ^thread.Thread) {
    data := cast(^ThreadData)t.data
    ctx := data.ctx
    mutex := data.mutex
    stop := data.stop
    buffer: []u8 = make([]u8, 4096)
    defer if buffer != nil {
        delete(buffer)
    }
    for ctx.status == TWS_ST_CONNECTED && !stop^ {
        length, frame_type, ok := tws_receiveframe(ctx, &buffer)
        if !ok {
            if frame_type == FRM_CLSE {
                sync.mutex_lock(mutex)
                fmt.println("\rServer closed the connection")
                fmt.print("> ")
                sync.mutex_unlock(mutex)
            } else {
                sync.mutex_lock(mutex)
                fmt.println("\rError receiving frame")
                fmt.print("> ")
                sync.mutex_unlock(mutex)
            }
            break
        }
        if length > 0 {
            message := string(buffer[:length])
            sync.mutex_lock(mutex)
            fmt.printf("\r[server] sent: %s\n> ", message)
            sync.mutex_unlock(mutex)
        }
    }
    fmt.println("Receive thread exit")
}

main :: proc() {
    ctx: Ctx
    fmt.println("Odin WebSocket Client")
    fmt.println("Connecting to localhost:8080...")
    socket, ok := tws_connect(&ctx, "localhost", 8080)
    if !ok {
        fmt.eprintln("Failed to connect to WebSocket server")
        return
    }
    defer tws_close(&ctx)

    fmt.println("Connected to WebSocket Server!")
    fmt.println("Type a message and press Enter (Ctrl+C to quit)")

    // Create a mutex to sync with console output
    output_mutex: sync.Mutex
    stop_thread := false
    thread_data := ThreadData{
        ctx = &ctx,
        mutex = &output_mutex,
        stop = &stop_thread,
    }
    // Create and start receive thread
    receive_thread := thread.create(receive_proc)
    if receive_thread == nil {
        fmt.eprintln("Failed to create receive thread")
        return
    }
    receive_thread.init_context = context
    receive_thread.data = &thread_data
    thread.start(receive_thread)
    
    input_buffer: [1024]u8
    for {
        sync.mutex_lock(&output_mutex)
        fmt.print("> ")
        sync.mutex_unlock(&output_mutex)
        // Read input from stdin
        bytes_read, read_err := os.read(os.stdin, input_buffer[:])
        if read_err != nil || bytes_read <= 0 {
            fmt.eprintln("Error reading input")
            break
        }
        input_text := strings.trim_right_space(string(input_buffer[:bytes_read]))
        if !tws_sendframe(&ctx, transmute([]u8)input_text, FRM_TXT) {
            fmt.eprintln("Error sending message")
            break
        }
    }
    stop_thread = true
    thread.join(receive_thread)
    thread.destroy(receive_thread)
    fmt.println("Disconnected from server")
}