GEM5=~/gem5/build/X86/gem5.opt
GEM5_CONFIG_FILE=~/gem5/configs/deprecated/example/se.py
SIMPOINT=~/simpoint/bin/simpoint
TIME=/usr/bin/time

COREMARK_ARGS="-v0 -c1 -w1 -i1"

GEM5_MEMORY="--mem-size=8GiB --caches --l2cache --l1d_size=64KiB --l1i_size=64KiB"

./paramExplore.py --gem5-binary $GEM5 --gem5-configfile $GEM5_CONFIG_FILE \
	--gem5-checkpoints ./in/ \
	--gem5tomcpat ./gem5tomcpat.py --gem5tomcpat-template-warm ./template_switchcpu_x86.xml --gem5tomcpat-template-cold ./template_cold_x86.xml \
	--weightfile 125000,./in/125000.weights 16000000,./in/16000000.weights \
	--mcpat ~/mcpat/mcpat --data-out results.csv --log log.txt \
	-- -c ./bin/zip --options="$COREMARK_ARGS" --cpu-type=O3CPU $GEM5_MEMORY
