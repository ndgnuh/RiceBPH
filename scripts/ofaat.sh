#!/bin/sh
flags="--project"
if [ -f ricebph.sys.so ]; then
	flags="$flags -J ricebph.sys.so"
fi
alias ofaat="julia $flags $@ scripts/plot-ofaat.jl"
mkdir outputs -p
ofaat configs/energy-transfer-01.toml outputs/energy-transfer-01
ofaat configs/energy-transfer-02.toml outputs/energy-transfer-02
