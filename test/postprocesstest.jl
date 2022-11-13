using RiceBPH.PostProcess
using JLD2

result_dir = joinpath(@__DIR__, "sample-results")
result_files = joinpath.(result_dir, readdir(result_dir))
result_files = filter(endswith("jld2"), result_files)
result_file = rand(result_files)

@testset "Plotting" begin
    p = PostProcess.plot_bph(result_file)
    savefig(p, "bph.png")
    @test true
    p = PostProcess.plot_rice(result_file)
    savefig(p, "rice.png")
    @test true
end

@testset "Hypothesis Testing" begin
    test_rice(result_file, 0.01)
    @test true
    batch_test_rice(result_dir, 0.01; alpha=0.05, clean=true)
    @test true
end

@testset "Population peak" begin
    local df = jldopen(f -> f["1"], result_file)
    peak_population(df.count_bph)
    @test true
    peak_population(result_file)
    @test true
    batch_peak_population(result_dir)
    @test true
end
