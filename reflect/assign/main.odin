#+feature dynamic-literals
package main

import "core:fmt"
import "core:reflect"

Foo :: struct {
    a: int,
    b: ^int,
    c: ^[dynamic]int,
}

main :: proc() {
    val_b := 2
    val_c := [dynamic]int{1, 2, 3}
    my_struct := Foo{
        a = 1,
        b = &val_b, // 'b' points to 'val_in_main'
        c = &val_c, // 'c' points to a dynamic array
    }
    assign(&my_struct)

    fmt.println("my_struct.a:", my_struct.a)                 // Expected: 6
    fmt.println("my_struct.b (address):", my_struct.b)       // Expected: address of val_in_main
    fmt.println("Value pointed to by b (*my_struct.b):", my_struct.b^) // Expected: 6
    fmt.println("Original val_b:", val_b)        // Expected: 6

    fmt.println("my_struct.c:", my_struct.c^)
}

assign :: proc(dest: ^$T) {
    f_a := reflect.struct_field_value_by_name(dest^, "a")
    // f_a.data is a rawptr to my_struct.a (effectively ^int)
    new_val_for_a := 6
    (^int)(f_a.data)^ = new_val_for_a
    fmt.printf("Reflected value of 'a' after modification: %d\n", f_a)

    f_b := reflect.struct_field_value_by_name(dest^, "b")
    // f_b.data is a rawptr to my_struct.b.
    // Since my_struct.b is of type ^int, f_b.data is effectively ^(^int).
    
    // Get the pointer value stored in field 'b'.
    pointer_stored_in_b := (^(^int))(f_b.data)^
    // Dereference ^int pointer to assign to the integer it points to.
    new_val_for_target_of_b := 6
    pointer_stored_in_b^ = new_val_for_target_of_b
    fmt.printf("Address: %v and Value: %d pointed to by field 'b'\n", pointer_stored_in_b, pointer_stored_in_b^)

    append(dest.c, 4)
}