using RiceBPH.Models
using ProgressMeter
using Test
using RiceBPH.Results: generate_sobol_inputs, compute_sobol
using GlobalSensitivity: Sobol, gsa

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

function ishi(X)
    A= 7
    B= 0.1
    sin(X[1]) + A*sin(X[2])^2+ B*X[3]^4 *sin(X[1])
end

@testset "GSA Sobol decomposed implementation" begin 
    method = Sobol(order=[0, 1, 2], nboot=2)
    a = -π
    b = π
    p_range = [(a, b), (a, b), (a, b), (a, b)]
    d = 4
    for _ in 1:10
        n= rand(100:1000)
        # First impl
        allx = generate_sobol_inputs(method,  p_range; samples=n)
        ally = ishi.(eachcol(allx))
        res1 = compute_sobol(method, ally, d, n)
        
        res2 = gsa(ishi, method, p_range; samples=n)
        @test res1.S1 == res2.S1
        @test res1.S1_Conf_Int == res2.S1_Conf_Int
        @test res1.S2 == res2.S2
        @test res1.S2_Conf_Int == res2.S2_Conf_Int
    end
end


@testset "Replication test" begin
    @showprogress for seed in 1:5
        @test test_replication(seed, 4, 0.05f0)
    end
    @showprogress for seed in 1:20
        @test test_replication(seed, 0, 0.0f0)
    end
end
