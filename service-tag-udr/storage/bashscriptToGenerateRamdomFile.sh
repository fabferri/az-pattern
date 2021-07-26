#!/bin/bash

res1=$(date +%s.%N)

for counter in {1..10}
do
## 5GB
## create a file with bs*count random bytes, in our case 1048576*5120 = 5GByte
dd if=/dev/urandom of="/mnt/resource/folder/test$counter.bin" bs=1048576 count=5120
done

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

echo All done- generated $numFiles files
printf "Total runtime: %d:%02d:%02d:%02.4f\n" $dd $dh $dm $ds

