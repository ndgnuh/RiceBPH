"""
    subpartitions(n)

Generate subpartitions with one index missing from `1:n` for a given integer n. This is a helper function for `sobol`.

# Arguments

  - `n::Int`: The integer for which subpartitions are generated.

# Returns

An iterator over subpartitions of n.

# Examples

```julia
subparts = subpartitions(4)
for part in subparts
   println(part)
end
```

Output:

```
(2, 3, 4)
(1, 3, 4)
(1, 2, 4)
(1, 2, 3)
```
"""
function subpartitions(n)
   (Tuple(i for i in 1:n if i != j) for j in 1:n)
end

"""
    cmean(df, yname, conds; name = yname)

Calculates the conditional mean of a variable in a DataFrame.

# Arguments

  - `df::DataFrame`: The input DataFrame.
  - `yname::Symbol`: The name of the variable whose mean is to be calculated.
  - `conds::Symbol`: The column(s) to group the DataFrame by, this is the condition.
  - `name::Symbol = yname`: (Optional) The name to assign to the resulting column.

# Returns

A new DataFrame with the conditional means.

# Examples

```julia
df = DataFrame(;
   x = [1, 2, 3, 1, 2, 3],
   y = [4, 5, 6, 7, 8, 9],
   z = [10, 11, 12, 13, 14, 15],
)
result = cmean(df, :y, :x; name = :mean_y)
```

The resulting DataFrame `result` will have the following structure:

```
6×3 DataFrame
 Row │ x      mean_y  z     
     │ Int64  Float64  Int64 
─────┼───────────────────────
   1 │     1      5.5     10
   2 │     2      6.5     11
   3 │     3      7.5     12
```
"""
function cmean(df, yname, conds; name = yname)
   combine(groupby(df, conds), yname => mean => name)
end

"""
    sobol(df, xnames, yname)

Calculate Sobol indices for results obtained from black box functions using the Sobol method.

# Arguments

  - `df::DataFrame`: The results DataFrame.
  - `xnames::Vector{Symbol}`: Names of the input variables (factors).
  - `yname::Symbol`: Name of the output variable.

# Returns

A dictionary mapping input variable names to their respective Sobol indices.

# Examples

```julia
df = DataFrame(;
   x1 = [1, 1, 1, 2, 2, 2, 3, 3, 3],
   x2 = [4, 5, 6, 4, 5, 6, 4, 5, 6],
)
df[!, :y] = df.x1 + df.x2 * 0.1 + rand(9) * 0.02
sobol_indices = sobol(df, [:x1, :x2], :y)
```

The resulting dictionary `sobol_indices` will have the following structure:

```
Dict{Tuple{Symbol, Vararg{Symbol}}, Float64} with 3 entries:
  (:x1, :x2) => 2.903e-6
  (:x2,)     => 0.0106756
  (:x1,)     => 0.989322
```
"""
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
