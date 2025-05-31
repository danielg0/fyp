# testing sub-sampling of bbvs
# copy collected checkpoints of width $(INPUT_BBV_WIDTH) (adjust if needed) to "in/BENCHMARK"
# copy weights file to weights/BENCHMARK.weights
# TODO: automate the copying (non-trivial, requires parsing simpoints file again)

# Path to cross-compilation lib
CROSSLIB = /home/danielg/x-tools/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot

GEM5 = ~/gem5/build/X86/gem5.opt
GEM5_CONFIG_FILE = ~/gem5/configs/deprecated/example/se.py
SIMPOINT = ~/simpoint/bin/simpoint
TIME = /usr/bin/time

# $(R) is the root directory of the experiment
# allows us to be in a symlink directory and reach out
R = $(shell pwd)

# coremark benchmarks to run. none contain /. all share the same arguments. symlinks in bin/ point to binaries
BENCHMARKS = zip
# -i picked so that 100m instructions simulated
COREMARK_ARGS = -v0 -c1 -w1 -i1
#BENCHMARKS = cjpeg core linear loops nnet parser radix2 sha zip
#COREMARK_ARGS = -v0 -c1 -w1 -i10

# spec benchmarks to run. None contain /. Each has a corresponding symlink in bin/ pointing to that benchmark's run folder
#BENCHMARKS = spec.nab

# for each spec benchmark, the binary name and flags passed to it, given by 'specinvoke -n'
#BINARY.spec.leela = leela_s_base.danielg-arm-64
#FLAGS.spec.leela = ref.sgf
#BINARY.spec.x264 = x264_s_base.danielg-arm-64
#FLAGS.spec.x264 = --pass 1 --stats x264_stats.log --bitrate 1000 --frames 1000 -o BuckBunny_New.264 BuckBunny.yuv 1280x720
#BINARY.spec.nab = nab_s_base.danielg-arm-64
#FLAGS.spec.nab = 3j1n 20140317 220

GEM5_MEMORY = --mem-size=8GiB --caches --l2cache --l1d_size=64KiB --l1i_size=64KiB

# the size of the input checkpoints and outputs
INPUT_BBV_WIDTH = 4000000
SCALED_BBV_SIZES = 125000 250000 500000 1000000 2000000 4000000 8000000 16000000

.PHONY: experiment
experiment: $(BENCHMARKS:%=%.experiment)
%.experiment: $(SCALED_BBV_SIZES:%=out/\%/%/generated)
	echo Experiment $* done

.PHONY: clean
clean:
	rm -rf out/

# scale generated checkpoints
# % is a benchmark/interval tuple so we can use $(*D) and $(*F) to get the components
.PRECIOUS: out/%/generated
out/%/generated:
	mkdir -p $(R)/$(@D)
	$(TIME) -o $(R)/$(@D)/subsampling.time $(R)/downsample.py \
		--base-folder $(R)/in/$(*D) --base-width $(INPUT_BBV_WIDTH) \
		--work-folder $(R)/$(@D) --target-width $(*F) \
		-- $(GEM5) $(GEM5_CONFIG_FILE) \
			-c ./bin/$(*D) --options='$(COREMARK_ARGS)' \
			--cpu-type=O3CPU $(GEM5_MEMORY) \
		2> $(R)/$(@D)/err.log > $(R)/$(@D)/log.log
	touch $@

