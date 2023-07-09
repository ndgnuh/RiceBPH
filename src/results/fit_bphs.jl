function fit_bphs(
   result::SimulationResult, groupkey = result.seed_factors
)
   groups = groupby(result.df, groupkey)
   combine(groups) do group
      # Stable steps
      q1 = quantile(group.pct_rices, 0.25)
      q3 = quantile(group.pct_rices, 0.75)
      group = filter(
         :pct_rices => (x -> q1 < x < q3), group
      )

      # Statistics
      results = map([
         :pct_nymphs, :pct_macros, :pct_brachys
      ]) do name
         @chain begin
            group[!, name]
            filter(!isnan, _)
            filter(!ismissing, _)
            name => mean(_)
         end
      end
      NamedTuple(results)
   end
end
