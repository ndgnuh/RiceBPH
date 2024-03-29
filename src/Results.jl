module Results

using ..Models: MDATA, ModelParameters
using ..Utils: latex_name
using DataFrames
using StatsBase
using GLMakie
using JDF
using Chain
using Printf
using Latexify
using Colors
using Printf: @format_str, format
using LaTeXStrings

const STAT_NAME = Symbol("--")
const STAT_QCV = :QCV
const STAT_MEAN = :Mean
const STAT_STD = :Std
const STAT_MINIMUM = :Min
const STAT_MAXIMUM = :Max

include("results/jdf.jl")
include("results/fn_fitting.jl")
include("results/fn_logistic.jl")
include("results/fn_damping_sine.jl")
include("results/fn_step_logistic.jl")
include("results/fn_bell.jl")
include("results/sobol.jl")
include("results/api.jl")
include("results/latexify.jl")
include("results/viz_colorscheme.jl")
include("results/viz.jl")
include("results/fit_rices.jl")
include("results/fit_bphs.jl")

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
   result = reduce(
      vcat,
      [
         show_analysis(df, MeanStd; k...),
         show_analysis(df, MinMax; k...),
      ],
   )
   sort(result, get_factor_name(df))
end

function show_analysis(
   df::DataFrame, preset::Preset; stable_steps::Bool = false
)
   #
   # Analyse per value of the factor
   #
   factor = get_factor_name(df)
   groups = groupby(df, factor)
   values = [
      getproperty(key, factor) for key in keys(groups)
   ]

   #
   # Which time step to view data?
   #
   steps = [
      get_timesteps(group, stable_steps) for group in groups
   ]

   #
   # Collect the result format base on preset
   #
   result = DataFrame(factor => values)
   for column in names(df)
      if column in ["step", "seed", String(factor)] ||
         startswith(column, "num_")
         continue
      end
      result[!, column] =
         map(zip(steps, Tuple(groups))) do (step, group)
            get_analysis(group, column, step, preset)
         end
   end

   return result
end

function get_timesteps(df, stable)
   if stable
      num_bphs = combine(
         groupby(df, :step), :num_bphs => mean => :μ
      )
      _, t2 = findmax(num_bphs.μ)
      t1 = t2 - 7 * 24
      @assert t1 > 0
      return t1:t2
   else
      return Colon()
   end
end

function detect_pulse(x, k = 24 * 7)
   # Running average for a day
   x_ma = [mean(x[t:(t+k)]) for t in 1:(lastindex(x)-k)]

   # Find baseline
   # Using 0.75 quartile will cause local pulse
   # which is not what we want
   baseline = quantile(x_ma, 0.5)

   # Region of interest
   roi = @. Int(x_ma > baseline)
   domain = findall(
      @. roi[(begin+1):end] != roi[begin:(end-1)]
   )
   if isodd(length(domain))
      push!(domain, lastindex(x_ma))
   end

   # Detect pulse in each ROI
   map(Iterators.partition(domain, 2)) do (t1, t2)
      t = t1 + argmax(x_ma[t1:t2]) - 1
      t = t + k ÷ 2
      (t, x[t])
   end
end

function detect_pulse(result::Result)
   groups = groupby(
      result.df, Cols(result.factor_name, :seed)
   )

   # Detect pulse for each group
   results = combine(groups) do group
      # Detect BPH pulse from each group
      peaks = detect_pulse(group.num_bphs)
      num_peaks = length(peaks)
      first_peak, _ = pop!(peaks)

      (; num_peaks, first_peak)
   end

   # Combine
   combine(groupby(results, result.factor_name)) do group
      (;
         num_peaks = mean(group.num_peaks),
         first_peak = mean(group.first_peak),
         # Compat with the compute_stats signature
         converged = true,
      )
   end
end

function compute_observations(result::SimulationResult)
   rice_params = fit_rices(result)
   bph_params = fit_bphs(result)
   innerjoin(
      rice_params, bph_params; on = result.seed_factors
   )
end

function get_observation_path(config)
   joinpath(config.output, "observation")
end

function cached_compute_observations!(
   config; force::Bool = false
)
   ob_path = get_observation_path(config)
   if force
      rm(ob_path; force = true, recursive = true)
   end

   if isfile(ob_path) || isdir(ob_path)
      df = DataFrame(JDF.load(ob_path))
      return df
   else
      # Load result
      result = SimulationResult(config.output)
      GC.gc()

      # Find rice params
      rice_params = fit_rices(result)
      type_compress!(rice_params; compress_float = true)
      GC.gc()

      # Find bph params
      bph_params = fit_bphs(result)
      type_compress!(bph_params; compress_float = true)
      GC.gc()

      # Join results
      df = innerjoin(
         rice_params, bph_params; on = result.seed_factors
      )
      GC.gc()

      # Cache the observation DF and clean up
      JDF.save(ob_path, df)
      GC.gc()
      return df
   end
end

end # module Results
