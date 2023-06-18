function cmean(df, yname, conds; name = yname)
   combine(groupby(df, conds), yname => mean => name)
end

function sobol(df, xnames, yname)
   # Generate index sets
   num_levels = length(xnames) + 1
   partitions = Dict{Int, Vector{Tuple}}()
   for i in 1:num_levels
      if i < num_levels
         partitions[i] = collect(subpartitons(i))
      else
         partitions[i] = [Tuple(1:num_levels-1)]
      end
   end

   # The result data frame
   base::DataFrame = unique!(select(df, xnames))

   # Conditional mean
   mean_columns = Vector{Symbol}[]
   for level in 1:num_levels
      # First level is just the mean
      if level == 1
         base[!, :E_0] .= mean(df[!, yname])
         push!(mean_columns, [:E_0])
         continue
      end

      # For each index set in the level
      mean_columns_u = Symbol[]
      for u in partitions[level]
         # key for group by
         groupkey = collect(map(i -> xnames[i], u))
         # Result columns
         name = Symbol("E_$(join(u))")
         push!(mean_columns_u, name)
         # Actual calculation and merge result
         aux = cmean(df, yname, groupkey; name)
         base = innerjoin(base, aux; on = groupkey)
      end
      push!(mean_columns, mean_columns_u)
   end

   # Map E_u columns to f_u columns
   f_columns = map(mean_columns) do cols
      map(cols) do col
         fcol = replace(string(col), "E" => "f")
         Symbol(fcol)
      end
   end

   # Calculate factored black box components f_i
   base[!, :f_0] = base[!, :E_0]
   for i in 2:num_levels
      # f_0 + f_1 + f_2 = ...
      local residual_cols::Vector{Symbol}
      residual_cols = mapreduce(vcat, 1:i-1) do j
         f_columns[j]
      end
      # @show i, residual_cols
      residual::Vector{Float32} = sum(
         base[!, col] for col in residual_cols
      )
      for (ecol, fcol) in zip(mean_columns[i], f_columns[i])
         transform!(base) do df
            NamedTuple([fcol => df[!, ecol] - residual])
         end
      end
   end

   # Calculate sobol index
   let result_key = Cols(f_columns[begin+1:end]...) # skip f_0
      df = select(base, result_key)
      vars = map(col -> var(df[!, col]), names(df))
      sobol_index_values = vars / sum(vars)

      namemap = mapreduce(vcat, 2:num_levels) do level
         map(partitions[level]) do u
            map(i -> xnames[i], u)
         end
      end
      Dict(namemap .=> sobol_index_values)
   end
end
