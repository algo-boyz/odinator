package bit
import intrinsics "base:intrinsics"
import "core:fmt"
import bits "core:math/bits"

BYTES :: Size(1)
KIBI_BYTES :: Size(1024 * BYTES)
MEBI_BYTES :: Size(1024 * KIBI_BYTES)
GIBI_BYTES :: Size(1024 * MEBI_BYTES)

Size :: distinct int

ptr_add :: #force_inline proc "contextless" (ptr: rawptr, offset: int) -> [^]byte {
	return ([^]byte)(uintptr(ptr) + transmute(uintptr)(offset))
}
align_forward :: #force_inline proc(ptr: rawptr, align_power_of_two: int) -> int {
	assert(is_power_of_two(align_power_of_two))
	remainder := (uintptr(ptr)) & transmute(uintptr)(align_power_of_two - 1)
	result := remainder == 0 ? 0 : transmute(uintptr)align_power_of_two - remainder
	return transmute(int)result
}
align_backward :: #force_inline proc(ptr: rawptr, alignment_power_of_two: int) -> int {
	result := uintptr(ptr) & (transmute(uintptr)alignment_power_of_two - 1)
	return transmute(int)result
}

count_leading_zeros :: bits.count_leading_zeros
count_trailing_zeros :: bits.count_trailing_zeros
count_ones :: bits.count_ones
count_zeros :: bits.count_zeros

is_power_of_two :: #force_inline proc "contextless" (x: $T) -> bool where intrinsics.type_is_integer(T) {
	return count_ones(x) == 1
}
low_mask :: #force_inline proc "contextless" (power_of_two: $T) -> T where intrinsics.type_is_unsigned(T) {
	return power_of_two - 1
}
high_mask :: #force_inline proc "contextless" (power_of_two: $T) -> T where intrinsics.type_is_unsigned(T) {
	return ~(power_of_two - 1)
}
get_bit :: #force_inline proc "contextless" (x, bit_index: $T) -> T where intrinsics.type_is_unsigned(T) {
	return (x >> bit_index) & 1
}
set_bit_one :: #force_inline proc "contextless" (x, bit_index: $T) -> T where intrinsics.type_is_unsigned(T) {
	return x | (1 << bit_index)
}
set_bit_zero :: #force_inline proc "contextless" (x, bit_index: $T) -> T where intrinsics.type_is_unsigned(T) {
	return x & ~(1 << bit_index)
}
set_bit :: #force_inline proc "contextless" (x, bit_index, bit_value: $T) -> T where intrinsics.type_is_unsigned(T) {
	x_without_bit := x & ~(1 << bit_index)
	bit := ((bit_value & 1) << bit_index)
	return x | bit
}
bit_swap :: proc(a: ^$T, b: ^T) {
    a^ ^= b^
    b^ ^= b^
    a^ ^= b^
}
// aka find_first_set()
log2_floor :: #force_inline proc "contextless" (x: $T) -> T where intrinsics.type_is_unsigned(T) {
	return x > 0 ? size_of(T) * 8 - 1 - count_leading_zeros(x) : 0
}
log2_ceil :: #force_inline proc "contextless" (x: $T) -> T where intrinsics.type_is_unsigned(T) {
	return x > 1 ? size_of(T) * 8 - 1 - count_leading_zeros((x - 1) << 1) : 0
}