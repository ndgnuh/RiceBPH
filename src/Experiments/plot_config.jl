@option struct PlotMeanStdTimeStep
    data::String
    column::String
    output::String
    normalize_y::Bool
    stable_steps::Bool
    band_alpha::Float32 = 0.15f0
end

@option struct PlotMeanStdGrid
    data::String
    column::String
    output::String
    normalize_y::Bool
    sync_y::Bool
    stable_steps::Bool
    band_alpha::Float32 = 0.15f0
end
