# Plotting ultilities
using Colors
using Agents

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

const PLOT_AGENT_MARKERS = Dict(true => :circle, false => :utriangle)
const PLOT_MAP_COLOR = (nan_color=RGBA(1.0, 1.0, 0.0, 0.5),
                        colormap=[RGBA(0, 1.0, 0, i) for i in 0:0.01:1],
                        colorrange=(0, 1))
function get_plot_kwargs(model)
    return (frames=2880,
            framerate=24,
            ac=AgentColor(model),
            am=agent_marker,
            heatarray=model_heatarray,
            heatkwargs=PLOT_MAP_COLOR)
end

