# RiceBPH Model

> We are cleaning up the code for this reporsitory.
> To reproduce the result from the paper, please use this branch:
> 
> https://github.com/ndgnuh/RiceBPH/tree/paper-replicate
> 
> 

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
julia --project scripts/main.jl configs/exploration.toml

# If you built a system image when setting up
julia -J ricebph.sys.so --project scripts/main.jl configs/exploration.toml
```

Render a video:
```shell
julia --project scripts/main.jl configs/video.toml
julia -J ricebph.sys.so --project scripts/main.jl configs/video.toml
```

## Reproduce our results

We setup tests to guarantee that our model is fully reproducible (see `test/runtests.jl`).

First replicate the data:
```shell
julia --project scripts/replicate_data.jl
```
Output data will be written to `outputs`.

And then replicate the figures:
```shell
julia --project scripts/replicate_figures.jl
```
The figures will be stored in `figures`.

If the replication is too slow, try using multi-processing. It's really simple:
```shell
# Eight processes
julia -p 8 --project scripts/replicate_data.jl
```
