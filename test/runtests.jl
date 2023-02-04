using Test
#= using BenchmarkTools =#
using RiceBPH: init_model, AGENT_DATA, MODEL_DATA, get_plot_kwargs
using RiceBPH
using BenchmarkTools
using InteractiveUtils

RiceBPH.run_simulation(;
    seed=0,
    init_nb_bph=200,
    init_pr_eliminate=0.15,
    init_position=:corner,
    envmap="../assets/envmaps/015-1x2.csv"
)
