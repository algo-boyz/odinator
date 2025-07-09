package signals

Signal_Payload :: struct($T, $C: typeid) {
	id:     Signal_Id,
	signal: ^Signal(T, C),
	ctx:    C,
	value:  T,
}
