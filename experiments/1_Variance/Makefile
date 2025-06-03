GEM5 = ~/gem5/build/X86/gem5.opt
GEM5_CONFIG_FILE = ~/gem5/configs/deprecated/example/se.py
SIMPOINT = ~/simpoint/bin/simpoint
TIME = /usr/bin/time

BENCHMARKS = cjpeg core linear loops nnet parser radix2 sha#zip
COREMARK_ARGS = -v0 -c1 -w1 -i10

PROFILED_BBV_SIZE = 1000
SCALED_BBV_SIZES = 1000 2000 4000 8000 16000 32000

GEM5_MEMORY = --mem-size=8GiB --caches --l2cache --l1d_size=64KiB --l1i_size=64KiB
# TODO: specify this properly
WARMUP = 1000

SIMPOINT_OPTIONS = -maxK 30
# size of simpoint groups used to calculate variance
SIMPOINT_N = 10

# trick to convert x y z to x,y,z
empty:=
space:=$(empty) $(empty)
comma:=,

.PHONY: experiment
experiment: $(BENCHMARKS:%=%.experiment)
%.experiment: $(SCALED_BBV_SIZES:%=results/\%/%/generated) baseline/%/generated
	echo Experiment $* done

.PHONY: clean
clean:
	rm -rf profiling/ $(BENCHMARKS:%=simpoints/%) checkpoints/ $(BENCHMARKS:%=baseline/%)

# collecting initial bbvs
.PRECIOUS: profiling/%/simpoint.bb.gz
profiling/%/simpoint.bb.gz: bin/%
	mkdir -p $(@D)
	$(TIME) -o $(@D)/collect.time $(GEM5) \
		--outdir=$(@D) $(GEM5_CONFIG_FILE) \
		-c $< --options='$(COREMARK_ARGS)' \
		--simpoint-profile --simpoint-interval $(PROFILED_BBV_SIZE) \
		--cpu-type=AtomicSimpleCPU $(GEM5_MEMORY) \
		2> $(@D)/err.log > $(@D)/log.log

# scaling profiled bbv up to greater interval sizes - from a single profiled
# profiling/b/simpoint.bb.gz for some benchmark b, we produce a simpoints/b/n.bb
# for each scaled bbv size n
.PRECIOUS: $(SCALED_BBV_SIZES:%=simpoints/\%/%.bb)
$(SCALED_BBV_SIZES:%=simpoints/\%/%.bb): profiling/%/simpoint.bb.gz
	mkdir -p $(@D)
	$(TIME) -o $(@D)/scaling.time bash -c "gunzip $< -c | ./supersample.py --outdir $(@D) \
		--insize $(PROFILED_BBV_SIZE) --scaleto $(SCALED_BBV_SIZES)"

# doing simpoint processing on points, producing clustered bbvs and distances to
# their cluster's centre
.PRECIOUS: simpoints/%.labels simpoints/%.weights
simpoints/%.labels simpoints/%.weights: simpoints/%.bb
	$(TIME) -o simpoints/$*.process.time $(SIMPOINT) -loadFVFile $< -saveLabels simpoints/$*.labels \
		-saveSimpointWeights simpoints/$*.weights $(SIMPOINT_OPTIONS) \
		> simpoints/$*.log 2>&1

# select the ten closest points for each
.PRECIOUS: simpoints/%.points simpoints/%.pweights
simpoints/%.points simpoints/%.pweights: simpoints/%.labels simpoints/%.weights
	$(TIME) -o simpoints/$*.select.time ./collectLabels.py -inLabels $< -outPoints $@ -N $(SIMPOINT_N) \
		-inWeights simpoints/$*.weights -outWeights simpoints/$*.pweights

# generate checkpoints from simpoints
# % will be of the form benchmark/interval so $(*D) and $(*F) can be used to
# extract them
.PRECIOUS: checkpoints/%/generated
checkpoints/%/generated: simpoints/%.points simpoints/%.pweights
	mkdir -p $(@D)
	$(TIME) -o $(@D)/checkpointing.time $(GEM5) \
		--outdir $(@D) $(GEM5_CONFIG_FILE) \
		-c bin/$(*D) --options='$(COREMARK_ARGS)' \
		--take-simpoint-checkpoint=$<,simpoints/$*.pweights,$(*F),$(WARMUP) \
		--cpu-type=AtomicSimpleCPU $(GEM5_MEMORY) \
		2> $(@D)/err.log > $(@D)/log.log
	touch $@

# run generated checkpoints
# script that parses the .points file and runs all the corresponding checkpoints
.PRECIOUS: results/%/generated
results/%/generated: simpoints/%.points checkpoints/%/generated
	mkdir -p $(@D)
	$(TIME) -o $(@D)/collection.time ./runCheckpoints.py \
		--inPoints $< --checkpointdir checkpoints/$* \
		--outdir $(@D) --warmup $(WARMUP) --width $(*F) \
		-- $(GEM5) $(GEM5_CONFIG_FILE) \
			-c bin/$(*D) --options='$(COREMARK_ARGS)' \
			--cpu-type=O3CPU $(GEM5_MEMORY) \
		2> $(@D)/err.log > $(@D)/log.log
	touch $@

# run baseline simulations
# full simulation to produce actual metrics for comparison
.PRECIOUS: baseline/%/generated
baseline/%/generated: bin/%
	mkdir -p $(@D)
	$(TIME) -o $(@D)/baseline.time $(GEM5) \
		--outdir=$(@D) $(GEM5_CONFIG_FILE) \
		-c $< --options='$(COREMARK_ARGS)' \
		--cpu-type=O3CPU $(GEM5_MEMORY) \
		2> $(@D)/err.log > $(@D)/log.log
	touch $@
