#!/bin/bash

# Output csv headers
echo benchmark,real_cpi,real_ipc

# Find every benchmark in this directory
for bench in $(find * -maxdepth 0 -type d)
do
	cpi=$(grep "system.cpu.cpi" ./$bench/stats.txt | tail -n 1 | awk '{print $2;}')
	ipc=$(grep "system.cpu.ipc" ./$bench/stats.txt | tail -n 1 | awk '{print $2;}')
	echo $bench,$cpi,$ipc
done
