using RiceBPH.Models
using RiceBPH.Visualisations
using InteractiveDynamics
using Comonicon

@main function main(; output::String, seed::Int = 0, map_size::Int = 125,
                    flower_width::Int = 0, init_pr_eliminate::Float32 = 0.15f0,
                    num_init_bphs::Int = 200, energy_transfer::Float32 = 0.04f0,
                    num_steps::Int = 2880, framerate::Int = 60, spu::Int = 1)
    model = init_model(; map_size, flower_width, num_init_bphs,
                       energy_transfer, init_pr_eliminate, seed)
    @info "Please wait while the video is being generated..."
    frames = num_steps
    abmvideo(output, model, agent_step!, model_step!;
             framerate, spu, frames,
             showstep = true,
             Visualisations.ac,
             Visualisations.heatkwargs,
             Visualisations.heatarray)
    @info "Video written to $(output)"
end
