package wsserver

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import "core:strings"

// Opaque type for `pthread_t` from libpthread
PThread :: [size_of(rawptr)]u8
// Opaque type for `pthread_mutex_t` from libpthread
PThread_Mutex :: [40]u8
// Opaque type for `pthread_cond_t` from libpthread
PThread_Cond :: [48]u8

// Alias for `ws_server`
@(private)
C_Server :: struct {
	host:        cstring,
	port:        u16,
	thread_loop: c.int,
	timeout_ms:  u32,
	evs:         C_Events,
	ctx:         rawptr,
}

Server :: struct {
	host:        string,
	port:        u16,
	// Create a new thread for the socket accept function 
	thread_loop: bool,
	timeout_ms:  u32,
	evs:         Events,
	ctx:         rawptr,
}

// Alias for `ws_cli_conn_t`
Client_Connection :: u64

// Alias for  `ws_connection`
Connection :: struct {
	client_sock:        c.int,
	state:              c.int,
	ws_srv:             Server,
	mtx_state:          PThread_Mutex,
	cnd_state_close:    PThread_Cond,
	thrd_tout:          PThread,
	close_thrd:         bool,
	mtx_snd:            PThread_Mutex,
	ip:                 [1024]u8,
	port:               [32]u8,
	last_pong_id:       i32,
	current_ping_id:    i32,
	mtx_ping:           PThread_Mutex,
	connection_context: rawptr,
	client_id:          Client_Connection,
}

MESSAGE_LENGTH :: 2048

Frame_Data :: struct {
	frm:        [MESSAGE_LENGTH]u8,
	msg:        [^]u8,
	msg_ctrl:   [125]u8,
	cur_pos:    c.size_t,
	amt_rad:    c.size_t,
	frame_type: Frame_Type,
	frame_size: u64,
	error:      c.int,
	client:     ^Connection,
}

Connection_State :: enum (c.int) {
	Invalid_Client = -1,
	Connecting     = 0,
	Open           = 1,
	Closing        = 2,
	Closed         = 3,
}

Frame_Type :: enum (c.int) {
	Fin          = 128,
	Fin_Shift    = 7,
	Continuation = 0,
	Text         = 1,
	Binary       = 2,
	Close        = 8,
	Ping         = 9,
	Pong         = 0xA,
	Unsupported  = 0xF,
}

C_Events :: struct {
	onopen:    proc "c" (client: Client_Connection),
	onclose:   proc "c" (client: Client_Connection),
	onmessage: proc "c" (client: Client_Connection, msg: [^]u8, size: u64, type: Frame_Type),
}

Events :: struct {
	onopen:    proc(client: Client_Connection),
	onclose:   proc(client: Client_Connection),
	onmessage: proc(client: Client_Connection, msg: []u8, type: Frame_Type),
}

when ODIN_OS == .Windows do foreign import ws "libws.lib"
when ODIN_OS == .Linux do foreign import ws "libws.a"
when ODIN_OS == .Darwin do foreign import ws "libws.a"

@(link_prefix = "ws_")
foreign ws {
	@(private)
	get_server_context :: proc(client: Client_Connection) -> rawptr ---
	get_connection_context :: proc(client: Client_Connection) -> rawptr ---
	set_connection_context :: proc(client: Client_Connection, ptr: rawptr) ---
	getaddress :: proc(client: Client_Connection) -> cstring ---
	getport :: proc(client: Client_Connection) -> cstring ---
	// Use `send_frame` for a more Odin-like experience
	sendframe :: proc(client: Client_Connection, msg: [^]u8, size: u64, type: Frame_Type) -> c.int ---
	// Use `send_frame_broadcast` for a more Odin-like experience
	sendframe_bcast :: proc(port: u16, msg: [^]u8, size: u64, type: Frame_Type) -> c.int ---
	ping :: proc(client: Client_Connection, threshold: c.int) ---
	// Use `send_text_frame` for a more Odin-like experience
	sendframe_txt :: proc(client: Client_Connection, msg: cstring) -> c.int ---
	// Use `send_text_frame_broadcast` for a more Odin-like experience
	sendframe_txt_bcast :: proc(port: u16, msg: cstring) -> c.int ---
	// Use `send_binary_frame` for a more Odin-like experience
	sendframe_bin :: proc(client: Client_Connection, msg: [^]u8, size: u64) -> c.int ---
	// Use `send_binary_frame_broadcast` for a more Odin-like experience
	sendframe_bin_bcast :: proc(port: u16, msg: [^]u8, size: u64) -> c.int ---
	get_state :: proc(client: Client_Connection) -> Connection_State ---
	close_client :: proc(client: Client_Connection) -> c.int ---
	@(private)
	socket :: proc(server: ^C_Server) -> c.int ---
}

Library_Context :: struct {
	events: Events,
}

Server_Context :: struct {
	lib_ctx:  Library_Context,
	user_ctx: rawptr,
}

@(private)
get_library_context :: proc(client: Client_Connection) -> ^Library_Context {
	ctx := cast(^Server_Context)get_server_context(client)
	return &ctx.lib_ctx
}

// Retrieves the server context set in `Server` struct
get_global_context :: proc(client: Client_Connection, $T: typeid) -> ^T {
	ctx := cast(^Server_Context)get_server_context(client)
	return cast(^T)ctx.user_ctx
}

// Alias for `socket`. Starts the websocket server and listens for connections.
listen :: proc(server: ^Server) -> int {
	host := strings.clone_to_cstring(server.host)
	defer delete(host)

	ctx := Server_Context {
		user_ctx = server.ctx,
		lib_ctx = {events = server.evs},
	}

	s := C_Server {
		timeout_ms = server.timeout_ms,
		thread_loop = server.thread_loop ? 1 : 0,
		port = server.port,
		host = host,
		ctx = &ctx,
		evs = C_Events{onopen = proc "c" (client: Client_Connection) {
				context = runtime.default_context()

				arena: virtual.Arena
				if err := virtual.arena_init_growing(&arena); err != nil {
					fmt.println("failed to initialize growable arena.", err)
					return
				}
				defer virtual.arena_free_all(&arena)

				ctx := get_library_context(client)

				context.temp_allocator = virtual.arena_allocator(&arena)
				ctx.events.onopen(client)
			}, onclose = proc "c" (client: Client_Connection) {
				context = runtime.default_context()

				arena: virtual.Arena
				if err := virtual.arena_init_growing(&arena); err != nil {
					fmt.println("failed to initialize growable arena.", err)
					return
				}
				defer virtual.arena_free_all(&arena)

				ctx := get_library_context(client)

				context.temp_allocator = virtual.arena_allocator(&arena)
				ctx.events.onclose(client)
			}, onmessage = proc "c" (
				client: Client_Connection,
				msg: [^]u8,
				size: u64,
				type: Frame_Type,
			) {
				context = runtime.default_context()

				arena: virtual.Arena
				if err := virtual.arena_init_growing(&arena); err != nil {
					fmt.println("failed to initialize growable arena.", err)
					return
				}
				defer virtual.arena_free_all(&arena)

				ctx := get_library_context(client)

				context.temp_allocator = virtual.arena_allocator(&arena)
				ctx.events.onmessage(client, msg[:size], type)
			}},
	}

	return int(socket(&s))
}

// Wrapper proc for `sendframe_bcast`
send_frame_broadcast :: proc(port: u16, data: []byte, type: Frame_Type) -> int {
	msg := slice.as_ptr(data)
	return int(sendframe_bcast(port, msg, u64(len(data)), type))
}

// Wrapper proc for `sendframe`
send_frame :: proc(client: Client_Connection, data: []byte, type: Frame_Type) -> int {
	msg := slice.as_ptr(data)
	return int(sendframe(client, msg, u64(len(data)), type))
}

// Wrapper proc for `sendframe_txt`
send_text_frame :: proc(client: Client_Connection, msg: string) -> int {
	cstr := strings.clone_to_cstring(msg)
	defer delete(cstr)
	return int(sendframe_txt(client, cstr))
}

// Wrapper proc for `sendframe_txt_bcast`
send_text_frame_broadcast :: proc(port: u16, msg: string) -> int {
	cstr := strings.clone_to_cstring(msg)
	defer delete(cstr)
	return int(sendframe_txt_bcast(port, cstr))
}

// Wrapper proc for `sendframe_bin`
send_binary_frame :: proc(client: Client_Connection, data: []byte) -> int {
	msg := slice.as_ptr(data)
	return int(sendframe_bin(client, msg, u64(len(data))))
}

// Wrapper proc for `sendframe_bin_bcast`
send_binary_frame_broadcast :: proc(port: u16, data: []byte) -> int {
	msg := slice.as_ptr(data)
	return int(sendframe_bin_bcast(port, msg, u64(len(data))))
}
