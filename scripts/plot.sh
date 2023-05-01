#!/bin/sh
flags="--project"
if [ -f ricebph.sys.so ]; then
	flags="$flags -J ricebph.sys.so"
fi
alias plot="julia $flags scripts/plot-ofaat.jl"

plot_if_not_exists() {
	if [ -f $3 ]; then
		echo "$3 exists, skipping"
	else
		plot --column $1 --keepaxis $2 $3
	fi
}
for column in num_bphs pct_nymphs pct_rices pct_females; do
	plot_if_not_exists $column outputs/energy-transfer-01 figures/energy-transfer-1-$column.png
	plot_if_not_exists $column outputs/energy-transfer-02 figures/energy-transfer-2-$column.png
	plot_if_not_exists $column outputs/energy-transfer-03 figures/energy-transfer-3-$column.png
	plot_if_not_exists $column outputs/num-init-bphs/ figures/num-init-bphs-$column.png
done
