#!/bin/bash

filename=/dev/disk/by-id/wwn-0x6f01faf000dcec2200004bd4555467b9
runtime=1
group="default"

uniform()
{
	local val="$1"
	local extra=""

	if [ "${val%KB*}" != "$val" ]; then
		echo "scale=2; ${val%KB*}/1024" | bc -l
		return 0
	fi

	if [ "${val%MB*}" != "$val" ]; then
		echo ${val%MB*}
		return 0
	fi

	if [ "${val%GB*}" != "$val" ]; then
		echo "scale=2; ${val%GB*}*1024" | bc -l
		return 0
	fi

	if [ "${val%B*}" != "$val" ]; then
		echo "scale=2; ${val%B*}/1024/1024" | bc -l
		return 0
	fi

	echo $val
}

parseRW()
{
	local action="$1"
	shift

	local blk=$(echo "$@" | grep -P -A1 "$action\s*:")
	local io="0"
	local bw="0"
	local iops="0"
	local latmin="0"
	local latmax="0"
	local latavg="0"
	if [ -n "$blk" ]; then
		io=$(echo "$blk" | sed -n  's/.*io=\([^,]*\).*/\1/p')
		io=$(uniform $io)
		bw=$(echo "$blk" | sed -n  's/.*bw=\([^,]*\).*/\1/p')
		bw=$(uniform $bw)
		iops=$(echo "$blk" | sed -n  's/.*iops=\([^,]*\).*/\1/p')
		latmin=$(echo "$blk" | sed -n  's/.*min=\([^,]*\).*/\1/p')
		latmax=$(echo "$blk" | sed -n  's/.*max=\([^,]*\).*/\1/p')
		latavg=$(echo "$blk" | sed -n  's/.*avg=\([^,]*\).*/\1/p')
	fi

	echo "$io $bw $iops $latmin $latmax $latavg"
}

parseCPU()
{
	local blk=$(echo "$@" | grep -P "cpu\s*:")
	local usr="0"
	local sys="0"
	local ctx="0"
	if [ -n "$blk" ]; then
		usr=$(echo "$blk" | sed -n  's/.*usr=\([^,]*\).*/\1/p')
		sys=$(echo "$blk" | sed -n  's/.*sys=\([^,]*\).*/\1/p')
		ctx=$(echo "$blk" | sed -n  's/.*ctx=\([^,]*\).*/\1/p')
	fi

	echo "${usr%\%*} ${sys%\%*} $ctx"
}

run()
{
	local ioengine="$1"
	local direct="$2"
	local rw="$3"
	local bs="$4"
	local iodepth="$5"
	local numjobs="$6"
	local name="$ioengine-$direct-$rw-$bs-$iodepth-$numjobs"

	local cmd="fio -filename=$filename -rw=$rw -bs=$bs -iodepth=$iodepth -direct=$direct -time_based -thread -ioengine=$ioengine -numjobs=$numjobs -runtime=$runtime -group_reporting -name=name"

	echo -e -n "$group $name $@ \t"
	local res="$($cmd)"
	# usr sys ctx      r-io r-bw r-iops r-latmin r-latmax r-latavg     w-io w-bw w-iops w-latmin w-latmax w-latavg
	echo -e "$(parseCPU "$res") \t$(parseRW 'read' "$res") \t\t$(parseRW 'write' "$res")"
}

v1()
{
	for ioengine in "sync" "libaio"; do 
		for direct in "0" "1"; do 
			for rw in "read" "randread" "write" "randwrite" "randrw"; do 
			    for bs in "4k" "8k" "32k" "2048k"; do
			    	for iodepth in 1 32 64 128; do
			    		for numjobs in 1 8 32 64; do
			    			run "$ioengine" "$direct" "$rw" "$bs" "$iodepth" "$numjobs"
			    		done
			    	done
			    done
	        done
	    done
	done
}

v2()
{
	for ioengine in "sync" "libaio"; do 
		for direct in "1"; do 
			for rw in "read" "randread" "write" "randwrite"; do 
			    for bs in "4k" "2048k"; do
			    	for iodepth in 128; do
			    		for numjobs in 8 32; do
			    			run "$ioengine" "$direct" "$rw" "$bs" "$iodepth" "$numjobs"
			    		done
			    	done
			    done
	        done
	    done
	done
}

main()
{
	if [ -n "$1" ]; then
		group="$1"
	fi
	if [ -n "$2" ]; then
		filename="$2"
	fi
	if [ -n "$3" ]; then
		runtime="$3"
	fi

	echo -e "group name ioengine direct rw bs iodepth numjobs \tusr sys ctx \t\tr-io r-bw r-iops r-latmin r-latmax r-latavg \tw-io w-bw w-iops w-latmin w-latmax w-latavg"
	v2
}

main "$@"
