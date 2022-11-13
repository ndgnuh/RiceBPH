# Rice-BPH Model

This is a model to simulate the rice-brown plant hopper dynamic.
The goal of this model is to research the effect of cultivated flower on the spread inside rice fields of brown plant hopper (a dangerous rice pest).

## Quick start

Clone this repo:
```bash
git clone https://github.com/ndgnuh/RiceBPH
```

At the root directory, run:

```shell
julia scripts/run_explore.jl
```

The first time will take a while to install dependencies. If you have a system image with `Makie`, `GLMakie`, `InteractiveDynamics` and `Agents` precompiled, it will take significantly less time to startup the exploration.
```shell
julia -J sys.so scripts/run_explore.jl
```

