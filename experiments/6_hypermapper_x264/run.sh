GEM5=~/gem5/build/ARM/gem5.opt
GEM5_CONFIG_FILE=~/gem5/configs/deprecated/example/se.py
SIMPOINT=~/simpoint/bin/simpoint
TIME=/usr/bin/time
CROSSLIB=/home/danielg/x-tools/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot

SPEC_ARGS="--dumpyuv 50 --frames 156 -o BuckBunny_New.264 BuckBunny.yuv 1280x720"

GEM5_MEMORY="--mem-size=8GiB --caches --l2cache --l1d_size=64KiB --l1i_size=64KiB"
GEM5_CROSS="--interp-dir $CROSSLIB --redirects /lib64=$CROSSLIB/lib64 --redirects /lib=$CROSSLIB/lib --redirects /usr/lib=$CROSSLIB/usr/lib --redirects /usr/lib64=$CROSSLIB/usr/lib64"

R=$(pwd)

cd ./bin/spec.x264 && $R/paramExplore.py --gem5-binary $GEM5 --gem5-configfile $GEM5_CONFIG_FILE \
	--gem5-checkpoints $R/in/ \
	--gem5tomcpat $R/gem5tomcpat.py --gem5tomcpat-template-warm $R/template_switchcpu_x86.xml --gem5tomcpat-template-cold $R/template_cold_x86.xml \
	--weightfile 125000,$R/in/125000.weights 16000000,$R/in/16000000.weights \
	--mcpat ~/mcpat/mcpat --data-out $R/results.csv --log $R/log.txt \
	--scenario $R/scenario.json \
	-- -c ./x264_s_base.danielg-arm-64 --options="$SPEC_ARGS" --cpu-type=O3CPU $GEM5_MEMORY $GEM5_CROSS
