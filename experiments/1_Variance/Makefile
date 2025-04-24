GEM5 = ~/gem5/gem5/build/X86/gem5.opt
GEM5_CONFIG_FILE = ~/gem5/gem5/configs/deprecated/example/se.py
SIMPOINT = ~/simpoint/bin/simpoint

BENCHMARKS = cjpeg core linear loops nnet parser radix2 sha zip
COREMARK_ARGS = -v0 -c1 -w1 -i10

PROFILED_BBV_SIZE = 1000
SCALED_BBV_SIZES = 1000 2000 4000 8000 16000 32000

GEM5_MEMORY = --mem-size=8GiB --caches --l2cache --l1d_size=64KiB --l1i_size=64KiB

SIMPOINT_OPTIONS = -maxK 30

# trick to convert x y z to x,y,z
empty:=
space:=$(empty) $(empty)
comma:=,

.PHONY: experiment
experiment: $(BENCHMARKS:%=%.experiment)
%.experiment: $(SCALED_BBV_SIZES:%=simpoints/\%/%.bb)
	echo Experiment $* done

.PHONY: clean
clean:
	rm -rf profiling/ simpoints/

# collecting initial bbvs
.PRECIOUS: profiling/%/simpoint.bb.gz
profiling/%/simpoint.bb.gz: bin/%
	mkdir -p profiling/$*
	$(GEM5) --outdir=profiling/$* $(GEM5_CONFIG_FILE) \
		-c $< --options='$(COREMARK_ARGS)' \
		--simpoint-profile --simpoint-interval $(PROFILED_BBV_SIZE) \
		--cpu-type=AtomicSimpleCPU $(GEM5_MEMORY) \
		2> profiling/$*/err.log > profiling/$*/log.log

# scaling profiled bbv up to greater interval sizes - from a single profiled
# profiling/b/simpoint.bb.gz for some benchmark b, we produce a simpoints/b/n.bb
# for each scaled bbv size n
.PRECIOUS: $(SCALED_BBV_SIZES:%=simpoints/\%/%.bb)
$(SCALED_BBV_SIZES:%=simpoints/\%/%.bb): profiling/%/simpoint.bb.gz
	mkdir -p simpoints/$*
	gunzip $< -c | ./supersample.py --outdir simpoints/$* \
		--insize $(PROFILED_BBV_SIZE) --scaleto $(SCALED_BBV_SIZES)
