@option struct ModelExploration
    params::Models.ModelParameters
    seed::Maybe{Int}
end

@option struct ModelVideo
    params::Models.ModelParameters
    video_output::String
    num_steps::Int = 2880
    spu::Int = 1
    framerate::Int = 60
    seed::Maybe{Int} = nothing
end

@option struct ModelOFAT
    factor::String
    values::String
    output::String
    num_replications::Int
    num_steps::Int
    params::Dict
end

SupportedConfig = Union{ModelExploration,
                        ModelVideo, Vector{ModelVideo},
                        ModelOFAT, Vector{ModelOFAT},
                        PlotMeanStdTimeStep, Vector{PlotMeanStdTimeStep}}
@option struct RunConfig
    config::SupportedConfig
end
