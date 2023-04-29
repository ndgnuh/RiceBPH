# Plotting ultilities
# Since visualisation packages are very slow to load,
# they are loaded lazily using Requires, so that if there are
# other tasks such as collecting statistics, they won't be loaded
# and takes tons of time.
module Visualisations

using Colors
using GLMakie
using ..Models

const FLOWER_COLOR = colorant"#FFC107"
const RICE_COLORS = RGBAf.(0.0f0, 0.8f0, 0.0f0, 0.0f0:0.001f0:1.0f0)
const AGENT_COLORS = Dict(Models.Egg => colorant"#0D47A1",
                          Models.Nymph => colorant"#D32F2F",
                          Models.Adult => colorant"#F44336")

ac(agent) = AGENT_COLORS[agent.stage]
am(_) = :circle

function heatarray(model)
    flower_mask = model.flower_mask
    @. !flower_mask * NaN32 + model.rice_map * flower_mask
end

function video(videopath::String,
               crop,
               init_nb_bph,
               position,
               pr_eliminate0;
               seed,
               frames = 2880,
               kwargs...)
    @info "Video seed: $seed"
    model = init_model(crop, init_nb_bph, position, pr_eliminate0; seed = seed, kwargs...)
    return abm_video(videopath,
                     model,
                     agent_step!,
                     model_step!;#
                     frames = frames,
                     framerate = 24,
                     ac = ac(model),
                     am = am,
                     heatarray = heatarray,
                     heatkwargs = (nan_color = (1.0, 1.0, 0.0, 0.5),
                                   colormap = [(0, 1.0, 0, i) for i in 0:0.01:1],
                                   colorrange = (0, 1)))
end

const heatkwargs = (; nan_color = FLOWER_COLOR,
                    colormap = RICE_COLORS,
                    colorrange = (0, 1))

end
