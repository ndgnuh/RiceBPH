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
    EPS = eps(Float32)
    _3EPS = EPS * 3
    _2EPS = EPS * 2
    df.num_bphs = @. Float32(df.num_nymphs + df.num_brachys + df.num_macros)
    df.pct_nymphs = @. Float32((df.num_nymphs + EPS) / (df.num_bphs + _3EPS))
    df.pct_macros = @. Float32((df.num_macros + EPS) / (df.num_bphs + _3EPS))
    df.pct_brachys = @. Float32((df.num_brachys + EPS) / (df.num_bphs + _3EPS))
    df.pct_females = @. Float32((df.num_females + EPS) / (df.num_bphs + _2EPS))
    df.pct_males = @. Float32(1 - df.pct_females)
    return df
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
