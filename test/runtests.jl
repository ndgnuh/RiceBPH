using RiceBPH.Models
using ProgressMeter
using Test

const NUM_STEPS = 2880

function test_replication(seed, flower_width, init_pr_eliminate)
    energy_transfer = 0.032f0
    map_size = 125
    init_num_bphs = 200
    model1 = init_model(; seed, init_num_bphs, energy_transfer, map_size, flower_width, init_pr_eliminate)
    _, mdf1 = run!(model1, agent_step!, model_step!, NUM_STEPS, mdata=Models.MDATA)

    model2 = init_model(; seed, init_num_bphs, energy_transfer, map_size, flower_width, init_pr_eliminate)
    _, mdf2 = run!(model2, agent_step!, model_step!, NUM_STEPS, mdata=Models.MDATA)


    return mdf1 == mdf2
end


@testset "Replication test" begin
    @showprogress for seed in 1:20
        @test test_replication(seed, 4, 0.05f0)
    end
    @showprogress for seed in 1:20
        @test test_replication(seed, 0, 0.0f0)
    end
end
