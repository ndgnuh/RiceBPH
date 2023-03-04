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

const MAP = "013-1x2.csv"
@info """
Done!
Initializing the model...
"""
model, agent_step!, model_step! = let
    model_kwargs = (seed=0,
        init_nb_bph=200,
        init_pr_eliminate=0.15,
        init_position=:corner,
        envmap=joinpath(MAPSDIR, MAP))
    init_model(; model_kwargs...)
end

# Plotting
@info """
Done!
Please wait while Julia is compiling the code for plotting.
"""
fig, obs = abmexploration(model;
    (agent_step!)=agent_step!,
    (model_step!)=model_step!,
    adata=AGENT_DATA,
    mdata=MODEL_DATA,
    get_plot_kwargs(model)...)
scene = display(fig)
wait(scene)
