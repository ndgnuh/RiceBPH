#!/bin/sh
flags="--project"
if [ -f ricebph.sys.so ]; then
	flags="$flags -J ricebph.sys.so"
fi
alias plot="julia $flags scripts/plot-ofaat.jl"
plot --column num_bphs --keepaxis \
	outputs/energy-transfer-01 figures/energy-transfer-1-num-bphs.png
plot --column num_bphs --keepaxis \
	outputs/energy-transfer-02 figures/energy-transfer-2-num-bphs.png 
plot --column pct_nymphs \
	outputs/energy-transfer-02 figures/energy-transfer-2-pct-nymphs.png 
