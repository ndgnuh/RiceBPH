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
   #= EPS = eps(Float32) =#
   EPS = 0.0f0
   _3EPS = EPS * 3
   _2EPS = EPS * 2
   df.num_bphs = @. Float32(
      df.num_nymphs + df.num_brachys + df.num_macros
   )
   df.pct_nymphs = @. Float32(
      (df.num_nymphs + EPS) / (df.num_bphs + _3EPS)
   )
   df.pct_macros = @. Float32(
      (df.num_macros + EPS) / (df.num_bphs + _3EPS)
   )
   df.pct_brachys = @. Float32(
      (df.num_brachys + EPS) / (df.num_bphs + _3EPS)
   )
   df.pct_females = @. Float32(
      (df.num_females + EPS) / (df.num_bphs + _2EPS)
   )
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
      group_stats =
         mapreduce(merge, data_names) do column
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

@kwdef struct SimulationResult
   factors::Vector{Symbol}
   seed_factors::Vector{Symbol}
   outputs::Vector{Symbol}
   num_replications::Int
   num_steps::Int
   num_configurations::Vector{Int}
   configurations::DataFrame
   df::DataFrame
end

function Base.show(io::IO, r::SimulationResult)
   factors = join(r.factors, ",")
   num_cfgs = join(r.num_configurations, ", ")
   println(io, "SimulationResult:")
   println(io, "\tFactors: $factors")
   println(io, "\tNum steps: $(r.num_steps)")
   println(io, "\tNum replications: $(r.num_replications)")
   println(io, "\tNum configurations: $(num_cfgs)")
end

function SimulationResult(paths::AbstractString...)
   df = mapreduce(vcat, paths) do path
      DataFrame(JDF.load(path))
   end
   SimulationResult(df)
end
function SimulationResult(df::DataFrame; infer = true)
   type_compress!(df; compress_float = true)
   df = if infer
      df = infer_stats!(df)
      type_compress!(df; compress_float = true)
   else
      df
   end

   # Factor names
   factors = @chain begin
      fieldnames(ModelParameters)
      intersect(propertynames(df), _)
   end
   seed_factors = vcat(factors, [:seed])

   # Remove factor with single value
   removal = Symbol[]
   for factor in factors
      if length(unique(df[!, factor])) == 1
         push!(removal, factor)
      end
   end
   setdiff!(factors, removal)
   select!(df, Not(removal))

   # Output names
   outputs = @chain begin
      propertynames(df)
      setdiff!(_, factors)
      setdiff!(_, [:seed, :step])
   end

   # Configurations
   configurations = unique(select(df, Cols(factors...)))
   type_compress!(configurations; compress_float = true)

   # Other hyper params
   num_steps = maximum(df.step)
   num_replications = maximum(df.seed)
   num_configurations = map(factors) do f
      length(unique(configurations[!, f]))
   end

   SimulationResult(;
      factors,
      seed_factors,
      outputs,
      df,
      configurations,
      num_steps,
      num_replications,
      num_configurations,
   )
end

export SimulationResult
