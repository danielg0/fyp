GEM5 = ~/Builds/Git/gem5/build/X86/gem5.opt
GEM5_CONFIG_FILE = ~/Builds/Git/gem5/configs/deprecated/example/se.py
SIMPOINT = ~/Builds/Local/simpoint/bin/simpoint

BENCHMARKS = cjpeg core linear loops nnet parser radix2 sha zip
COREMARK_ARGS = -v0 -c1 -w1 -i10

PROFILED_BBV_SIZE = 1000
SCALED_BBV_SIZES = 1000 2000 4000 8000 16000 32000

GEM5_MEMORY = --mem-size=8GiB --caches --l2cache --l1d_size=64KiB --l1i_size=64KiB

.PHONY: experiment
experiment: $(BENCHMARKS:%=simpoints/%/scaled.done)

.PHONY: clean
clean:
	rm -rf profiling/ simpoints/

profiling/%/simpoint.bb.gz: bin/%
	mkdir -p profiling/$*
	$(GEM5) --outdir=profiling/$* $(GEM5_CONFIG_FILE) \
		-c $< --options='$(COREMARK_ARGS)' \
		--simpoint-profile --simpoint-interval $(PROFILED_BBV_SIZE) \
		--cpu-type=AtomicSimpleCPU $(GEM5_MEMORY)


simpoints/%/scaled.done: profiling/%/simpoint.bb.gz
	mkdir -p simpoints/$*
	gunzip $< -c | ./supersample.py --outdir simpoints/$* \
		--insize $(PROFILED_BBV_SIZE) --scaleto $(SCALED_BBV_SIZES)
	touch simpoints/$*/scaled.done
