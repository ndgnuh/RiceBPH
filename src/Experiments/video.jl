function run(config::ModelVideo)
    model = init_model(config.params; config.seed)
    frames = config.num_steps
    abmvideo(config.video_output, model, agent_step!, model_step!;
             config.framerate, config.spu, frames,
             showstep = true,
             Visualisations.ac,
             Visualisations.heatkwargs,
             Visualisations.heatarray)
    @info "Video written to $(config.video_output)"
end
