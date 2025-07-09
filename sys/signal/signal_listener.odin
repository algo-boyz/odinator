package signals

Signal_Listener :: struct($T, $C: typeid) {
	emit_fn: proc(payload: Signal_Payload(T, C)),
	ctx:     C,
	id:      Signal_Id,
	cleanup: proc(ctx: C),
}
