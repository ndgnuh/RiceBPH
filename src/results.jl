module Results

using ..Models: MDATA
using DataFrames
using StatsBase
using GLMakie
using JDF
using Chain
using Printf

"""
    infer_stats!(df:DataFrame)

Calculate inferable statistics from the result dataframe.
Return the data frame. This function is inplace.
The inferable statistics are:

- num_bphs: total number of BPHs
- pct_nymphs: percentage of nymphs
- pct_macros: percentage of macros
- pct_bracys: percentage of bracys
- pct_females percentage of females BPH
- pct_males: percentage of males BPH

Eggs are not counted in the calculations.
"""
function infer_stats!(df)
    df.num_bphs = @. Float32(df.num_nymphs + df.num_brachys + df.num_macros)
    df.pct_nymphs = @. Float32((df.num_nymphs + eps(Float32)) /
                               (df.num_bphs + 3 * eps(Float32)))
    df.pct_macros = @. Float32((df.num_macros + eps(Float32)) /
                               (df.num_bphs + 3 * eps(Float32)))
    df.pct_brachys = @. Float32((df.num_brachys + eps(Float32)) /
                                (df.num_bphs + 3 * eps(Float32)))
    df.pct_females = @. Float32((df.num_females + eps(Float32)) /
                                (df.num_bphs + 2 * eps(Float32)))
    df.pct_males = @. Float32(1 - df.pct_females)
    df.pct_bphs = Float32.(df.num_bphs ./ maximum(df.num_bphs))
    return df
end

"""
    get_stat(df::DataFrame, column::Symbol)

Return a dataframe contains the aggregated statistics of `df[!, column]` 
along the `seed` columns (along replications).
The returned dataframe has these colums:
- step
- mean
- std
- min
- max
- median
"""
function get_stat(df, column)
    combine(groupby(df, :step),
            column => mean => :mean,
            column => std => :std,
            column => minimum => :min,
            column => maximum => :max,
            column => median => :median)
end

"""
    get_factor_name(df::DataFrame)::Symbol

Return the variable factor from the OFAAT result.
"""
function get_factor_name(df)
    @chain begin
        (Symbol(name) for name in names(df))
        Iterators.filter(!in(MDATA), _)
        Iterators.filter(!=(:seed), _)
        Iterators.filter(!=(:step), _)
        first
    end
end

"""
    get_data_names(df::DataFrame)

Return a vector of the names of the data columns.
"""
function get_data_names(df)
    factor = Symbol(get_factor_name(df))
    @chain begin
        (Symbol(name) for name in names(df))
        Iterators.filter(!=(:seed), _)
        Iterators.filter(!=(:step), _)
        Iterators.filter(!=(factor), _)
        collect
    end
end

"""
    get_stats(df)

Get statistics over all replications of each parameter from the OFAAT result.
"""
function get_stats(df; stable = false)
    factor = get_factor_name(df)
    data_names = get_data_names(df)
    stats = combine(groupby(df, factor)) do group
        steps = if stable
            get_stable_bph_timesteps(group.num_bphs)
        else
            Colon()
        end
        group_stats = mapreduce(merge, data_names) do column
            X = group[steps, column]
            μ = mean(X)
            σ = std(X)
            a = minimum(X)
            b = maximum(X)
            return Dict(column => (; μ, σ, a, b))
        end
        # Need to convert to named tuple so 
        # that it spreads to multiple columns
        return NamedTuple(group_stats)
    end
    return stats
end

"""
    load(path_to_jdf_folder)

Load the result, apply some inference on the results (to get extra statistics).
Return the a dataframe of the results.
"""
function load(path)
    df = DataFrame(JDF.load(path))
    infer_stats!(df)
end

"""
    get_stable_bph_timesteps(num_bphs)

Return a range of timesteps where the population of BPHs is stable.
This time period is defined as a week before the BPH population peak.
"""
function get_stable_bph_timesteps(num_bphs::Vector)
    value, t2 = findmax(num_bphs)
    t1 = t2 - 7 * 24
    @assert t1 > 0
    return t1:t2
end
function get_stable_bph_timesteps(df::AbstractDataFrame)
    get_stable_bph_timesteps(get_stat(df, :num_bphs).mean)
end

@enum Preset begin
    MeanStd
    MinMax
end

function get_analysis(group, column, step, ::Val{MeanStd})
    μ = mean(group[step, column])
    σ = std(group[step, column])
    return @sprintf "%.3f ± %.3f" μ σ
end
function get_analysis(group, column, step, ::Val{MinMax})
    x = group[step, column]
    a = minimum(x)
    b = maximum(x)
    return @sprintf "[%.3f, %.3f]" a b
end
function get_analysis(group, column, step, preset::Preset)
    get_analysis(group, column, step, Val(preset))
end

function show_analysis(df::DataFrame, preset::Int; k...)
    show_analysis(df, Preset(preset); k...)
end

function show_analysis(df::DataFrame, preset::Nothing; k...)
    result = reduce(vcat,
                    [
                        show_analysis(df, MeanStd; k...),
                        show_analysis(df, MinMax; k...),
                    ])
    sort(result, get_factor_name(df))
end

function show_analysis(df::DataFrame, preset::Preset;
                       stable_steps::Bool = false)
    #
    # Analyse per value of the factor
    #
    factor = get_factor_name(df)
    groups = groupby(df, factor)
    values = [getproperty(key, factor) for key in keys(groups)]

    #
    # Which time step to view data?
    #
    steps = if stable_steps
        [get_stable_bph_timesteps(group) for group in groups]
    else
        [Colon() for _ in groups]
    end

    #
    # Collect the result format base on preset
    #
    result = DataFrame(factor => values)
    for column in names(df)
        if column in ["step", "seed", String(factor)] || startswith(column, "num_")
            continue
        end
        result[!, column] = map(zip(steps, Tuple(groups))) do (step, group)
            get_analysis(group, column, step, preset)
        end
    end

    return result
end

end # module Results
