#!/usr/bin/env bash

COMMAND="prun -v -np 1 -native '-l gpu=GTX480' wave"

I_VALS=(1000 10000 1000000 10000000)
T_VALS=(1000000 500000 5000 500)

# clear the output file
echo > exp_results.txt

for ((i=0; i < 4; i++))
do
    for ((blah=0; blah < 10; blah++))
    do
    echo Doing ${I_VALS[$i]} ${T_VALS[$i]}

    echo Parameters: ${I_VALS[i]} ${T_VALS[$i]} >> exp_results.txt
    prun -v -np 1 -native '-l gpu=GTX480' wave ${I_VALS[$i]} ${T_VALS[$i]} >> exp_results.txt
    echo -e "\n" >> exp_results.txt
    done
done
