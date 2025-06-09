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
# in ascending order of simpoint index

startpoints=$(grep "\.0" $experiment/simpoints/$bench/$inter.points | awk "{print (\$1 * $inter) - $warmup}")

i=0
for instr in $startpoints
do
	if [[ $instr -lt 0 ]]
	then
		instr=0
	fi

	checkpoint_path=$(find $experiment/checkpoints/$bench/$inter -name "*_inst_${instr}_*")
	checkpoint_name=$(find $experiment/checkpoints/$bench/$inter -name "*_inst_${instr}_*" -printf "%f")
	to=$(echo $checkpoint_name | awk "{ sub(/simpoint_[0-9]+_/, \"simpoint_${i}_\"); print }")
	i=$(($i+1))
	cp -r $checkpoint_path ./in/$to
done

echo "Don't forget to renumber the checkpoints"
