package chat

import ws "../"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:sync"

on_open :: proc(client: ws.Client_Connection) {
	tid := os.current_thread_id()
	fmt.printfln("[client %d][thread %d] connected", client, tid)

	ctx := ws.get_global_context(client, Server_Context)
	ctx_add_client(ctx, client)
}

on_close :: proc(client: ws.Client_Connection) {
	tid := os.current_thread_id()
	fmt.printfln("[client %d][thread %d] disconnected", client, tid)

	ctx := ws.get_global_context(client, Server_Context)
	ctx_remove_client(ctx, client)
}

on_message :: proc(client: ws.Client_Connection, data: []u8, type: ws.Frame_Type) {
	tid := os.current_thread_id()
	fmt.printfln("[client %d][thread %d] sent message", client, tid)

	if type != .Text {
		ws.send_text_frame(client, "invalid message")
		ws.close_client(client)
		return
	}

	ctx := ws.get_global_context(client, Server_Context)
	clients := ctx_clone_clients(ctx)

	message := string(data)
	chat_message := fmt.tprintf("[client %d] says: %s", client, message)
	chat_message_for_self := fmt.tprintf("You said: %s", message)
	for connection in clients {
		if connection == client {
			ws.send_text_frame(client, chat_message_for_self)
		} else {
			ws.send_text_frame(connection, chat_message)
		}
	}
}

Server_Context :: struct {
	clients: [dynamic]ws.Client_Connection,
	mutex:   ^sync.Mutex,
}

ctx_add_client :: proc(ctx: ^Server_Context, client: ws.Client_Connection) {
	sync.lock(ctx.mutex)
	defer sync.unlock(ctx.mutex)
	append(&ctx.clients, client)
}

ctx_remove_client :: proc(ctx: ^Server_Context, client: ws.Client_Connection) {
	sync.lock(ctx.mutex)
	defer sync.unlock(ctx.mutex)
	idx := -1
	for other_client, index in ctx.clients {
		if other_client == client {
			idx = index
			break
		}
	}

	assert(idx >= 0)
	unordered_remove(&ctx.clients, idx)
	shrink(&ctx.clients)
}

ctx_clone_clients :: proc(ctx: ^Server_Context) -> []ws.Client_Connection {
	sync.lock(ctx.mutex)
	defer sync.unlock(ctx.mutex)
	return slice.clone(ctx.clients[:], context.temp_allocator)
}

PORT :: 8080

main :: proc() {
	clients: [dynamic]ws.Client_Connection
	defer delete(clients)

	lock: sync.Mutex
	ctx := Server_Context{clients, &lock}


	tid := os.current_thread_id()
	server := ws.Server {
		host = "0.0.0.0",
		port = PORT,
		timeout_ms = 1000,
		evs = {onopen = on_open, onclose = on_close, onmessage = on_message},
		ctx = &ctx,
	}

	fmt.printfln("[thread %d] server started on port %d", tid, PORT)
	ws.listen(&server)
	fmt.printfln("server closed")

}
