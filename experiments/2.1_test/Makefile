# Path to cross-compilation lib
CROSSLIB = /home/danielg/x-tools/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot

GEM5 = ~/gem5/build/ARM/gem5.opt
GEM5_CONFIG_FILE = ~/gem5/configs/deprecated/example/se.py --interp-dir $(CROSSLIB) --redirects /lib64=$(CROSSLIB)/lib64 --redirects /lib=$(CROSSLIB)/lib --redirects /usr/lib=$(CROSSLIB)/usr/lib --redirects /usr/lib64=$(CROSSLIB)/usr/lib64
SIMPOINT = ~/simpoint/bin/simpoint
TIME = /usr/bin/time

# $(R) is the root directory of the experiment
# allows us to be in a symlink directory and reach out
R = $(shell pwd)

# coremark benchmarks to run. none contain /. all share the same arguments. symlinks in bin/ point to binaries
#BENCHMARKS = cjpeg core linear loops nnet parser radix2 sha zip
#COREMARK_ARGS = -v0 -c1 -w1 -i10

# spec benchmarks to run. None contain /. Each has a corresponding symlink in bin/ pointing to that benchmark's run folder
BENCHMARKS = spec.x264#spec.leela spec.x264

# for each spec benchmark, the binary name and flags passed to it, given by 'specinvoke -n'
BINARY.spec.leela = leela_s_base.danielg-arm-64
FLAGS.spec.leela = test.sgf
BINARY.spec.x264 = x264_s_base.danielg-arm-64
FLAGS.spec.x264 = --dumpyuv 50 --frames 156 -o BuckBunny_New.264 BuckBunny.yuv 1280x720
BINARY.spec.nab = nab_s_base.danielg-arm-64
FLAGS.spec.nab = hkrdenq 1930344093 1000

PROFILED_BBV_SIZE = 125000
SCALED_BBV_SIZES = 125000 250000 500000 1000000 2000000 4000000 8000000 16000000

GEM5_MEMORY = --mem-size=8GiB --caches --l2cache --l1d_size=64KiB --l1i_size=64KiB
# TODO: specify this properly
WARMUP = 100000

SIMPOINT_OPTIONS = -maxK 30
# size of simpoint groups used to calculate variance
SIMPOINT_N = 10

.PHONY: experiment
experiment: $(BENCHMARKS:%=%.experiment)
%.experiment: $(SCALED_BBV_SIZES:%=results/\%/%/generated) baseline/%/generated regular/%/generated
	echo Experiment $* done

.PHONY: clean
clean:
	rm -rf profiling/ $(BENCHMARKS:%=simpoints/%) checkpoints/ $(BENCHMARKS:%=baseline/%)

# collecting initial bbvs (% is a benchmark name with no /)
.PRECIOUS: profiling/%/simpoint.bb.gz
profiling/%/simpoint.bb.gz: bin/%
	mkdir -p $(@D)
	# change directory to spec run folder to execute benchmark there
	# TODO: could we replace this with a gem5 location alias (--redirects)?
	cd $< && $(TIME) -o $(R)/$(@D)/collect.time $(GEM5) \
		--outdir=$(R)/$(@D) $(GEM5_CONFIG_FILE) \
		-c ./$(BINARY.$*) --options='$(FLAGS.$*)' \
		--simpoint-profile --simpoint-interval $(PROFILED_BBV_SIZE) \
		--cpu-type=ArmAtomicSimpleCPU $(GEM5_MEMORY) \
		2> $(R)/$(@D)/err.log > $(R)/$(@D)/log.log

# scaling profiled bbv up to greater interval sizes - from a single profiled
# profiling/b/simpoint.bb.gz for some benchmark b, we produce a simpoints/b/n.bb
# for each scaled bbv size n
# % is a benchmark name (note that % is escaped in the rule target - it outputs "simpoint/%/1000.bb simpoint/%/2000.bb ...: profiling/%/simpoint.bb.gz")
.PRECIOUS: $(SCALED_BBV_SIZES:%=simpoints/\%/%.bb)
$(SCALED_BBV_SIZES:%=simpoints/\%/%.bb): profiling/%/simpoint.bb.gz
	mkdir -p $(@D)
	$(TIME) -o $(@D)/scaling.time bash -c "gunzip $< -c | ./supersample.py --outdir $(@D) \
		--insize $(PROFILED_BBV_SIZE) --scaleto $(SCALED_BBV_SIZES)"

# doing simpoint processing on points, producing clustered bbvs and distances to
# their cluster's centre
# % is a "benchmark/interval" pair
.PRECIOUS: simpoints/%.labels simpoints/%.weights
simpoints/%.labels simpoints/%.weights: simpoints/%.bb
	$(TIME) -o simpoints/$*.process.time $(SIMPOINT) -loadFVFile $< -saveLabels simpoints/$*.labels \
		-saveSimpointWeights simpoints/$*.weights $(SIMPOINT_OPTIONS) \
		> simpoints/$*.log 2>&1

# select the ten closest points for each
# % is a "benchmark/interval" pair
.PRECIOUS: simpoints/%.points simpoints/%.pweights
simpoints/%.points simpoints/%.pweights: simpoints/%.labels simpoints/%.weights
	$(TIME) -o simpoints/$*.select.time ./collectLabels.py -inLabels $< -outPoints $@ -N $(SIMPOINT_N) \
		-inWeights simpoints/$*.weights -outWeights simpoints/$*.pweights

# generate checkpoints from simpoints
# % will be of the form benchmark/interval so $(*D) and $(*F) can be used to
# benchmark name doesn't contain a /
# extract them
.PRECIOUS: checkpoints/%/generated
checkpoints/%/generated: simpoints/%.points simpoints/%.pweights
	mkdir -p $(@D)
	cd bin/$(*D) && $(TIME) -o $(R)/$(@D)/checkpointing.time $(GEM5) \
		--outdir $(R)/$(@D) $(GEM5_CONFIG_FILE) \
		-c ./$(BINARY.$(*D)) --options='$(FLAGS.$(*D))' \
		--take-simpoint-checkpoint=$(R)/$<,$(R)/simpoints/$*.pweights,$(*F),$(WARMUP) \
		--cpu-type=ArmAtomicSimpleCPU $(GEM5_MEMORY) \
		2> $(R)/$(@D)/err.log > $(R)/$(@D)/log.log
	touch $@

# run generated checkpoints
# script that parses the .points file and runs all the corresponding checkpoints
.PRECIOUS: results/%/generated
results/%/generated: simpoints/%.points checkpoints/%/generated
	mkdir -p $(@D)
	cd bin/$(*D) && $(TIME) -o $(R)/$(@D)/collection.time $(R)/runCheckpoints.py \
		--inPoints $(R)/$< --checkpointdir $(R)/checkpoints/$* \
		--outdir $(R)/$(@D) --warmup $(WARMUP) --width $(*F) \
		-- $(GEM5) $(GEM5_CONFIG_FILE) \
			-c ./$(BINARY.$(*D)) --options='$(FLAGS.$(*D))' \
			--cpu-type=ArmO3CPU $(GEM5_MEMORY) \
		2> $(R)/$(@D)/err.log > $(R)/$(@D)/log.log
	touch $@

# run baseline simulations
# full simulation to produce actual metrics for comparison
.PRECIOUS: baseline/%/generated
baseline/%/generated: bin/%
	mkdir -p $(@D)
	cd $< && $(TIME) -o $(R)/$(@D)/baseline.time $(GEM5) \
		--outdir=$(R)/$(@D) $(GEM5_CONFIG_FILE) \
		-c ./$(BINARY.$*) --options='$(FLAGS.$*)' \
		--cpu-type=ArmO3CPU $(GEM5_MEMORY) \
		2> $(R)/$(@D)/err.log > $(R)/$(@D)/log.log
	touch $@

# collect regular intervals
# tick value calculated from dividing total ticks executed by 50 to get ~50
# checkpoints from across execution to pick randomly to start from
CHECKPOINT_GAP = 800000000000
MAX_CHECKPOINT = 75
.PRECIOUS: regular/%/generated
regular/%/generated: bin/%
	mkdir -p $(@D)
	cd $< && $(TIME) -o $(R)/$(@D)/regular.time $(GEM5) \
		--outdir=$(R)/$(@D) $(GEM5_CONFIG_FILE) \
		-c ./$(BINARY.$*) --options='$(FLAGS.$*)' \
		--cpu-type=ArmAtomicSimpleCPU $(GEM5_MEMORY) \
		--take-checkpoints $(CHECKPOINT_GAP),$(CHECKPOINT_GAP) --max-checkpoints $(MAX_CHECKPOINT) \
		2> $(R)/$(@D)/err.log > $(R)/$(@D)/log.log
	touch $@
