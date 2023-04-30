# Rice-BPH Model

This is a model to simulate the rice-brown plant hopper dynamic.
The goal of this model is to research the effect of cultivated flower on the spread inside rice fields of brown plant hopper (a dangerous rice pest).

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

[To be done]
