package stack

import "core:testing"

@(test)
stack_peek_test :: proc(t: ^testing.T) {
	s, _err := make_stack(i32)
	defer destroy_stack(s)
	stack_push(s, 1)
	stack_push(s, 2)
	stack_push(s, 3)

	p, ok := stack_peek(s)
	testing.expect(t, p == 3, "incorrect stack peek output")
	testing.expect(t, ok == true, "incorrect stack peek output")

	empty, _err2 := make_stack(i32)
	defer destroy_stack(empty)
	p, ok = stack_peek(empty)
	testing.expect(t, ok == false, "incorrect stack indicator")
}

@(test)
stack_pop_test :: proc(t: ^testing.T) {
	s, _err := make_stack(i32)
	defer destroy_stack(s)
	stack_push(s, 1)
	stack_push(s, 2)
	stack_push(s, 3)

	p, ok := stack_pop(s)
	testing.expect(t, p == 3, "incorrect stack pop output")
	testing.expect(t, ok == true, "incorrect stack empty indicator")

	p, ok = stack_pop(s)
	testing.expect(t, p == 2, "incorrect stack pop output")
	testing.expect(t, ok == true, "incorrect stack empty indicator")

	p, ok = stack_pop(s)
	p, ok = stack_pop(s)
	testing.expect(t, ok == false, "incorrect stack empty indicator")
}

@(test)
multi_push_pop_test :: proc(t: ^testing.T) {
	s, _err := make_stack(i32)
	defer destroy_stack(s)
	stack_push(s, 1)
	stack_push(s, 2)
	stack_push(s, 3)

	stack_pop(s)
	stack_pop(s)
	stack_pop(s)
	stack_pop(s)

	p, ok := stack_peek(s)
	testing.expect(t, ok == false, "incorrect stack peek output")

	stack_push(s, 4)

	p, ok = stack_peek(s)
	testing.expect(t, p == 4, "incorrect stack peek output")
	testing.expect(t, ok == true, "incorrect stack peek output")

	p, ok = stack_pop(s)
	testing.expect(t, p == 4, "incorrect stack peek output")
	testing.expect(t, ok == true, "incorrect stack peek output")
}