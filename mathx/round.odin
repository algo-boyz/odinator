package mathx

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