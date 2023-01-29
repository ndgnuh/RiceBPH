# This scripts calculate statistics
# from saved results
# input: results directory
# output: statistic file
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using JLD2

using Serialization
using ProgressMeter
using Comonicon
using RiceBPH
using DataFrames
using Parameters
using Statistics

@with_kw struct ReplicationStatistic
    mean_pct_healthy_rice::Float32
    std_pct_healthy_rice::Float32
    num_outcomes::Int32
    num_good_outcomes::Int32
    num_peaks::Int32
    first_peak::Float32
    second_peak::Float32
    first_peak_value::Float32
    second_peak_value::Float32
    peaks_time_diff::Float32
    peaks_value_diff::Float32
end


function replication_statistic(;
    populations, rices,
    good_threshold::AbstractFloat=0.45f0,
    only_good=false,
    only_bad=false
)
    @assert !(only_good == only_bad == true)
    # Food related statistics
    pct_healthy_rices = map(rices) do R
        R[end] / R[begin]
    end
    good_outcomes = pct_healthy_rices .>= good_threshold
    populations, rices = if only_good
        populations[good_outcomes], rices[good_outcomes]
    elseif only_bad
        bad_outcomes = .!(good_outcomes)
        populations[bad_outcomes], rices[bad_outcomes]
    else
        populations, rices
    end
    num_outcomes = length(populations)
    num_good_outcomes = count(good_outcomes)

    # BPH related statistics
    peaks = RiceBPH.batch_peak_populations(populations)
    num_peaks = length(peaks)
    first_peak = first(peaks)
    second_peak = first(Iterators.drop(peaks, 1))
    first_peak_value = 0
    second_peak_value = 0
    peaks_time_diff = second_peak - first_peak
    peaks_value_diff = second_peak_value - first_peak_value

    return ReplicationStatistic(;
        mean_pct_healthy_rice=mean(pct_healthy_rices),
        std_pct_healthy_rice=std(pct_healthy_rices),
        num_outcomes, num_good_outcomes,
        num_peaks,
        first_peak, second_peak,
        first_peak_value, second_peak_value,
        peaks_time_diff, peaks_value_diff
    )
end

#= @info "Loading data" =#
#= const populationss, ricess = let =#
#=     df = jldopen("results/envmap=012-1x2.csv-init_nb_bph=20-init_position=border-init_pr_eliminate=0.15.jld2") do io =#
#=         ((io["results"])) =#
#=     end =#
#=     populationss = [df.count_is_alive for df in df] =#
#=     ricess = [df.num_healthy_rice for df in df] =#
#=     populationss, ricess =#
#= end =#

#= @info "Calculating" =#
#= replication_statistic(; populations=populationss, rices=ricess, only_good=true) =#
#= @info "="^30 =#
#= replication_statistic(; populations=populationss, rices=ricess, only_good=true) =#

@main function main(result_dir::AbstractString, output_file::String)
    files = joinpath.(result_dir, readdir(result_dir))
    results = []
    sizehint!(results, length(files))
    @showprogress for file in files
        io = jldopen(file)
        params = io["params"]
        rep_results = io["results"]
        close(io)
        populations = [df.count_is_alive for df in rep_results]
        rices = [df.num_healthy_rice for df in rep_results]
        stats = replication_statistic(;
            populations=populations,
            rices=rices
            #= only_good=true =#
        )
        stats_tuple = NamedTuple(
            k => getproperty(stats, k) for k in propertynames(stats)
        )
        push!(results, merge(params, stats_tuple))
        GC.gc()
    end
    stats_df = DataFrame(results)
    serialize(output_file, stats_df)
end
