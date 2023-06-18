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
		args="--column $1 $2 $3 "
		shift 3
		plot $args $@
	fi
}
for column in num_bphs pct_nymphs pct_rices pct_females; do
	if [ $column = num_bphs ]; then
		extra_flags=""
	else
		extra_flags="--syncy"
	fi
	plot_if_not_exists $column outputs/energy-transfer-01 figures/energy-transfer-1-$column.png $extra_flags 
	plot_if_not_exists $column outputs/energy-transfer-02 figures/energy-transfer-2-$column.png $extra_flags 
	plot_if_not_exists $column outputs/energy-transfer-03 figures/energy-transfer-3-$column.png $extra_flags 
	plot_if_not_exists $column outputs/num-init-bphs/ figures/num-init-bphs-$column.png $extra_flags
	plot_if_not_exists $column outputs/pr-eliminate/ figures/pr-eliminate-$column.png $extra_flags
	plot_if_not_exists $column outputs/flower-width-01 figures/flower-width-01-$column.png $extra_flags 
	plot_if_not_exists $column outputs/flower-width-02 figures/flower-width-02-$column.png $extra_flags 
done
