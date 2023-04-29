using RiceBPH.Models
using RiceBPH.Visualisations
using InteractiveDynamics
using BenchmarkTools
using GLMakie

const MDATA = Models.MDATA_EXPL
const model = init_model(; seed = 0,
                         map_size = 100, num_init_bphs = 200,
                         init_pr_eliminate = 0.05f0, flower_width = 0,
                         init_position = Models.Corner,
                         energy_transfer = 0.045f0)
const _, mdf = run!(model, agent_step!, model_step!, 1; mdata = MDATA)
#= @btime run!(model, agent_step!, model_step!, 2880) =#

#= const heatkwargs = (nan_color = RGBf(1.0f0, 1.0f0, 0.0f0), =#
#=                     colormap = [RGBf(0.0f0, i, 0.0f0) for i in 0.0f0:0.001f0:1.0f0], =#
#=                     colorrange = (0, 1)) =#

const heatkwargs = (;
                    nan_color = RGBAf(1.0, 1.0, 0.0, 0.5),
                    colormap = [RGBAf(0, 0.7, 0, i) for i in 0:0.01:1],
                    colorrange = (0, 1))

const fig, _ = abmexploration(model;
                              (agent_step!) = agent_step!,
                              (model_step!) = model_step!,
                              mdata = MDATA,
                              Visualisations.ac, Visualisations.heatarray,
                              Visualisations.heatkwargs)
const scene = display(fig)
wait(scene)
