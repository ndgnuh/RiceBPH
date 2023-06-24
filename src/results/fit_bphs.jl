function fit_bphs(result::SimulationResult)
   groups = groupby(result.df, result.seed_factors)
   combine(groups) do group
      # Stable steps
      q1 = quantile(group.pct_rices, 0.25)
      q3 = quantile(group.pct_rices, 0.75)
      group = filter(:pct_rices => (x -> q1 < x < q3), group)

      # Statistics
      results = map([:pct_nymphs, :pct_macros, :pct_brachys]) do name
         name => mean(group[!, name])
      end
      NamedTuple(results)
   end
end
