#!/bin/bash

# Output csv headers
echo benchmark,interval,cluster,cpi,ipc

# Find every stat in the out folder
for statfile in $(find out/ -name "stats.txt")
do
	count=$(grep "switch_cpus\.cpi" $statfile | wc -l)
	if [ $count -ne 2 ]; then
		# in no-warmup case
		count_nw=$(grep "system.cpu.cpi" $statfile | wc -l)
		if [ $count -eq 0 -a $count_nw -eq 1 ]; then
			cpi=$(grep "system.cpu.cpi" $statfile | awk '{print $2;}')
			ipc=$(grep "system.cpu.ipc" $statfile | awk '{print $2;}')
		else
			echo ERROR: $statfile
			exit -1
		fi
	else
		cpi=$(grep "switch_cpus\.cpi" $statfile | tail -n 1 | awk '{print $2;}')
		ipc=$(grep "switch_cpus\.ipc" $statfile | tail -n 1 | awk '{print $2;}')
	fi

	# cut out/ and stats.txt from name
	case=$(echo $statfile | cut -d "/" -f 2-4 --output-delimiter ",")
	echo $case,$cpi,$ipc
done
