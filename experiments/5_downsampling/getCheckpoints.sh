# bash script to pull across checkpoints from variance experiments
# handles no warmup checkpoints
# usage: ./getCheckpoints.sh EXPERIMENT BENCHMARK INTERVAL WARMUP
# TODO: better error handling

set -ev

experiment=$1
bench=$2
inter=$3
warmup=$4
echo $experiment $bench $inter $warmup


# get the start instruction for the 0th index for all the simpoint clusters
# will contain negatives because warmup

startpoints=$(grep "\.0" $experiment/simpoints/$bench/$inter.points | awk "{print (\$1 * $inter) - $warmup}")

for instr in $startpoints
do
	if [[ $instr -lt 0 ]]
	then
		instr=0
	fi

	checkpoint=$(find $experiment/checkpoints/$bench/$inter -name "*_inst_${instr}_*")
	echo $checkpoint
	cp -r $checkpoint ./in
done

echo "Don't forget to renumber the checkpoints"
