module Results

using ..Models: MDATA
using DataFrames
using StatsBase
using GLMakie
using JDF
using Chain

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

end # module Results
