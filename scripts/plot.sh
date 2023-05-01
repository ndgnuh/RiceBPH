#!/bin/sh
flags="--project"
if [ -f ricebph.sys.so ]; then
	flags="$flags -J ricebph.sys.so"
fi
alias plot="julia $flags scripts/plot-ofaat.jl"
for column in num_bphs pct_nymphs pct_rices pct_females; do
	plot --column $column --keepaxis \
		outputs/energy-transfer-01 figures/energy-transfer-1-$column.png
	plot --column $column --keepaxis \
		outputs/energy-transfer-02 figures/energy-transfer-2-$column.png 
	plot --column $column --keepaxis \
		outputs/energy-transfer-03 figures/energy-transfer-3-$column.png 
done
