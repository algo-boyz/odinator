package jmp

import "core:c/libc"
import "core:container/queue"
import "core:fmt"
import "core:time"

Scheduler :: struct {
	buf: map[i64]libc.jmp_buf,
	// where to start
	anchor:  libc.jmp_buf,
	// what is deleted
	queue:   queue.Queue(i64),
	// garbage collector
	cleanup: [dynamic]i64,
}

cleanup :: proc(s: ^Scheduler) {
	for item in s.cleanup {
		delete_key(&s.buf, item)
	}
	clear(&s.cleanup)
}

@(deferred_in = cleanup)
pause :: #force_inline proc(s: ^Scheduler) {
	rn := time.tick_now()
	s.buf[rn._nsec] = libc.jmp_buf{}
	if libc.setjmp(&s.buf[rn._nsec]) == 1 {
		return
	}
	queue.push_back(&s.queue, rn._nsec)
	libc.longjmp(&s.anchor, 1)
}

cleanup_resume :: proc(s: ^Scheduler, _: i64) {
	cleanup(s)
}

@(deferred_in = cleanup_resume)
resume :: proc(s: ^Scheduler, time: i64) -> bool {
	buf, ok := s.buf[time]
	if !ok {
		return false
	}
	// mark for garbage collection
	append(&s.cleanup, time)
	libc.longjmp(&buf, 1)
}

anchor_jump :: #force_inline proc(s: ^Scheduler) {
	libc.longjmp(&s.anchor, 1)
}

anchor :: #force_inline proc(s: ^Scheduler) {
	libc.setjmp(&s.anchor)
}

get_paused :: proc(s: ^Scheduler) -> (timestamp: i64, ok: bool) {
	timestamp, ok = queue.pop_front_safe(&s.queue)
	return
}

/*
fn :: #force_inline proc(s: ^Scheduler) {
	fmt.println("pausing")
	pause(s)
	fmt.println("unpaused")
}

main :: proc() {
	s := new_scheduler()
	anchor(&s)

	if item, ok := get_paused(&s); ok {
		fmt.println("pre resume")
		resume(&s, item)
	} else {
		fmt.println("running test fn")
		fn(&s)
	}

	fmt.println("all done")
}

output:
running test fn
pausing
pre resume
unpaused
all done
*/

