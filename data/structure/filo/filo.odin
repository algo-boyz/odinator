package stack

import "core:fmt"
import "core:mem"
import "core:os"

Stack :: struct($T: typeid) {
	value: T,
	next:  ^Stack(T),
}

make_stack :: proc(
	$T: typeid,
	alloc := context.allocator,
) -> (
	stack: ^Stack(T),
	err: mem.Allocator_Error,
) {
	// first item stores nothing
	return new(Stack(T), alloc)
}

stack_push :: proc(
	stack: ^$L/Stack($T),
	target: T,
	alloc := context.allocator,
) -> mem.Allocator_Error {
	new_elem, err := new_clone(Stack(T){value = target, next = stack.next})
	if err != os.ERROR_NONE {
		return err
	}
	stack.next = new_elem
	return mem.Allocator_Error.None
}


// pops an item off the stack, if the stack is empty, 
// ok's value will be false, otherwise true
stack_pop :: proc(stack: ^$L/Stack($T), alloc := context.allocator) -> (result: T, ok := false) {
	if stack.next == nil {
		return
	} else {
		result = stack.next.value
		temp := stack.next.next
		free(stack.next)
		stack.next = temp
		ok = true
		return
	}
}

// peeks the stack, if the stack is empty, 
// ok's value will be false, otherwise true
stack_peek :: proc(stack: ^$L/Stack($T), alloc := context.allocator) -> (result: T, ok := false) {
	if stack.next != nil {
		ok = true
		result = stack.next.value
	}
	return
}


// prints out the stack
print_stack :: proc(stack: ^$L/Stack($T)) {
	current_node := stack.next
	fmt.print("<")
	for current_node != nil {
		temp := current_node
		current_node = current_node.next
		fmt.print(temp.value)
		if current_node != nil {
			fmt.print(", ")
		}
	}
	fmt.print(">")
	fmt.println()
}

// calls free() on every node of the stack, then 
// freeing itself
destroy_stack :: proc(stack: ^$L/Stack($T), alloc := context.allocator) {
	current_node := stack.next
	for current_node != nil {
		temp := current_node
		current_node = current_node.next
		free(temp, alloc)
	}
	free(stack, alloc)
}