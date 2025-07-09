package omath

import "base:intrinsics"
import "core:math"
import "core:testing"

round_up :: proc(num, multiple: $T) -> T where intrinsics.type_is_numeric(T) {
    if multiple == 0 do return num
    
    remainder := num % multiple
    if remainder == 0 do return num
    
    return num + multiple - remainder
}

round_down :: proc(num, multiple: $T) -> T where intrinsics.type_is_numeric(T) {
    if multiple == 0 do return num
    
    remainder := num % multiple
    if remainder == 0 do return num
    
    return num - remainder
}

round :: proc(value, resolution: $T) -> T where intrinsics.type_is_numeric(T) {
	return math.round(value / resolution) * resolution
}

@(test)
test_round :: proc(_: ^testing.T) {
	assert(round(f16(1.26), f16(0.25)) == f16(1.25))
	assert(round(f32(1.26), f32(0.25)) == f32(1.25))
	assert(round(f64(190452), f64(10)) == f64(190450))
}