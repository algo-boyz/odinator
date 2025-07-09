package signals

import "core:fmt"

Signal_Id :: int

Signal :: struct($T, $C: typeid) {
	listeners: map[int](Signal_Listener(T, C)),
	_last_id:  Signal_Id,
}

init_with_value :: proc($T: typeid) -> ^Signal(T, rawptr) {
	return init_with_value_and_ctx(T, rawptr)
}

init_with_value_and_ctx :: proc($T, $C: typeid) -> ^Signal(T, C) {
	self := new(Signal(T, C))
	self.listeners = make(map[Signal_Id]Signal_Listener(T, C))
	self._last_id = 0
	return self
}

init :: proc {
	init_with_value,
	init_with_value_and_ctx,
}

deinit :: proc(self: ^Signal($T, $C)) {
	for id in self.listeners {
		disconnect(self, id)
	}

	delete(self.listeners)
	free(self)
	fmt.println("deinit called")
}

emit :: proc(self: ^Signal($T, $C), value: T) {
	for _, listener in self.listeners {
		listener.emit_fn(
			Signal_Payload(T, C) {
				id = listener.id,
				signal = self,
				ctx = listener.ctx,
				value = value,
			},
		)
	}
}

connect_simple :: proc(
	self: ^Signal($T, $C),
	ctx: C,
	fn: proc(payload: Signal_Payload(T, C)),
) -> Signal_Id {
	return connect_with_cleanup(self, ctx, fn, nil)
}

connect_with_cleanup :: proc(
	self: ^Signal($T, $C),
	ctx: C,
	fn: proc(payload: Signal_Payload(T, C)),
	cleanup: proc(ctx: C),
) -> Signal_Id {
	signal_listener := Signal_Listener(T, C) {
		ctx     = ctx,
		emit_fn = fn,
		id      = self._last_id + 1,
		cleanup = cleanup,
	}

	self._last_id += 1

	self.listeners[signal_listener.id] = signal_listener

	return signal_listener.id
}

connect :: proc {
	connect_simple,
	connect_with_cleanup,
}

disconnect :: proc(self: ^Signal($T, $C), id: Signal_Id) {
	if id in self.listeners {
		listener := self.listeners[id]
		if listener.cleanup != nil {
			listener.cleanup(listener.ctx)
		}
		delete_key(&self.listeners, id)
	}
}
