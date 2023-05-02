using GLMakie
using Colors
using ..Results

@recipe(RegionChart, x, ys) do scene
    Attributes(bandkw = NamedTuple())
end
function GLMakie.plot!(scene::RegionChart)
    cum = zero.(scene.ys[] |> first)
    bandkw = scene.band_kw
    ys = scene.ys[]
    x = scene.x[]
    colors = diverging_palette(0, 360, length(ys), c = 0.3, s = 0.3, b = 0.3, d2 = 1)
    for (color, y) in zip(colors, ys)
        next_cum = y + cum
        band!(scene, x, cum, next_cum; color, bandkw...)
        cum .= next_cum
    end
    scene
end

function regionchart!(ax, ys; k...)
    regionchart!(ax, eachindex(first(ys)), ys; k...)
end

function plot_bph_region(df; time = Colon(), in_hours = false)
    fig = Figure()
    columns = [:pct_nymphs, :pct_macros, :pct_brachys]
    names = ["Nymphs", "Macropterous", "Brachypterous"]
    means = [Results.get_stat(df, column).mean[time] for column in columns]
    x, xlabel = if in_hours
        df.step[time], "Hours"
    else
        df.step[time] / 24, "Days"
    end
    ax = Axis(fig[1, 1]; yticks = 0:0.05f0:1, xlabel, ylabel = "% of BPHs")
    scene = regionchart!(ax, x, means)
    ylims!(0, 1)
    xlims!(minimum(x), maximum(x))
    leg = Legend(fig[2, 1], scene.bands[], names;
                 orientation = :horizontal, tellwidth = false, tellheight = true)
    return fig
end
