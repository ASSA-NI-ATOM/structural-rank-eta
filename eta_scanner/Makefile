NVCC = nvcc
CUDA_ARCH = sm_86

all: eta_congruent_gpu

eta_congruent_gpu: eta_congruent_gpu.cu
	$(NVCC) -O3 --use_fast_math -arch=$(CUDA_ARCH) -o $@ $<

clean:
	rm -f eta_congruent_gpu

.PHONY: all clean
