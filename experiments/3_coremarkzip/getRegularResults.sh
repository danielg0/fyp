echo "benchmark,interval,index,ipc,cpi,cputime"
for file in $(find ./reg_results/ -name "stats.txt")
do
	timing=${file/stats.txt/random.time}
	cputime=$(grep -Po "\d+\.\d+(?=user)" $timing)
	case=$(echo $file | cut -d "/" -f 3-5)
	ipc=$(grep system.switch_cpus_1.ipc $file | awk '{print $2;}')
	cpi=$(grep system.switch_cpus_1.cpi $file | awk '{print $2;}')
	echo ${case////,},${ipc},${cpi},${cputime}
done
