using Statistics
using LinearAlgebra
using LsqFit
using DataFrames
using ProgressMeter

function _legitify(x, fallback)
   if isnan(x) || isinf(x)
      return fallback
   else
      return x
   end
end

function try_fit(model, x, y, base_params, names)
   fit = try
      curve_fit(model, x, y, base_params)
   catch e
      if e isa LinearAlgebra.SingularException
         (; param = base_params, converged = false)
      else
         rethrow(e)
      end
   end

   # Collect result 
   ret_p = NamedTuple(
      k => v for (k, v) in zip(names, fit.param)
   )
   ret_c = (; converged = fit.converged)
   return merge(ret_p, ret_c)
end

"""
```julia
function qcv(x)
```
The `qcv` function calculates the coefficient of dispersion (CD) for a given dataset `x` using the interquartile range (IQR).

### Parameters
- `x`: An array or collection of numerical values representing the dataset for which the CD is to be calculated.

### Returns
The function returns a single floating-point value representing the coefficient of dispersion (CD) of the dataset.

### Description
The coefficient of dispersion (CD) is a measure of the relative variability or dispersion of a dataset. It is calculated as the absolute difference between the first quartile (Q1) and the third quartile (Q3), divided by their sum.

The `qcv` function calculates the CD by first computing the first quartile `q1` and the third quartile `q3` using the `quantile` function from the `Statistics` module. The `quantile` function returns the value that corresponds to the given quantile of the dataset. In this case, `q1` represents the 25th percentile (Q1), and `q3` represents the 75th percentile (Q3).

The CD is then computed as the absolute difference between `q3` and `q1`, divided by their sum.

### Example Usage
```julia
data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
cd = qcv(data)
println("Coefficient of Dispersion: ", cd)
```

### Note
- The `quantile` function used in the `qcv` function assumes the default values for the `beta` and `alpha` parameters, which correspond to the definitions of the quartiles used in traditional statistics. However, these parameters can be adjusted if desired.
- The `qcv` function assumes that the input dataset `x` is numeric. Providing non-numeric values may result in unexpected behavior or errors.
"""
function qcv(x)
   q1 = quantile(x, 0.25; beta = 0, alpha = 0)
   q3 = quantile(x, 0.75; beta = 0, alpha = 0)
   abs((q3 - q1) / (q3 + q1))
end

function compute_global_stats(params_df, names::Vector)
   gstats = map([mean, std, minimum, maximum, qcv]) do func
      mapreduce(merge, names) do name
         Dict(
            :stat => Symbol(func),
            name => func(params_df[!, name]),
         )
      end
   end
   df = DataFrame(gstats)
   select!(df, vcat(:stat, names)) # Reordering
end

function compute_global_stats(df, factor)
   stat_names = names(df)
   filter!(!isequal("seed"), stat_names)
   mapreduce(merge, stat_names) do name
      values = filter(!ismissing, df[!, name])
      values = filter!(!isnan, values)
      values =
         Symbol(name) == factor ? unique(values) : values
      stat = map([mean, std, minimum, maximum, qcv]) do fn
         Float64(fn(values))
      end
      Dict(Symbol(name) => stat)
   end
end

function compute_factor_stats(params_df, factor, names)
   combine(groupby(params_df, factor)) do g
      compute_global_stats(g, names)
   end
end

"""
   Base.isvalid(x::Real)

The isvalid function checks whether a given floating-point number x is valid, i.e., it is neither NaN nor infinite.
"""
function Base.isvalid(x::Real)
   !(isnan(x) || isinf(x))
end

"""
"""
function fit_fn(
   fn,
   df,
   groups,
   column;
   param_name_options = NamedTuple(),
   stable_steps = false,
)
   param_names = get_param_names(fn; param_name_options...)
   param_masks = get_param_masks(fn)
   groups = groupby(df, groups)
   total = length(groups)

   # Progress bar
   # Divide the fitting process to 4 step so that it doesn't feel stuck
   pbar = Progress(total, "Fitting $(fn) on $(column):", 0)

   # Fitting the function
   combine(groups) do group
      # Collect data
      x::Vector{Float32} = convert.(Float32, group.step)
      y::Vector{Float32} =
         convert.(Float32, group[!, column])

      # Filter nan and infinities
      valid_idx = map(isvalid, y)
      x = x[valid_idx]
      y = y[valid_idx]

      # Filter steps
      x, y = if stable_steps
         ymax = argmax(y)
         steps = 1:ymax
         x[steps], y[steps]
      else
         x, y
      end

      # Initialize parameters
      params::Vector{Float32} = init_params(fn, x, y)

      # Fit function
      fit = try
         curve_fit(fn, x, y, params)
      catch
         params .= NaN32
         (; param = params, converged = false)
      end

      # Make a mapping from name to param so that DataFrames make them columns
      param_part = (
         name => value for
         (name, value, mask) in zip(param_names, fit.param, param_masks)
         if mask
      )
      converge_part = (:converged => fit.converged,)
      result = NamedTuple(
         Iterators.flatten((param_part, converge_part))
      )

      # Update progress bar
      next!(pbar)
      GC.gc()
      return result
   end
end

function q1(x)
   quantile(x, 0.25)
end

function q3(x)
   quantile(x, 0.75)
end

function compute_stats(fit_df, group_key; only_converged=true)
   # Should non-converged data be allowed
   fit_df = if only_converged
      filter(:converged => identity, fit_df)
   else
      fit_df
   end

   # Filter out meta-data column, rename the group key column
   fit_df = select(fit_df, Not(:converged))


   # Functions and column to compute statistics
   stat_fns = [maximum, minimum, mean, std, qcv, median, q1, q3]
   param_names = [name for name in names(fit_df) if name != "seed"]

   # If no groupkey, use the whole data frame
   groups = if isnothing(group_key)
      fit_df
   else
      # Else, replicate the group key column first-
      # One column is used as key and the other is used for statistics
      new_group_key = "$(group_key)_value"
      fit_df[!, new_group_key] = fit_df[!, group_key]
      groupby(fit_df, new_group_key)
   end

   # Split apply combine, each statistics
   mapreduce(merge, stat_fns) do fn
      # Each group
      result = combine(groups) do group
         # Each column in the group
         mapreduce(merge, param_names) do name
            x = filter(isvalid, group[!, name])
            NamedTuple([Symbol(name) => fn(x)])
         end
      end

      # Map dataframe with their corresponding function
      NamedTuple([Symbol(string(fn)) => result])
   end
end

function get_param_names(f; subscript=nothing, superscript=nothing)
   names = map(string, get_param_basenames(f))
   names = if isnothing(subscript)
      names
   else
      ["$(name)_$(subscript)" for name in names]
   end
   names = if isnothing(superscript)
      names
   else
      ["$(name)^$(superscript)" for name in names]
   end

   return map(Symbol, names)
end

"""
   mask_nonconverge(fit_df)

Change the row which is not converged to NaN.
"""
function mask_nonconverge(df)
    ret = select(df, Not(:converged))
    converged = df.converged
    for name in names(ret)
        x = ret[!, name]
        ret[!, name] = if isa(x, Real)
            @. x * converged + (!converged) * NaN
        else
            x
        end
    end
    return ret
end
