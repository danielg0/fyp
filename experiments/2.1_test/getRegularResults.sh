echo "benchmark,interval,index,ipc,cpi"
for file in $(find ./reg_results/ -name "stats.txt")
do
	case=$(echo $file | cut -d "/" -f 2-5)
	ipc=$(grep system.switch_cpus_1.ipc $file | awk '{print $2;}')
	cpi=$(grep system.switch_cpus_1.cpi $file | awk '{print $2;}')
	echo ${case////,},${ipc},${cpi}
done
