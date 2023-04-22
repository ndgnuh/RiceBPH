const BASEDIR = joinpath(@__DIR__, "..")
const MAPSDIR = joinpath(BASEDIR, "assets", "envmaps")
using Pkg
Pkg.activate(BASEDIR)

# Installing dependencies
@info """
Installing dependencies...
This will take a if this is the first time this script is ran.
"""
Pkg.instantiate()

# Actual works here
@info """
Done!
Compiling and loading packages...
"""
using RiceBPH: init_model, AGENT_DATA, MODEL_DATA
using RiceBPH.Visualize: get_plot_kwargs
using GLMakie
using InteractiveDynamics

#= if !isnothing(get(ENV, "NO_SCATTER", nothing)) =#
#=     @info "Disabling scatter so that it won't lag" =#
#= end =#
function GLMakie.scatter!(a...; b...)
end

const MAP = "nf-300.csv"
const MAP = "006-1x2.csv"
@info """
Done!
Initializing the model...
"""
const INIT_NB_BPH = 200
const ENERGY_TRANSFER = 0.05f0
const ENERGY_CONSUME = ENERGY_TRANSFER / 3 # eat, move, reproduce
model, agent_step!, model_step! = let
    model_kwargs = (;
        seed=0,
        init_nb_bph=INIT_NB_BPH,
        init_pr_eliminate=0.05f0,
        energy_transfer=ENERGY_TRANSFER,
        energy_consume=ENERGY_CONSUME,
        moving_speed_shortwing=1,
        moving_speed_longwing=1,
        init_position="corner",
        envmap=joinpath(MAPSDIR, MAP))
    init_model(; model_kwargs...)
end

# Plotting
@info """
Done!
Please wait while Julia is compiling the code for plotting.
"""
abm_video(
    "video.mp4",
    model,
    agent_step!,
    model_step!;
    #= adata=AGENT_DATA, =#
    get_plot_kwargs(model)...)
