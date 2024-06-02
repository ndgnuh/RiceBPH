module RiceBPH

using Distributed
using CairoMakie
using Reexport
using Colors
using JDF
using DataFrames
using Random
using Serialization
using ProgressBars
using BenchmarkTools
using Printf

include("Utils.jl")
include("ModelRewrite.jl")
include("Results.jl")
include("Visualisations.jl")
include("ofaat.jl")
include("Experiments.jl")

#= using .Results =#
#= using .Utils =#
#= @reexport using .Models =#
#= using .Visualisations =#

#= include("postprocess.jl") =#

"""
    percent_ticks(nticks; miminum = 0.0f0, maximum = 1.0f0, decimals = 0)

Return a Makie tick that formats the percentage.

## Example

    julia> percent_ticks(5)
    (Float32[0.0, 0.25, 0.5, 0.75, 1.0], ["0%", "25%", "50%", "75%", "100%"])
"""
function percent_ticks(
        nticks::Integer; minimum = 0.0f0, maximum = 1.0f0, decimals::Integer = 0)
    fmt = Printf.Format("%.$(decimals)f")
    values = range(minimum, maximum; length = nticks)
    labels = map(values) do value
        label = Printf.format(fmt, value * 100)
        return label * "%"
    end
    return (values, labels)
end

"""
    day_ticks(timesteps, daystep=20)

Return a Makie tick that formats the day from hour timestep.

## Example

    julia> day_ticks(1:2880, 30)
    ([1, 721, 1441, 2161], ["0", "30", "60", "90"])
"""
function day_ticks(timesteps, daystep = 20)
    a = minimum(timesteps)
    b = maximum(timesteps)
    values = collect(range(a, b; step = daystep * 24))
    labels = map(values) do v
        string(trunc(Int, v / 24))
    end
    return (values, labels)
end

function categorical_ticks(values)
    labels = map(string, values)
    return values, labels
end
function categorical_ticks(values, format_string)
    format = Printf.Format(format_string)
    labels = map(values) do value
        Printf.format(format, value)
    end
    return values, labels
end

"""
    stacked_barplot!(ax, x, ys; options...)

Wrapper for `barplot!` to create stacked bar plot.

# Example

    fig = Figure()
    ax = Axis(fig[1, 1])
    ylims!(ax, 0, 1)
    x = collect(1:5)
    y1 = rand(5) / 3
    y2 = rand(5) / 3
    y3 = 1 .- y1 .- y2
    ys = [y1, y2, y3]
    colormap = [:red, :green, :blue]
    stacked_barplot!(ax, x, ys; colormap)
    fig
"""
function stacked_barplot!(ax, x, ys; options...)
    allx = repeat(x, length(ys))
    ally = reduce(vcat, ys)
    n = length(x)
    groups = reduce(vcat, [fill(i, n) for i in eachindex(ys)])
    return barplot!(ax, allx, ally; color = groups, stack = groups, options...)
end

# Color map for visualization
const BPH_COLORMAP = Colors.sequential_palette(10, 4; b = 0.5)[(end - 2):end]

"""
    load_result(jdfpath)

Load JDF result dataframe and calculate the percentage values.
Return the dataframe.
"""
function load_result(dfpath)
    df = DataFrame(loadjdf(dfpath))
    df.num_nymphs = convert.(UInt32, df.num_nymphs)
    df.num_macros = convert.(UInt32, df.num_macros)
    df.num_brachys = convert.(UInt32, df.num_brachys)
    df.num_bphs = df.num_nymphs + df.num_macros + df.num_brachys
    df.pct_nymphs = df.num_nymphs ./ df.num_bphs
    df.pct_macros = df.num_macros ./ df.num_bphs
    df.pct_brachys = df.num_brachys ./ df.num_bphs
    df.has_bphs = df.num_bphs .> 0
    return df
end

"""
    load_result_dir(jdfpath)

Load multiple JDF result dataframes from a directory.
Calculate the percentage values for each of the dataframe.
Return a vector of dataframes.
"""
function load_result_dir(dpath)
    fs = joinpath.(dpath, readdir(dpath))
    filter!(isdir, fs)
    return load_result.(fs)
end

function set_makie_theme!()
    return update_theme!(;
        fonts = (;
            regular = "../fonts/NewComputerModern/NewCM10-Bold.otf",
            bold = "../fonts/NewComputerModern/NewCM10-Bold.otf"
        ),
    )
end

function run_experiment_v2(;
        output_dir::String,
        base_params::Dict,
        params::Vector{T},
        name_format_fn::Function,
        num_replications::Int = 100
) where {T <: AbstractDict}

    # Initialize RNG or reload it
    rng_path = joinpath(output_dir, "rng")
    rng = isfile(rng_path) ? deserialize(rng_path) : Xoshiro(0)

    # Num simulations
    base_params = copy(base_params)
    base_params[:rng] = rng
    total_num_simulations = length(params) * num_replications
    pbar = ProgressBar(; total = total_num_simulations)

    # Grid search
    df = Models.init_model_df()
    for param_update in params, rep in 1:num_replications
        param = merge(base_params, param_update)

        # Output path
        output_name = name_format_fn(param_update, rep)
        output_path = joinpath(output_dir, output_name)

        # Run simulation
        if !isdir(output_path)
            model = RiceBPH.Models.init_model(; param...)
            df = RiceBPH.Models.run_ricebph!(df, model)

            # Save results
            # No need to compress, we already used a good df
            #= type_compress!(df; compress_float = true) =#
            savejdf(output_path, df)

            # Save state
            serialize(rng_path, rng)
        end

        # Update
        update(pbar)
        let postfix = Dict(
                :simulation => "$(pbar.current)/$(total_num_simulations)",
                :replication => "$(rep)/$(num_replications)",
                :output_path => output_path
            )
            postfix = merge(postfix, param)

            postfix_str = join(["$(k): $(v)" for (k, v) in postfix], "\n")
            set_multiline_postfix(pbar, postfix_str)
        end
    end
end

"""
This function is the same as run_experiment_202405`, but use 1 RNG for every processes.
"""
function run_experiment_202405_mp(;
        output_dir::String,
        base_params::Dict,
        params::Vector{T},
        name_format_fn::Function,
        num_replications::Int = 100
) where {T <: AbstractDict}
    # Num simulations
    base_params = copy(base_params)
    total_num_simulations = length(params) * num_replications

    # Run parallel simulations
    futures = map(enumerate(params)) do (i, param_update)
        # Initialize and run the model
        @spawnat :any begin
            # Update parameters
            param = merge(base_params, param_update)
            rng = Xoshiro(i)

            # Run replications
            output_paths = map(1:num_replications) do rep
                output_name = name_format_fn(param_update, rep)
                output_path = joinpath(output_dir, output_name)

                if !isdir(output_path)
                    model = RiceBPH.Models.init_model(; rng, param...)
                    df = RiceBPH.Models.run_ricebph!(model)
                    df[:, :seed] = fill(rep, size(df, 1))

                    # Output path
                    JDF.savejdf(output_path, df)
                end
                return output_path
            end

            # GC or OOM
            GC.gc(false)
            return param, output_paths
        end
    end

    # Concat intermediate result and return the final one
    pbar = ProgressBar(futures)
    result_files = mapreduce(vcat, futures) do future
        update(pbar)
        param, output_path = fetch(future)
        output_path
    end

    # Save the output
    final_df = mapreduce(vcat, result_files) do output_path
        DataFrame(JDF.loadjdf(output_path))
    end
    JDF.savejdf(final_df, output_dir)

    # Cleanup
    for result_file in result_files
        rm(result_file)
    end
end
"""
    run_simulation_benchmark(; params...)

Run benchmark with customized parameters. If no parameter is input,
the baseline is used.
"""
function run_simulation_benchmark(; params...)
    base_params = (;
        init_num_bphs = 200, flower_width = 10, init_pr_eliminate = 0.2f0, energy_transfer = 0.3f0
    )
    params = merge(base_params, params)
    @benchmark begin
        model = Models.init_model(; $params...)
        Models.run_ricebph!(model)
    end
end

end # module RiceBPH
