"""
Provide a computation context and quality of life public API for the Results module.
There should be a bunch of wrapper functions associated with this struct.
"""
@kwdef struct Result
   df::DataFrame
   factor_name::Symbol
   factor_values::Vector
   data_names::Vector{Symbol}
end

function Result(path::AbstractString)
   df = DataFrame(JDF.load(path))
   Result(df)
end

function Result(df::DataFrame)
   infer_stats!(df)
   factor_name = get_factor_name(df)
   data_names = get_data_names(df)
   factor_values = unique(df[!, factor_name])
   Result(; df, factor_name, data_names, factor_values)
end

function get_by_value(result::Result, x)
   @assert x in result.factor_values
   df = filter(result.factor_name => isequal(x), result.df)
   Result(;
          df = df,
          result.factor_name,
          factor_values = [x],
          result.data_names,
         )
end

function group_fit(
      model::Base.Callable, result::Result, column; kw...
   )
   group_fit(model, result.df, column; kw...)
end

function factor_group_fit(
      model::Base.Callable, result::Result, column; kw...
   )
   group_fit(model, result.df, column; kw...)
end
