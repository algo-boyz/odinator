package cuda

import "core:fmt"
import "core:strings"
import "core:c"

when ODIN_OS == .Linux do foreign import foo {"add.a", "system:cudart" }

foreign foo {
    gpu_alloc :: proc "c" ( devicePtr : ^rawptr, size : int ) ---

    host_to_gpu :: proc "c" ( dst : rawptr, src : rawptr, count : int ) ---

    gpu_to_host :: proc "c" ( dst : rawptr, src : rawptr, count : int ) ---

    gpu_free :: proc "c" ( devicePtr : rawptr ) ---

    gpu_run :: proc "c" ( A : [^]f32, B : [^]f32, C : [^]f32, N : int ) ---
}

main :: proc () {
    fmt.printf("Starting CUDA...\n")

    N :: 512

    h_A : ^[N]f32 = new( [N]f32 )
    h_B : ^[N]f32 = new( [N]f32 )
    h_C : ^[N]f32 = new( [N]f32 )

    // Initialize host vectors
    for _, i in h_A {
        h_A[i] = 1;
        h_B[i] = 2;
    }

    // Allocate vectors
    d_A, d_B, d_C : [^]f32
    my_cudaMalloc( cast( ^rawptr ) & d_A, N * size_of( f32 ) )
    my_cudaMalloc( cast( ^rawptr ) & d_B, N * size_of( f32 ) )
    my_cudaMalloc( cast( ^rawptr ) & d_C, N * size_of( f32 ) )

    // Copy host vectors to device
    host_to_gpu( rawptr( d_A ), rawptr( h_A ), N * size_of( f32 ) )
    host_to_gpu( rawptr( d_B ), rawptr( h_B ), N * size_of( f32 ) )

    // Launch kernel
    gpu_run( d_A, d_B, d_C, N )

    // Copy result vector from device to host
    gpu_to_host( rawptr( h_C ), rawptr( d_C ), N * size_of( f32 ) )

    for i in 0..<(N / 50) {
        fmt.printf( "%v + %v = %v\n", h_A[i], h_B[i], h_C[i] )
    }

    // Free device memory
    gpu_free( rawptr( d_A ) )
    gpu_free( rawptr( d_B ) )
    gpu_free( rawptr( d_C ) )

    // Free host memory
    free( rawptr( h_A ) )
    free( rawptr( h_B ) )
    free( rawptr( h_C ) )

    fmt.printf("...end of program.\n")
}