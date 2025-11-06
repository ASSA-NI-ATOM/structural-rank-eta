/*
 * eta_congruent_gpu.cu — ASSA-NI Structural Rank Analyzer (FINAL OPTIMIZED 2025)
 * Author: Siarhei P. Tabalevich
 * ORCID: https://orcid.org/0009-0007-4425-9443
 * Repository: https://github.com/ASSA-NI-ATOM/structural-rank-eta
 * License: CC BY-NC 4.0
 */

#include <cuda_runtime.h>
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <limits.h>

#define CUDA_CHECK(call) do { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        fprintf(stderr, "[FATAL] CUDA error at %s:%d: %s\n", __FILE__, __LINE__, cudaGetErrorString(err)); \
        exit(EXIT_FAILURE); \
    } \
} while(0)

__device__ __forceinline__ uint64_t isqrt_uint64(uint64_t n) {
    if (n == 0) return 0;
    uint64_t x = (uint64_t)((double)n * 0.5 + 1.0);
    x = (x + n / x) >> 1;
    x = (x + n / x) >> 1;
    x = (x + n / x) >> 1;
    if (x > n / x) x--;
    return x;
}

__device__ __forceinline__ bool is_qr_mod(uint64_t val, int mod) {
    val %= mod;
    if (val == 0) return true;
    switch (mod) {
        case 3:  return val == 1;
        case 5:  return val == 1 || val == 4;
        case 7:  return val == 1 || val == 2 || val == 4;
        case 11: return val == 1 || val == 3 || val == 4 || val == 5 || val == 9;
        case 13: return val == 1 || val == 3 || val == 4 || val == 9 || val == 10 || val == 12;
        case 17: return val == 1 || val == 2 || val == 4 || val == 8 || val == 9 || val == 13 || val == 15 || val == 16;
        case 19: return val == 1 || val == 4 || val == 5 || val == 6 || val == 7 || val == 9 || val == 11 || val == 16 || val == 17;
        case 23: {
            static const uint8_t r[] = {1,2,3,4,6,8,9,12,13,16,18,22};
            #pragma unroll
            for (int i = 0; i < 12; ++i) if (val == r[i]) return true;
            return false;
        }
        case 29: {
            static const uint8_t r[] = {1,4,5,6,7,9,13,16,20,22,23,24,25,28};
            #pragma unroll
            for (int i = 0; i < 14; ++i) if (val == r[i]) return true;
            return false;
        }
        default: return false;
    }
}

__global__ void eta_congruent_kernel(
    const uint64_t T,
    const uint64_t n_start,
    const uint64_t n_end,
    uint64_t* __restrict__ d_min_eta
) {
    uint64_t eta = n_start + (uint64_t)blockIdx.x * blockDim.x + (uint64_t)threadIdx.x;
    if (eta > n_end || eta == 0) return;
    if (eta > 1518500249ULL) return;

    uint64_t d = 2 * eta - 1;
    uint64_t d2 = d * d;
    if (d2 > ULLONG_MAX - T) return;

    const int Q[9] = {3,5,7,11,13,17,19,23,29};
    bool survive = true;
    #pragma unroll
    for (int i = 0; i < 9; ++i) {
        int q = Q[i];
        uint64_t total = (T % q + d2 % q) % q;
        if (!is_qr_mod(total, q)) {
            survive = false;
            break;
        }
    }
    if (!survive) return;

    uint64_t candidate = T + d2;
    uint64_t y = isqrt_uint64(candidate);
    if (y * y == candidate) {
        atomicMin((unsigned long long*)d_min_eta, (unsigned long long)eta);
    }
}

void search_eta_chunked(uint64_t T, uint64_t n_max, uint64_t* result) {
    const uint32_t BLOCK_SIZE = 256;
    const uint64_t MAX_GRID_DIM = 65535ULL;
    const uint64_t CHUNK_SIZE = (uint64_t)BLOCK_SIZE * MAX_GRID_DIM;

    uint64_t* d_min_eta;
    CUDA_CHECK(cudaMalloc(&d_min_eta, sizeof(uint64_t)));
    uint64_t init = ULLONG_MAX;
    CUDA_CHECK(cudaMemcpy(d_min_eta, &init, sizeof(uint64_t), cudaMemcpyHostToDevice));

    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    CUDA_CHECK(cudaEventRecord(start));

    for (uint64_t n0 = 1; n0 <= n_max; n0 += CHUNK_SIZE) {
        uint64_t n1 = (n0 + CHUNK_SIZE - 1 < n_max) ? n0 + CHUNK_SIZE - 1 : n_max;
        uint32_t grid = (uint32_t)((n1 - n0 + 1 + BLOCK_SIZE - 1) / BLOCK_SIZE);
        eta_congruent_kernel<<<grid, BLOCK_SIZE>>>(T, n0, n1, d_min_eta);
        CUDA_CHECK(cudaGetLastError());
    }

    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaEventRecord(stop));
    CUDA_CHECK(cudaEventSynchronize(stop));

    CUDA_CHECK(cudaMemcpy(result, d_min_eta, sizeof(uint64_t), cudaMemcpyDeviceToHost));

    float ms = 0;
    CUDA_CHECK(cudaEventElapsedTime(&ms, start, stop));
    printf("Computation time: %.2f ms\n", ms);
    if (ms > 0.1f) {
        double thr = (double)n_max / (ms * 1000.0);
        printf("Throughput: %.2f million η/sec\n", thr);
    }

    CUDA_CHECK(cudaFree(d_min_eta));
    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <T> <n_max>\n", argv[0]);
        return 1;
    }

    uint64_t T = strtoull(argv[1], NULL, 10);
    uint64_t n_max = strtoull(argv[2], NULL, 10);
    if (n_max == 0) { fprintf(stderr, "n_max must be ≥ 1\n"); return 1; }

    printf("ASSA-NI η-Analyzer (FINAL 2025 EDITION)\n");
    printf("Author: Sergei V. Tabalevich\n");
    printf("ORCID: https://orcid.org/0009-0007-4425-9443\n");
    printf("========================================\n");
    printf("T = %" PRIu64 " (T mod 4 = %" PRIu64 ")\n", T, T % 4);
    printf("n_max = %" PRIu64 "\n", n_max);

    if (T % 4 != 3) {
        printf("⚠️  Warning: T ≢ 3 (mod 4). Result may not correspond to any η(k).\n");
    }

    int dev;
    cudaGetDevice(&dev);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, dev);
    printf("GPU: %s (sm_%d%d)\n", prop.name, prop.major, prop.minor);

    uint64_t result;
    search_eta_chunked(T, n_max, &result);

    if (result == ULLONG_MAX) {
        printf("\n✓ No η ≤ %" PRIu64 " found.\n", n_max);
    } else {
        printf("\n✗ η = %" PRIu64 " FOUND!\n", result);
        printf("  → |p - q| = %" PRIu64 "\n", 4 * result - 2);
    }

    printf("\nReproducibility meta\n");
    printf("  T = %" PRIu64 "\n", T);
    printf("  n_max = %" PRIu64 "\n", n_max);
    printf("  GPU = %s\n", prop.name);
    return 0;
}
