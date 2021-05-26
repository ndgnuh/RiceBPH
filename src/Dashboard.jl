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
                    type="number", id="pr_killed0", value=0.001, step=0.001, max=1, min=0
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
        dbc_cardbody([]; id="map-pv"),
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
                    html_br()
                    dbc_cardlink([#
                        html_a("Generate"; id="video-btn", href="javascript:void(0)"),
                    ])
                ],
            )
        ],
    )
end

function draw_pr_killed(z)
    trace = (#
        z=collect(eachrow(z)),
        zmax=maximum(z),
        zmin=0,
        type="heatmap",
        showscale=false,
        colorscale=[(i, "rgba(1.0, 0.0, 0.0, $i)") for i in 0:0.1:1],
    )
    return dcc_graph(; figure=(#
        data=[trace],
    ))
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
        trace = (#
            z=collect(eachrow(crop)),
            zmin=0,
            zmax=1,
            type="heatmap",
            showscale=false,
            colorscale=[(i, "rgba(0.0, 1.0, 0.0, $i)") for i in 0:0.1:1],
        )
        trace2 = (#
            z=collect(eachrow(isnan.(crop) * 1.0)),
            zmax=1,
            zmin=0,
            type="heatmap",
            showscale=false,
            colorscale=[(i, "rgba(1.0, 1.0, 0.0, 0.5)") for i in 0:0.1:1],
        )
        pr_killed = imfilter(isnan.(crop), Kernel.gaussian(3))
        pr_killed = pr_killed / maximum(pr_killed) * pr_killed0
        html_div(
            [#
                dbc_col("Flower/Total: $(count(isnan, crop))/$(length(crop[:]))"; width=12)
                dbc_row(
                    [#
                        dbc_col() do
                            dcc_graph(; figure=(#
                                data=[trace2, trace],
                            ))
                        end
                        dbc_col() do
                            draw_pr_killed(pr_killed)
                        end
                    ],
                )
            ],
        )
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
        # Run the model
        isbph(x) = true
        food(model) = count(≥(0.5), model.food)
        adata = [(isbph, count)]
        mdata = [food]
        traces = [
            begin
                crop = readdlm(map_path, Float32)
                model = Model.init_model(
                    crop,
                    nb_bph_init,
                    Symbol(init_position),
                    convert(Float32, pr_killed0);
                    seed=seed,
                )
                adf, mdf = Agents.run!(
                    model,
                    Model.agent_step!,
                    Model.model_step!,
                    2880;
                    adata=adata,
                    mdata=mdata,
                )
                bph_trace = (
                    x=adf.step, y=adf.count_isbph, type="scatter", mode="lines+scatters"
                )
                rice_trace = (x=mdf.step, y=mdf.food, type="scatter", mode="lines+scatters")
                (bph_trace, rice_trace)
            end for seed in 1:replication
        ]

        bph_layout = (title="BPH",)
        rice_layout = (title="Rice",)
        dbc_row(
            [
                dbc_col([#
                    dcc_graph(; figure=(data=getindex.(traces, 1), layout=bph_layout)),
                ])
                dbc_col([#
                    dcc_graph(; figure=(data=getindex.(traces, 2), layout=rice_layout)),
                ])
            ],
        )
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
    ) do ts, frames, map_path, nb_bph_init, init_position, pr_killed0
        if isnothing(ts)
            return "..."
        end
        seed = 1
        vname = "BPH-$(nb_bph_init)-$(init_position)-$(pr_killed0)-$(seed).mp4"
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

        video64 = String(Base64.encode.(read(vpath)))
        video64 = "data:video/mp4;base64,$video64"
        if isfile(vpath)
            html_div(
                [
                    "Video saved in $(vpath)"
                    html_br()
                    html_video(
                        [
                            html_source(; src=vpath, type="video/mp4")
                            html_source(; src=video64, type="video/mp4")
                            "Your browser doesn't support HTML5 video player"
                        ];
                        controls=true,
                    )
                ],
            )
        else
            "Some thing is wrong with video: please check $vpath"
        end
    end
end

function simulation_output()
    return dbc_card(
        [
            dbc_cardheader("Output")
            dbc_cardbody(["Output"]; id="simulation-output")
        ]
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
                                dbc_cardbody(; id="video-output")
                            ]
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
