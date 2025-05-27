#!/bin/bash

# Output csv headers
echo benchmark,interval,cluster,index,cpi,ipc

# Find every experiment in this directory
for p in $(find * -maxdepth 3 -mindepth 3 -type d)
do
	count=$(grep "switch_cpus\.cpi" $p/stats.txt | wc -l)
	if [ $count -ne 2 ]; then
		# in no-warmup case
		count_nw=$(grep "system.cpu.cpi" $p/stats.txt | wc -l)
		if [ $count -eq 0 -a $count_nw -eq 1 ]; then
			cpi=$(grep "system.cpu.cpi" $p/stats.txt | awk '{print $2;}')
			ipc=$(grep "system.cpu.ipc" $p/stats.txt | awk '{print $2;}')
		else
			echo ERROR: %p
			exit -1
		fi
	else
		cpi=$(grep "switch_cpus\.cpi" $p/stats.txt | tail -n 1 | awk '{print $2;}')
		ipc=$(grep "switch_cpus\.ipc" $p/stats.txt | tail -n 1 | awk '{print $2;}')
	fi

	echo ${p////,},$cpi,$ipc
done
