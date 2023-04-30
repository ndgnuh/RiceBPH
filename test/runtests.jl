using RiceBPH.Models
using Test

function test_replication(seed)
    energy_transfer = 0.04f0
    flower_width = 4
    init_pr_eliminate = 0.05f0
    map_size = 125
    num_init_bphs = 200
    model1 = init_model(; seed, num_init_bphs, energy_transfer, map_size, flower_width, init_pr_eliminate)
    _, mdf1 = run!(model1, agent_step!, model_step!, 200, mdata=Models.MDATA)

    model2 = init_model(; seed, num_init_bphs, energy_transfer, map_size, flower_width, init_pr_eliminate)
    _, mdf2 = run!(model2, agent_step!, model_step!, 200, mdata=Models.MDATA)


    return mdf1 == mdf2
end


@testset "Replication test" begin
    for seed in rand(1:1000, 5)
        @test test_replication(1)
    end
end
