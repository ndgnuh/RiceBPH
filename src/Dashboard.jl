module Dashboard

using ..Model
using Dash
using DashHtmlComponents
using DashCoreComponents
using DashTable
using DashBootstrapComponents
using DelimitedFiles
using PlotlyJS
using ImageFiltering
using Agents: Agents
using Base64: Base64
using JSON3
using DataFrames

heatmapkwargs = (zauto=true, transpose=true, showscale=false)

function figure(p; kwargs...)
    figure = JSON3.read(json(p), NamedTuple{(:data, :layout, :frames)})
    return dcc_graph(; figure=figure, kwargs...)
end

function parameters_view()
    return dbc_card([#
        dbc_cardheader("Parameters"),
        dbc_cardbody([#
            dbc_formgroup([#
                dbc_label("Map:"),
                dbc_select(; id="crop", options=[], value=[]),
                html_a("Refresh"; id="refresh-map", href="javascript:void(0)"),
                html_br(),
                dbc_label("Init #BPH"),
                dbc_input(; type="number", id="nb_bph_init", value=200),
                dbc_label("Init position"),
                dbc_select(;
                    id="init_position",
                    options=[#
                        (value="corner", label="Corner"),
                        (value="random_c1", label="Random (2 patches scenario)"),
                        (value="random_c2", label="Random (9 patches scenario)"),
                        (value="border", label="Border"),
                    ],
                    value="corner",
                ),
                dbc_label("Kill probability"),
                dbc_input(;
                    type="number", id="pr_killed0", value=0.075, step=0.000001, max=1, min=0
                ),
                dbc_label("Replications"),
                dbc_input(; type="number", id="replication", value=50, max=5000, min=1),
            ]),
            dbc_cardlink([
                html_a("Run simulation"; href="javascript:void(0)", id="run-btn")
            ]),
        ]),
    ])
end

function map_view()
    return dbc_card([#
        dbc_cardheader("Map preview"),
        dcc_loading(dbc_cardbody([]; id="map-pv")),
    ])
end

function video_paramter()
    return dbc_card(
        [#
            dbc_cardheader("Video")
            dbc_cardbody(
                [
                    dbc_label("Number of steps: ")
                    dbc_input(; type="number", id="video-frames", value=2880)
                    dbc_label("Video seed: ")
                    dbc_input(; type="number", id="video-seed", value=1)
                    html_br()
                    dbc_cardlink([#
                        html_a("Generate"; id="video-btn", href="javascript:void(0)"),
                    ])
                ],
            )
        ],
    )
end

callbacks = Dict{Symbol,Function}()

callbacks[:refreshmap] = function (app)
    return callback!(
        app,#
        Output("crop", "options"),
        Output("crop", "value"),
        Input("refresh-map", "n_clicks"),
    ) do _
        map_options, map_value = let mapdir = joinpath(@__DIR__, "maps/")
            labels = readdir(mapdir)
            values = joinpath.(mapdir, labels)
            [(value=v, label=l) for (v, l) in zip(values, labels)], first(values)
        end
    end
end

callbacks[:drawmap] = function (app)
    callback!(
        app,
        Output("map-pv", "children"),
        Input("crop", "value"),
        Input("pr_killed0", "value"),
    ) do mappath, pr_killed0
        crop = readdlm(mappath)
        trace = heatmap(;#
            z=crop,
            heatmapkwargs...,
            colorscale=[(i, "rgba(0.0, 1.0, 0.0, $i)") for i in 0:0.1:1],
        )
        trace2 = heatmap(;#
            z=isnan.(crop) * 1.0,
            colorscale=[(i, "rgba(1.0, 1.0, 0.0, 0.5)") for i in 0:0.1:1],
            heatmapkwargs...,
        )
        pr_killed = imfilter(isnan.(crop), Kernel.gaussian(3))
        pr_killed = pr_killed / maximum(pr_killed) * pr_killed0
        trace3 = heatmap(;
            z=pr_killed,
            colorscale=[(i, "rgba(1.0, 0.0, 0.0, $i)") for i in 0:0.1:1],
            heatmapkwargs...,
        )
        surface_flower = count(isnan, crop)
        surface_all = length(crop[:])
        surface_flower_pc = round(surface_flower / surface_all * 100; digits=2)
        layout = Layout(;
            title="<b>Crop size: $(size(crop)). Flower/Total: $(surface_flower)/$(surface_all) ($surface_flower_pc%)</b>",
        )
        fig = hcat(plot([trace2, trace]), plot([trace3]))
        relayout!(fig.plot, layout)
        figure(fig)
    end
end

callbacks[:run] = function (app)
    callback!(
        app,
        Output("simulation-output", "children"),
        Input("run-btn", "n_clicks_timestamp"),
        State("crop", "value"),
        State("nb_bph_init", "value"),
        State("init_position", "value"),
        State("pr_killed0", "value"),
        State("replication", "value"),
    ) do ts, map_path, nb_bph_init, init_position, pr_killed0, replication
        if isnothing(ts)
            return "..."
        end
        adata = let bph(x) = true
            [(bph, count)]
        end
        mdata = let rice(model) = count(≥(0.5), model.food)
            [rice]
        end

        function run_simulation(seed)
            crop = readdlm(map_path)
            init_position = Symbol(init_position)
            model = Model.init_model(
                crop, nb_bph_init, init_position, pr_killed0; seed=seed
            )
            adf, mdf = Agents.run!(
                model,
                Model.agent_step!,
                Model.model_step!,
                2880;
                adata=adata,
                mdata=mdata,
            )
            df = innerjoin(adf, mdf; on=:step)
            return (seed, df)
        end
        # Run the model

        total_rice = count(!isnan, readdlm(map_path))
        data = [run_simulation(sd) for sd in 1:replication]
        passes = [seed for (seed, df) in data if df.rice[end] < total_rice ÷ 2]
        npasses = length(passes)

        # Data traces
        bph_traces = [
            scatter(;#
                x=df.step,
                y=df.count_bph,
                name="Seed $(seed)",
            ) for (seed, df) in data
        ]
        rice_traces = [
            scatter(;#
                x=df.step,
                y=df.rice,
                name="Seed $(seed)",
            ) for (seed, df) in data
        ]
        bph_layout = Layout(; title="<b>BPH</b>")
        rice_layout = Layout(; title="<b>Rice ≥ 50%</b>")
        plt = hcat(plot(bph_traces, bph_layout), plot(rice_traces, rice_layout))

        # Plot layout
        mapname = split(map_path, r"[\\/]")[end]
        str_passed = if npasses === 0
            "(No passed cases)"
        else
            """
            Passed cases: $(join(passes, ", ")). ($(npasses)/$(replication))
            """
        end
        title = """
        <b>Map: $(mapname), #BPH: $(nb_bph_init),
        pos: $(init_position), pr_killed: $(pr_killed0),
        $str_passed
        </b>
        """
        relayout!(plt.plot, Layout(; showlegend=false, ymin=0, title=title))

        return figure(plt)
    end
end

callbacks[:run_video] = function (app)
    return callback!(
        app,
        Output("video-output", "children"),
        Input("video-btn", "n_clicks_timestamp"),
        State("video-frames", "value"),
        State("crop", "value"),
        State("nb_bph_init", "value"),
        State("init_position", "value"),
        State("pr_killed0", "value"),
        State("video-seed", "value"),
    ) do ts, frames, map_path, nb_bph_init, init_position, pr_killed0, seed
        if isnothing(ts)
            return "..."
        end
        mapname = split(map_path, r"[/\\]")[end]
        vname = "BPH-$(mapname)-$(nb_bph_init)-$(init_position)-$(pr_killed0)-$(seed).mp4"
        vpath = normpath(joinpath(@__DIR__, "..", vname))

        crop = readdlm(map_path)
        Model.video(
            vpath,
            crop,
            nb_bph_init,
            Symbol(init_position),
            pr_killed0;
            frames=frames,
            seed=seed,
        )

        if isfile(vpath)
            html_div("Video saved in:\n$(vpath)")
        else
            "Some thing is wrong with video: please check $vpath"
        end
    end
end

function simulation_output()
    return dbc_card(
        [
            dbc_cardheader("Output")
            dcc_loading(dbc_cardbody(["Output"]; id="simulation-output"))
        ],
    )
end

function start(; host="127.0.0.1", port=8000, debug=true)
    @info "Debug = $debug"
    app = dash(; external_stylesheets=[dbc_themes.BOOTSTRAP])

    app.layout = dbc_container(
        [#
            html_h1(Model.name)
            html_h4("Input")
            dbc_row([# row
                dbc_col(parameters_view(); width=2)
                dbc_col(map_view();)
            ])
            html_br()
            html_h4("Plot output")
            simulation_output()
            html_h4("Video output")
            dbc_row(
                [
                    dbc_col(video_paramter(); width=3)
                    dbc_col(
                        dbc_card(
                            [
                                dbc_cardheader("Video")
                                dcc_loading(dbc_cardbody(; id="video-output"))
                            ],
                        );
                        width=9,
                    )
                ],
            )
            html_br()
        ],
    )

    for (k, f!) in callbacks
        f!(app)
    end

    return run_server(app, host, port; debug=debug)
end

end
