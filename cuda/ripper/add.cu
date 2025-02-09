#include <cuda_runtime.h>
#include <stdio.h>

__global__ void vectorAdd(const float *A, const float *B, float *C, int numElements) {
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < numElements) {
        C[i] = A[i] + B[i];
    }
}

extern "C" void gpu_alloc(void** devicePtr, size_t size) {
    cudaMalloc((void**)devicePtr, size);
}

extern "C" void host_to_gpu(void* dst, const void* src, size_t count) {
    cudaMemcpy(dst, src, count, cudaMemcpyHostToDevice);
}

extern "C" void gpu_to_host(void* dst, const void* src, size_t count) {
    cudaMemcpy(dst, src, count, cudaMemcpyDeviceToHost);
}

extern "C" void gpu_free(void* devicePtr) {
    cudaFree(devicePtr);
}

extern "C" void gpu_run(const float *A, const float *B, float *C, int N) {
    int threadsPerBlock = 256;
    int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    vectorAdd<<<blocksPerGrid, threadsPerBlock>>>(A, B, C, N);
    cudaDeviceSynchronize();
}