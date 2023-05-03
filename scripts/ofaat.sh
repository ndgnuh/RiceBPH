#!/bin/sh
flags="--project"
if [ -f ricebph.sys.so ]; then
	flags="$flags -J ricebph.sys.so"
fi

alias ofaat="julia $flags $@ scripts/run_ofaat.jl"
mkdir outputs -p
for config_file in configs/*.toml; do
	if [ $config_file = "test-run.toml" ]; then
		continue
	fi
	bn="$(basename $config_file .toml)"
	output_dir="outputs/$bn"
	if [ -e $output_dir ]; then
		echo "Output directory $output_dir exists, skipping"
	else
		ofaat $config_file outputs/$bn
	fi
done
