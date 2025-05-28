# Path to cross-compilation lib
CROSSLIB = /home/danielg/x-tools/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot

GEM5 = ~/gem5/build/X86/gem5.opt
GEM5_CONFIG_FILE = ~/gem5/configs/deprecated/example/se.py
SIMPOINT = ~/simpoint/bin/simpoint
TIME = /usr/bin/time

# benchmark to run
BENCHMARK = bin/zip
# -i picked so that 100m instructions simulated
BENCHMARK_ARGS = -v0 -c1 -w1 -i1

BBV_SIZES = 500000 1000000 1500000 2000000 2500000 3000000 3500000 4000000

GEM5_MEMORY = --mem-size=8GiB --caches --l2cache --l1d_size=64KiB --l1i_size=64KiB

.PHONY: all
all: $(BBV_SIZES:%=%.time)

.PHONY: clean
clean:
	rm -rf $(BBV_SIZES:%=%.time) workdir/

# collect bbvs for each interval size (% is an interval size
.PRECIOUS: %.time
%.time: $(BENCHMARK)
	mkdir -p workdir/$*
	$(TIME) -o $@ $(GEM5) \
		--outdir=workdir/$* $(GEM5_CONFIG_FILE) \
		-c $< --options='$(BENCHMARK_ARGS)' \
		--simpoint-profile --simpoint-interval $* \
		--cpu-type=AtomicSimpleCPU $(GEM5_MEMORY) \
		2> workdir/$*/err.log > workdir/$*/log.log
