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
   fig = Figure(; figure_padding = 1)
   df = (result.df)
   factor_name = only(result.factors)

   # Axis setup
   day_step = 14
   xticks = 0:(day_step*24):maximum(df.step)
   ax = Axis(
      fig[1, 1];
      xticks = (xticks, (string ∘ Int).(xticks / 24)),
      yticks = WilkinsonTicks(7; k_min = 5, k_max = 10),
      xlabel = "Day",
      ylabel = "Number of BPHs",
   )

   # For formatting the plot
   count = 1
   min_y = 0
   max_y = maximum(df.num_bphs)

   @info result.factors
   # Group by input factors
   for group in groupby(df, result.factors)
      # Compute step-wise mean and standard deviation
      # statistics over multiple seeds
      subgroups = groupby(group, :step)
      stats = combine(
         subgroups,
         :num_bphs => mean => :num_bphs,
         :num_bphs => std => :err,
      )

      # Collect
      t = stats.step
      μ = stats.num_bphs
      σ = stats.err

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

   fig = Figure(; figure_padding = 1)
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
   xname = only(result.factors)
   x = stats[!, xname]
   ynames = (:pct_macros, :pct_brachys, :pct_nymphs)
   axes = []

   # Start plotting
   fig = Figure(; figure_padding = 1)
   pos = [(1, 1), (2, 1), (3, 1)]
   for (i, yname) in enumerate(ynames)
      ax = Axis(
         fig[pos[i]...];
         xticks = (eachindex(x), format_float.(x)),
         yticks = (0:0.1:1, format_float.(0:0.1:1)),
         xticklabelrotation = π / 2,
         height = 300,
         width = 900,
         xlabel = latex_name(xname),
         ylabel = latex_name(yname),
         xticklabelsize = latex_font_size,
         yticklabelsize = latex_font_size,
      )
      ax.xlabelsize = latex_font_size
      ax.ylabelsize = latex_font_size
      barplot!(ax, eachindex(x), stats[!, yname])
      push!(axes, ax)
   end

   # Sync axes
   linkaxes!(axes...)

   # Resize figure to axes
   resize_to_layout!(fig)

   # Return figure
   return fig
end

function draw_phase(df, xcol)
   x = df[!, xcol]

   # Prepare 
   fig = Figure(; figure_padding = 1)
   ax_common = (;
      width = 300,
      height = 300,
      xticks = WilkinsonTicks(7; k_min = 5, k_max = 10),
      yticks = WilkinsonTicks(7; k_min = 5, k_max = 10),
   )

   # Rice percentage
   ax = ax1 = Axis(fig[1, 2]; ax_common...)
   s1 = scatter!(
      ax,
      x,
      df[!, :pct_rices];
      color = COLORSCHEME.color2,
      label = latex_name(:pct_rices),
   )

   # Rice destruction speed
   ax = ax2 = Axis(fig[1, 3]; ax_common...)
   s2 = scatter!(
      ax,
      x,
      df[!, :spd_rices];
      color = COLORSCHEME.color1,
      label = latex_name(:spd_rices),
   )

   # BPH population
   ax = ax3 = Axis(fig[1, 1]; ax_common...)
   s3a = scatter!(
      ax,
      x,
      df[!, :pct_nymphs];
      color = COLORSCHEME.color5,
      label = latex_name(:pct_nymphs),
   )
   s3b = scatter!(
      ax,
      x,
      df[!, :pct_brachys];
      color = COLORSCHEME.color3,
      label = latex_name(:pct_brachys),
   )
   s3c = scatter!(
      ax,
      x,
      df[!, :pct_macros];
      color = COLORSCHEME.color4,
      label = latex_name(:pct_macros),
   )

   # Legend
   let scatters = [s1, s2, s3a, s3b, s3c]
      labels = [s.label for s in scatters]

      # Dummy legend for x-axis
      _, _, s = scatter(
         [1], [1]; color = :black, marker = :rect
      )
      push!(scatters, s)
      push!(
         labels,
         LaTeXString("\$x\$-axis: $(latex_name(xcol))"),
      )

      Legend(
         fig[2, 1:3],
         scatters,
         labels;
         labelsize = latex_font_size,
         orientation = :horizontal,
         tellwidth = true,
         tellheight = true,
      )
   end

   # Resize figure and font stuffs
   ax1.xlabelsize = latex_font_size
   ax2.xlabelsize = latex_font_size
   ax3.xlabelsize = latex_font_size
   linkxaxes!(ax1, ax2, ax3)
   resize_to_layout!(fig)
   return fig
end

function draw_phase_2f(
   df, xname, yname, zname; limit01 = false
)
   fig = Figure(; figure_padding = (10, 1, 1, 1))
   legend_height = 32
   ax = Axis3(
      fig[1, 1];
      xlabel = latex_name(xname),
      ylabel = latex_name(yname),
      zlabel = "",
      width = 600 + legend_height,
      height = 600,
      xticks = WilkinsonTicks(7; k_min = 5, k_max = 10),
      yticks = WilkinsonTicks(7; k_min = 5, k_max = 10),
      zticks = WilkinsonTicks(7; k_min = 5, k_max = 10),
      viewmode = :stretch,
   )
   ax.xlabelsize = latex_font_size
   ax.ylabelsize = latex_font_size

   # Scatter points
   colorw = normalize(df[!, zname], Inf32)
   color = [
      let r = COLORSCHEME.color1
         g = COLORSCHEME.color2
         color = g * z + r * (1 - z)
         (color, 0.7)
      end for z in colorw
   ]

   # Main plot
   s1 = scatter!(
      ax,
      df[!, xname],
      df[!, yname],
      df[!, zname];
      label = latex_name(zname),
      color,
   )

   # Draw lower and higher bound
   x = [minimum(df[!, xname]), maximum(df[!, xname])]
   y = [minimum(df[!, yname]), maximum(df[!, yname])]

   # Lower bound
   z = fill(minimum(filter(!isnan, df[!, zname])), 2, 2)
   surface!(ax, x, y, z; color = (COLORSCHEME.color1, 0.2))
   # Higher bound
   z = fill(maximum(filter(!isnan, df[!, zname])), 2, 2)
   surface!(ax, x, y, z; color = (COLORSCHEME.color2, 0.2))

   # Fix z axis scale
   if limit01
      zlims!(ax, 0, 1)
   end

   # Legend
   _, _, sl = scatter(
      [1],
      [1];
      marker = :rect,
      color = COLORSCHEME.color1,
      label = LaTeXString(L"\min"),
   )
   _, _, sh = scatter(
      [1],
      [1];
      marker = :rect,
      color = COLORSCHEME.color2,
      label = LaTeXString(L"\max"),
   )
   Legend(
      fig[2, 1],
      [s1, sl, sh],
      [s1.label, sl.label, sh.label];
      orientation = :horizontal,
      labelsize = latex_font_size,
      height = legend_height,
   )

   # Resize figure to axes
   rowgap!(fig.layout, 0)
   resize_to_layout!(fig)
   Makie.trim!(fig.layout)
   fig
end

function draw_scan_heatmap(
   statsdf,
   xname,
   yname,
   zname;
   colormap = :grays,
   text_color_low = :white,
   text_color_high = :black,
)
   # Unpack
   fig = Figure()
   x = statsdf[!, xname]
   y = statsdf[!, yname]
   z = statsdf[!, zname]

   # To heatmap args
   all_x = unique(x)
   all_y = unique(y)
   xsize = length(all_x)
   ysize = length(all_y)
   zmap = reshape(z, xsize, ysize)

   # Draw heatmap
   ax = Axis(
      fig[1, 1];
      xticks = (1:xsize, format_float.(all_x)),
      yticks = (1:ysize, format_float.(all_y)),
      xlabel = latex_name(replace(xname, "_value" => "")),
      ylabel = latex_name(replace(yname, "_value" => "")),
   )
   ax.xlabelsize = latex_font_size
   ax.ylabelsize = latex_font_size

   heatmap!(ax, 1:xsize, 1:ysize, zmap; colormap = colormap)

   # Put target text on the formap
   text_color_threshold = mean(zmap)
   for i in 1:xsize, j in 1:ysize
      zij = zmap[i, j]
      text = format_float(zij)

      # Text property
      color = if zij > text_color_threshold
         text_color_high
      else
         text_color_low
      end
      position = (i, j)
      align = (:center, :center)

      # Yank
      text!(ax, text; color, position, align)
   end

   # Return figure
   return fig
end
