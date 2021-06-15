 # Rice-BPH Model

This is a model to simulate the rice-brown plant hopper dynamic for my Bachelor Thesis.
The goal of this model is to research the effect of cultivated flower on the spread inside rice fields of brown plant hopper (a dangerous rice pest).

The model is written in Julia, `using Agents` package/framework.
Obviously, to use the model, Julia is required. I reccomend Julia 1.6, but 1.x should work, too.

- [Basic Usage](#basic-usage)
  - [Installation](#install)
  - [Run model from code](#run-the-model)
  - [Dash board](#dash)
- [Replication](#replication)
- [Post Processing](#postprocessing)

## Basic Usage

> If you just want to play around without digging too much about Julia and Agents, I reccommend doing the [Installation](#install) and [run the dashboard](#dash).

### <a name="install">Installation</a>

First step is clone this repo.

```bash
git clone https://github.com/ndgnuh/RiceBPH
```

Then, activate the environment and install the dependencies.

```julia
using Pkg
Pkg.activate("RiceBPB")
Pkg.instantiate()
```

### Run the model

> I recommend taking a look at [Agents.jl documentation](https://juliadynamics.github.io/Agents.jl/stable/) first.

To run the model, import `RiceBPH.Model`. Initialize the model:
```julia
model = Model.init_model(;
    envmap = joinpath("src", "maps", "012-1x2.csv"),
    pr_killed = 0.15,
    nb_bph_init = 200,
    position = :corner, # or :border
    seed = 1,
    kwargs... # we talk about this later
)
```

Then, use `run!` from `Agents`. `DataFrames` is needed to collect data.

```julia
using DataFrames
using Agents
const nsteps = 2880
adf, mdf = run!(model,
    Model.agent_step!,
    Model.model_step!,
    nsteps;
    adata = Model.adata,
    mdata = Model.mdata
)
```

About `kwargs`, these are the *model parameter*. The default ones are defined in `Model.default_parameters`.

Parameter          | Description                         | DataType            | Value
---                | ---                                 | ---                 | ---
`age_init`         | Age of transition to nymph stage    | `Integer`           | `168`
`age_reproduce`    | Age of transition to adult stage    | `Integer`           | `504`
`age_old`          | Age of transition to old stage      | `Integer`           | `600`
`age_die`          | Age of transition to death          | `Integer`           | `720`
`pr_reproduce`     | Probability of reproduction         | `Dict{Bool,Vector}` | `Dict(true => 0.188, false => 0.157)`
`pr_egg_death`     | Egg's death probability             | `AbstractFloat`     | `0.0025`
`pr_old_death`     | Old's death probability             | `AbstractFloat`     | `0.04`
`offspring_max`    | Max eggs/reproduction               | `Integer`           | `12`
`offspring_min`    | Min eggs/reproduction               | `Integer`           | `5`
`energy_max`       | Max energy                          | `AbstractFloat`     | `1.0`
`energy_transfer`  | Max energy received from eating     | `AbstractFloat`     | `0.1`
`energy_consume`   | Energy consume each step            | `AbstractFloat`     | `0.025`
`energy_move`      | Energy required for moving          | `AbstractFloat`     | `0.2`
`energy_reproduce` | Energy required for reproduction    | `AbstractFloat`     | `0.8`
`move_directions`  | Input for `walk!` (with extra step) | `Dict{Bool,Vector}` | `Dict(true => Model.neighbors_at(1), false => Model.neighbors_at(2))`

Dictionary paremter are variant wise, the long winged variant take the `false` one, and the short winged take the `true`.




### <a name="dash">Use the dash board</a>

The dash board is built with Dash.

> The code for dash board is kind of ugly to be honest.

Dash board must be run in the command line. The reason is not having to load Dash unnecessary. When run in multiprocess, it will cost `p` times the memory.

```sh
julia --project src/RiceBPH.jl
```

The command line will output the host and the port. Open it on your browser.
Inside the dash board, there will be tools for viewing `envmap`, running simulation and plot `adf`, `mdf`, a tool for generating video (based on `seed`) and a tool for viewing replication result.

## Replication

The script `replicate.jl` is used to replicate the model. Configurations are defined in [config.jl](https://github.com/ndgnuh/RiceBPH/blob/master/config.jl)
Key | Meaning 
--- | ---
`:replication` | Number of replications
`:output_directory` | Result folder
`:nprocs` | Number of process to run (if 1 then nothing happens)
`:overwrite` | Poorly implemented, please leave it as `false`
`:seed_offset` | Not implemented, ignore it please

The input is a file, in which, the last expression returns a `Vector{NamedTuple}`. Each named tuple is the input of the model (see [Run model](#run-the-model)). 
With `input.jl` as input file:

```julia
julia --project replicate.jl input.jl
```

Pre-replicated output is available in the release page. Warning: it's very heavy, 20GB when unpacked.

## Post processing

For now, please refer to the `test/runtests.jl` for how to run the post processing. 
Basically, `test_flower` tests the result to see if the flower managed to keep at least half of the rice.
The `peak` functions collect the population peaks (the local maximums of population curve) of BPH for statistics (see image).

![](https://raw.githubusercontent.com/ndgnuh/RiceBPH/master/figures/peak.png)
