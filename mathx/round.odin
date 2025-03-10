package mathx

import "base:intrinsics"
import "core:math"
import "core:testing"

round_up :: proc(num, multiple: int) -> int {
    if multiple == 0 do return num
    
    remainder := num % multiple
    if remainder == 0 do return num
    
    return num + multiple - remainder
}

round_down :: proc(num, multiple: int) -> int {
    if multiple == 0 do return num
    
    remainder := num % multiple
    if remainder == 0 do return num
    
    return num - remainder
}

// Round to a partial number. ie Rounding 1.30 to 1.25 with `round(1.30,0.25)`
round :: proc {
	round_f16,
	round_f32,
	round_f64,
}

round_f16 :: proc(value: f16, resolution: f16) -> f16 where intrinsics.type_is_float(f16) {
	return math.round_f16(value / resolution) * resolution
}

round_f32 :: proc(value: f32, resolution: f32) -> f32 where intrinsics.type_is_float(f32) {
	return math.round_f32(value / resolution) * resolution
}

round_f64 :: proc(value: f64, resolution: f64) -> f64 where intrinsics.type_is_float(f64) {
	return math.round_f64(value / resolution) * resolution
}

@(test)
test_round :: proc(_: ^testing.T) {
	assert(round(f16(1.26), f16(0.25)) == f16(1.25))
	assert(round(f32(1.26), f32(0.25)) == f32(1.25))
	assert(round(f64(190452), f64(10)) == f64(190450))
}