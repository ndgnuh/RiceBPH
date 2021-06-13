using RiceBPH.PostProcess

result_dir = joinpath("..", "results")
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
    df = test_rice(result_files, 0.01)
    display(df)
    @test true
end
