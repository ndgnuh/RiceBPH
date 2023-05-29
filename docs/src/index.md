# RiceBPH Model

This is a model to simulate the rice-brown plant hopper dynamic.
The goal of this model is to research the effect of cultivated flower on the spread inside rice fields of brown plant hopper (a dangerous rice pest).

```@raw html
<video controls autoplay>
  <source src="https://github.com/ndgnuh/RiceBPH/releases/download/assets/video.mp4" type="video/mp4">
  Your browser does not support video tags
</video>
```


## Setup

This model is implemented using the Julia language, please install it from [this link](https://julialang.org/downloads/). We recommend using version Julia 1.9.

After that, setup the project's dependencies:
```shell
julia --project -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
```

[Optional] Build a "system image". A system image contains compiled code, so that Julia does not have to recompile everything everytime it runs. TLDR: this reduces latency.
```shell
julia --project scripts/build_system_image.jl
```
As far as I know, you need a working C compiler for this step. If not, try installing Julia 1.9. The 1.9 version has binary caching so it should have less latency than previous versions.

## Running the model

Here we show some simple examples.
The running scripts are placed in the `scripts/` folder.
If you wish to customize, all of the scripts have `--help` flags, which lists all the options.

Model exploration:
```shell
julia --project scripts/model_exploration.jl

# If you built a system image when setting up
julia -J ricebph.sys.so --project scripts/model_exploration.jl
```

Render a video:
```shell
julia --project scripts/run_video.jl --output video.mp4
julia -J ricebph.sys.so --project scripts/run_video.jl --output video.mp4
```

Run replication an collect data:
```shell
julia --project scripts/run_ofaat.jl configs/energy-transfer.toml outputs/energy-transfer
julia --project -J ricebph.sys.so scripts/run_ofaat.jl configs/energy-transfer.toml outputs/energy-transfer
```
If you wish to run with multiple processes (example: 8)
```shell
julia --project -p 8 scripts/run_ofaat.jl configs/energy-transfer.toml outputs/energy-transfer
```
Some example configuration files are in the `configs` folder.

## Reproduce our results

We setup tests to guarantee that our model is fully reproducible (see `test/runtests.jl`).

To reproduce the data, run the replication with these configurations (you can add `-J ricebph.sys.so` or `-p 8` to reduce runtime, but the results would be the same):
```shell
julia --project scripts/run_ofaat.jl configs/energy-transfer-01.toml outputs/energy-transfer-01
julia --project scripts/run_ofaat.jl configs/energy-transfer-02.toml outputs/energy-transfer-02
julia --project scripts/run_ofaat.jl configs/energy-transfer-03.toml outputs/energy-transfer-03
```

If you only wish to reproduce the plot, download the provided data at the release page (TBD) and run:
```shell
julia --project scripts/run_ofaat.jl --column num_bphs outputs/energy-transfer-01 figures/energy-transfer-1-num_bphs.png
julia --project scripts/run_ofaat.jl --column num_bphs outputs/energy-transfer-02 figures/energy-transfer-2-num_bphs.png
julia --project scripts/run_ofaat.jl --column num_bphs outputs/energy-transfer-03 figures/energy-transfer-3-num_bphs.png
julia --project scripts/run_ofaat.jl --column num_bphs outputs/num-init-bphs/ figures/num-init-bphs-num_bphs.png
julia --project scripts/run_ofaat.jl --column num_bphs outputs/pr-eliminate/ figures/pr-eliminate-num_bphs.png
julia --project scripts/run_ofaat.jl --column num_bphs outputs/flower-width figures/flower-width-num_bphs.png
julia --project scripts/run_ofaat.jl --column pct_nymphs outputs/energy-transfer-01 figures/energy-transfer-1-pct_nymphs.png
julia --project scripts/run_ofaat.jl --column pct_nymphs outputs/energy-transfer-02 figures/energy-transfer-2-pct_nymphs.png
julia --project scripts/run_ofaat.jl --column pct_nymphs outputs/energy-transfer-03 figures/energy-transfer-3-pct_nymphs.png
julia --project scripts/run_ofaat.jl --column pct_nymphs outputs/num-init-bphs/ figures/num-init-bphs-pct_nymphs.png
julia --project scripts/run_ofaat.jl --column pct_nymphs outputs/pr-eliminate/ figures/pr-eliminate-pct_nymphs.png
julia --project scripts/run_ofaat.jl --column pct_nymphs outputs/flower-width figures/flower-width-pct_nymphs.png
julia --project scripts/run_ofaat.jl --column pct_rices outputs/energy-transfer-01 figures/energy-transfer-1-pct_rices.png
julia --project scripts/run_ofaat.jl --column pct_rices outputs/energy-transfer-02 figures/energy-transfer-2-pct_rices.png
julia --project scripts/run_ofaat.jl --column pct_rices outputs/energy-transfer-03 figures/energy-transfer-3-pct_rices.png
julia --project scripts/run_ofaat.jl --column pct_rices outputs/num-init-bphs/ figures/num-init-bphs-pct_rices.png
julia --project scripts/run_ofaat.jl --column pct_rices outputs/pr-eliminate/ figures/pr-eliminate-pct_rices.png
julia --project scripts/run_ofaat.jl --column pct_rices outputs/flower-width figures/flower-width-pct_rices.png
julia --project scripts/run_ofaat.jl --column pct_females outputs/energy-transfer-01 figures/energy-transfer-1-pct_females.png
julia --project scripts/run_ofaat.jl --column pct_females outputs/energy-transfer-02 figures/energy-transfer-2-pct_females.png
julia --project scripts/run_ofaat.jl --column pct_females outputs/energy-transfer-03 figures/energy-transfer-3-pct_females.png
julia --project scripts/run_ofaat.jl --column pct_females outputs/num-init-bphs/ figures/num-init-bphs-pct_females.png
julia --project scripts/run_ofaat.jl --column pct_females outputs/pr-eliminate/ figures/pr-eliminate-pct_females.png
julia --project scripts/run_ofaat.jl --column pct_females outputs/flower-width figures/flower-width-pct_females.png
```

For Linux user, we provide this convenience script:
```shell
# For the data
bash scripts/ofaat.sh
# For the figures
bash scripts/plot.sh
```
