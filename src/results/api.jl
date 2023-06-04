"""
Provide a computation context and quality of life public API for the Results module.
There should be a bunch of wrapper functions associated with this struct.
"""
@kwdef struct Result
    df::DataFrame
    factor_name::Symbol
    data_names::Vector{Symbol}
end

function Result(path::AbstractString)
    df = DataFrame(JDF.load(path))
    infer_stats!(df)
    factor_name = get_factor_name(df)
    data_names = get_data_names(df)
    Result(; df, factor_name, data_names)
end

function group_fit(model::Base.Callable, result::Result, column; kw...)
    group_fit(model, result.df, column; kw...)
end
