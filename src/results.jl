module Results

using ..Models: MDATA
using DataFrames
using StatsBase
using GLMakie
using JDF
using Chain

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

function get_stat(df, column)
    combine(groupby(df, :step),
            column => mean => :mean,
            column => std => :std,
            column => minimum => :min,
            column => maximum => :max)
end

function get_factor_name(df)
    @chain begin
        (Symbol(name) for name in names(df))
        Iterators.filter(!in(MDATA), _)
        Iterators.filter(!=(:seed), _)
        Iterators.filter(!=(:step), _)
        first
    end
end

function load(path)
    df = DataFrame(JDF.load(path))
    infer_stats!(df)
end

end # module Results
