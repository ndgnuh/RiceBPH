"""
dropnan(df)

Remove rows with NaN from dataframe, returns a subdataframe.
"""
function dropnan(df)
   mask = map(eachrow(df)) do row
      mapreduce(!isnan, &, row)
   end
   @view df[mask, :]
end

const latex_font_size = 24
function format_float(x)
   format(format"%.04f", x)
end

function visualize_qcv(
   result::SimulationResult,
   obdf = compute_observations(result);
   plot_options = NamedTuple(),
   axis_options = NamedTuple(),
)
   df = rename(permutedims(obdf.qcv), [:qcv])
   df.names = propertynames(obdf.qcv)

   # Sort by QCV
   df = sort(df, :qcv; rev = false)
   names = df.names
   qcv = df.qcv
   idx = eachindex(names)

   # Index of factor
   factor_idx = indexin(result.factors, names)

   colors = [
      parse(Color, COLORSCHEME.color4),
      parse(Color, COLORSCHEME.color2),
   ]
   colormap = map(idx) do i
      if i in factor_idx
         return colors[1]
      else
         return colors[2]
      end
   end

   attrs = (;
      bar_labels = map(x -> format(format"%.04f", x), qcv),
      axis = (;
         xticks = (idx, map(latex_name, names)),
         xticklabelsize = latex_font_size,
         #= yticks = (0:0.1:maximum(qcv)+0.1), =#
         ylabel = ("Quartile Coefficent of Variant"),
         axis_options...,
      ),
      color = colormap,
      plot_options...,
   )
   fig, ax, _ = barplot(idx, qcv; attrs...)
   #= ylims!(ax, 0, maximum(qcv) + 0.1) =#
   return fig
end

function visualize_qcv(
   result::Result,
   obdf = compute_observations(result);
   plot_options = NamedTuple(),
   axis_options = NamedTuple(),
)
   df = rename(permutedims(obdf.qcv), [:qcv])
   df.names = DataFrames.names(obdf.qcv)

   # Sort by QCV
   df = sort(df, :qcv; rev = false)
   names = df.names
   qcv = df.qcv
   idx = eachindex(names)

   # Index of factor
   factor_idx = findfirst(
      result.factor_name |> string |> isequal, names
   )

   colors = [
      parse(Color, COLORSCHEME.color4),
      parse(Color, COLORSCHEME.color2),
   ]
   colormap = [
      i == factor_idx ? colors[1] : colors[2] for i in idx
   ]

   attrs = (;
      bar_labels = map(x -> format(format"%.04f", x), qcv),
      axis = (;
         xticks = (idx, map(latex_name, names)),
         xticklabelsize = latex_font_size,
         yticks = (0:0.1:maximum(qcv)+0.1),
         ylabel = ("Quartile Coefficent of Variant"),
         axis_options...,
      ),
      color = colormap,
      plot_options...,
   )
   fig, ax, _ = barplot(idx, qcv; attrs...)
   ylims!(ax, 0, maximum(qcv) + 0.1)
   return fig
end

function visualize_num_bphs(result)
   fig = Figure()
   df = (result.df)
   factor_name = only(result.factors)

   # Axis setup
   day_step = 10
   xticks = 0:(day_step*24):maximum(df.step)
   ax = Axis(
      fig[1, 1];
      xticks = (xticks, (string ∘ Int).(xticks / 24)),
      xlabel = "Day",
      ylabel = "Number of BPHs",
   )

   # For formatting the plot
   count = 1
   min_y = 0
   max_y = maximum(df.num_bphs)

   # Collect the result first
   for group in groupby(df, factor_name)
      allstats = combine(groupby(group, :step)) do row
         x = row.num_bphs
         μ = mean(x)
         σ = if length(x) == 1
            only(x)
         else
            std(x)
         end
         (; t = first(unique(row.step)), μ, σ)
      end
      stats = dropnan(allstats)

      # Collect
      t = stats.t
      μ = stats.μ
      σ = stats.σ

      # Adjust axis scale
      max_y = max(
         max_y, trunc(Int, maximum(μ + σ) / 100) * 100
      )
      min_y = min(
         min_y, trunc(Int, minimum(μ - σ) / 100) * 100
      )

      # Formatting
      color = COLORSCHEME2[count]
      factor_value = group[!, factor_name] |> first
      label = LaTeXString("\$N_I = $(factor_value)\$")

      # Plot mean + std plot with a band and a middle line
      band!(ax, t, μ - σ, μ + σ; color = (color, 0.3))
      lines!(ax, t, μ; linewidth = 2.5, label, color)

      # Increase count
      count = count + 1
   end

   # Reticks y axis
   ax.yticks = min_y:150:max_y
   fig[1, 2] = Legend(
      fig,
      ax,
      "Initial number of BPHs";
      framevisible = false,
      nbanks = 2,
   )
   return fig
end

function visualize_pct_nymphs(
   result, obdf = compute_observations(result)
)
   meandf = obdf.mean
   factor_column = "$(only(result.factors))_value"

   xvalues = meandf[!, factor_column]
   x = eachindex(xvalues)
   μ = meandf.pct_nymphs

   config = (;
      bar_labels = map(format_float, μ),
      axis = (;
         xlabel = LaTeXString(latex_name(:pct_nymphs)),
         ylabel = latex_name(only(result.factors)),
         yticks = (x, format_float.(xvalues)),
         xticks = 0:0.1:1.3,
      ),
      direction = :x,
      color = COLORSCHEME.color2,
   )
   fig, ax, _ = barplot(x, μ; config...)
   ax.xlabelsize = latex_font_size
   ax.ylabelsize = latex_font_size
   xlims!(ax, 0, 1)
   return fig
end

function heatmap_df(df, x, y, z; options...)
   xs = unique(df[!, x])
   ys = unique(df[!, y])
   zmap = groupby(df, Cols(x, y))
   z = map(
      i -> first(zmap[i][!, z]), Iterators.product(xs, ys)
   )

   fig = Figure()
   ax = Axis(
      fig[1, 1];
      xticks = (eachindex(xs), format_float.(xs)),
      yticks = (eachindex(ys), format_float.(ys)),
      xlabel = String(x),
      ylabel = String(y),
   )

   # The heatmap
   hmap = heatmap!(ax, z; options...)

   # Text overlay
   threhsold = mean(z)
   for i in eachindex(xs), j in eachindex(ys)
      position = (i, j)
      value = z[i, j]
      align = (:center, :center)
      text!(ax, format_float(value); align, position)
   end

   # Color bar
   Colorbar(fig[1, 2], hmap)
   fig
end

function scatter_df!(ax, fitdf, xname, yname)
   x = fit_df[:, xname]
   y = fit_df[:, yname]
   scatter!(ax, x, y)
end

function draw_pct_bphs(result::SimulationResult)
   # Fit population statistics
   df = fit_bphs(result)
   stats = combine(groupby(df, result.factors)) do group
      (;
         pct_nymphs = mean(group[!, :pct_nymphs]),
         pct_macros = mean(group[!, :pct_macros]),
         pct_brachys = mean(group[!, :pct_brachys]),
      )
   end

   # Data for plotting
   xcol = only(result.factors)
   x = stats[!, xcol]
   ycols = (:pct_macros, :pct_brachys, :pct_nymphs)
   axes = []

   # Start plotting
   fig = Figure()
   pos = [(1, 1), (2, 1), (3, 1)]
   for (i, ycol) in enumerate(ycols)
      ax = Axis(
         fig[pos[i]...];
         xticks = (eachindex(x), format_float.(x)),
         yticks = (0:0.1:1, format_float.(0:0.1:1)),
         xticklabelrotation = π / 2,
         height = 300,
         width = 900,
         xlabel = latex_name(xcol),
         ylabel = latex_name(ycol),
         xticklabelsize = latex_font_size,
         yticklabelsize = latex_font_size,
      )
      ax.xlabelsize = latex_font_size
      ax.ylabelsize = latex_font_size
      barplot!(ax, eachindex(x), stats[!, ycol])
      push!(axes, ax)
   end

   # Sync axes
   linkaxes!(axes...)

   # Resize figure to axes
   resize_to_layout!(fig)

   # Return figure
   return fig
end
