# Plotting ultilities
# Since visualisation packages are very slow to load,
# they are loaded lazily using Requires, so that if there are
# other tasks such as collecting statistics, they won't be loaded
# and takes tons of time.
module Visualize

using Agents
using Requires

function __init__()
    @require GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a" @eval using GLMakie
    @require Colors = "5ae59095-9a9b-59fe-a467-6f913c188581" @eval using Colors
    @require InteractiveDynamics = "ec714cd0-5f51-11eb-0b6e-452e7367ff84" @eval using InteractiveDynamics
end

# Agent coloring
struct AgentColor <: Function
    model::AgentBasedModel
end

function (ac::AgentColor)(agent)
    x, y = agent.pos
    model = ac.model
    if isnan(model.food[x, y])
        RGBAf(0.0f0, 0.0f0, 0.0f0)
    elseif agent.age < model.age_init
        RGBAf(0.0f0, 0.0f0, 1.0f0)
    else
        RGBAf(1.0f0, 0.0f0, 0.0f0)
    end
end

# Agent marker
function agent_marker(agent)
    return agent.isshortwing ? :circle : :utriangle
end

# Model map
function model_heatarray(model)
    return model.food
end

function video(videopath::String,
    crop,
    init_nb_bph,
    position,
    pr_eliminate0;
    seed,
    frames=2880,
    kwargs...)
    @info "Video seed: $seed"
    model = init_model(crop, init_nb_bph, position, pr_eliminate0; seed=seed, kwargs...)
    return abm_video(videopath,
        model,
        agent_step!,
        model_step!;#
        frames=frames,
        framerate=24,
        ac=ac(model),
        am=am,
        heatarray=heatarray,
        heatkwargs=(nan_color=(1.0, 1.0, 0.0, 0.5),
            colormap=[(0, 1.0, 0, i) for i in 0:0.01:1],
            colorrange=(0, 1)))
end

function default_map_color()
    (;
        nan_color=RGBA(1.0, 1.0, 0.0, 0.5),
        colormap=[RGBA(0, 1.0, 0, i) for i in 0:0.01:1],
        colorrange=(0, 1)
    )
end

function default_agent_marker()
    Dict(true => :circle, false => :utriangle)
end

function get_plot_kwargs(model)
    return (frames=2880,
        framerate=24,
        ac=AgentColor(model),
        am=agent_marker,
        heatarray=model_heatarray,
        heatkwargs=default_map_color())
end

end
