using Test
using BenchmarkTools
using GradProject
using GradProject.Model
using GradProject.Model.Agents

isbph(x) = true
food(model) = count(≥(0.5), model.food)
adata = [(isbph, count)]
mdata = [food]

function run_with_seed(seed)
    crop = Model.gencrop_3x3()
    model = Model.init_model(crop, 200, :corner, 0.2f0; seed=seed)
    return adf, mdf = run!(
        model, Model.agent_step!, Model.model_step!, 2880; adata=adata, mdata=mdata
    )
end

@testset "Basic" begin
    crop = Model.gencrop_3x3()
    @test true
    model = Model.init_model(crop, 200, :corner, 0.2f0; seed=1)
    @test true
    run!(model, Model.agent_step!, Model.model_step!, 1; adata=adata, mdata=mdata)
    @test true
end

# Before adding type parameter
# BenchmarkTools.Trial:
#   memory estimate:  20.73 MiB
#   allocs estimate:  82035
#   --------------
#   minimum time:     309.505 ms (0.00% GC)
#   median time:      313.172 ms (0.00% GC)
#   mean time:        312.776 ms (0.46% GC)
#   maximum time:     316.794 ms (1.13% GC)
#   --------------
#   samples:          16
display(@benchmark run_with_seed(1))
@testset "Benchmark" begin
    @test true
end

@testset "Reproducible" begin
    for seed in rand(UInt8, 3)
        adf1, mdf1 = run_with_seed(seed)
        adf2, mdf2 = run_with_seed(seed)
        for name in names(adf1)
            @test all(adf1[!, name] .=== adf2[!, name])
        end
        for name in names(mdf1)
            @test all(mdf1[!, name] .=== mdf2[!, name])
        end
    end
end

@testset "Generate Video" begin
    crop = Model.gencrop_3x3()
    Model.video(crop, 200, :random_c2, 0.1; seed=1)
    @test true
end
