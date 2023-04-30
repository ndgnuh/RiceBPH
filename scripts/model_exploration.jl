using RiceBPH.Models
using RiceBPH.Visualisations
using InteractiveDynamics
using Comonicon

@main function main(; map_size::Int = 125, flower_width::Int = 0,
                    num_init_bphs::Int = 200, init_pr_eliminate::Float32 = 0.15f0,
                    energy_transfer::Float32 = 0.04f0, seed::Int = 0)
    model = init_model(; map_size, flower_width, num_init_bphs,
                       energy_transfer, init_pr_eliminate, seed)
    fig, _ = abmexploration(model; agent_step!, model_step!,
                            mdata = Models.MDATA_EXPL,
                            Visualisations.ac,
                            Visualisations.heatkwargs,
                            Visualisations.heatarray)
    scene = display(fig)
    wait(scene)
end
