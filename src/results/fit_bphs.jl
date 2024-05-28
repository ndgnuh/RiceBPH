notinfnan(x) = (!isnan(x)) && (!ismissing(x)) && (!isinf(x))
mean_skipnan = mean ∘ filter(notinfnan)
std_skipnan = std ∘ filter(notinfnan)
q1_skipnan(x) = quantile(filter(notinfnan, x), 0.25f0)
q2_skipnan(x) = quantile(filter(notinfnan, x), 0.50f0)
q3_skipnan(x) = quantile(filter(notinfnan, x), 0.75f0)
iqr_skipnan(x) = q3_skipnan(x) - q1_skipnan(x)

function fit_bphs(result::SimulationResult, groupkey = result.seed_factors)
   groups = groupby(result.df, groupkey)
   combine(groups) do group
      # Stable steps
      q1 = quantile(group.pct_rices, 0.25)
      q3 = quantile(group.pct_rices, 0.75)
      group = filter(:pct_rices => (x -> q1 < x < q3), group)

      # Statistics
      results = map([:pct_nymphs, :pct_macros, :pct_brachys]) do name
         @chain begin
            group[!, name]
            filter(!isnan, _)
            filter(!ismissing, _)
            name => mean(_)
         end
      end

      # Clean up
      GC.gc(false)
      NamedTuple(results)
   end
end

# New code
# ========
function fit_bph(df::DataFrame)
   # Quartiles of rice
   rice_1 = quantile(df[!, :pct_rices] |> unique, 0.25)
   rice_3 = quantile(df[!, :pct_rices] |> unique, 0.75)
   df = filter(:pct_rices => (x -> rice_1 < x < rice_3), df)

   # Compute statistics
   columns = [:pct_nymphs, :pct_macros, :pct_brachys]
   means = Dict([Symbol("mean_$(c)") => mean(df[!, c]) for c in columns])
   stds = Dict([Symbol("std_$(c)") => std(df[!, c]) for c in columns])
   DataFrame(merge(means, stds))
end

function fit_bph(dfs::Vector{DF}, groupkey::Symbol) where {DF <: AbstractDataFrame}
   # Prepare
   df = mapreduce(vcat, dfs) do df
      rice_1 = quantile(df[!, :pct_rices] |> unique, 0.25)
      rice_3 = quantile(df[!, :pct_rices] |> unique, 0.75)
      df = filter(:pct_rices => (x -> rice_1 < x < rice_3), df)
   end

   # Combine declaration
   columns = [:pct_nymphs, :pct_macros, :pct_brachys]
   mapper = mapreduce(vcat, columns) do column
      [
         column => mean_skipnan => Symbol("mean_$(column)"),
         column => std_skipnan => Symbol("std_$(column)"),
         column => iqr_skipnan => Symbol("iqr_$(column)"),
         column => q1_skipnan => Symbol("q1_$(column)"),
         column => q3_skipnan => Symbol("q3_$(column)"),
      ]
   end

   # Split-apply-combine
   combine(groupby(df, groupkey), mapper...)
end
