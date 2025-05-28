echo "interval,cpu_time"
for f in *.time
do
	echo -n ${f/\.time/}","
	grep -Po "[[:digit:]]+\.[[:digit:]]+(?=user)" $f
done
