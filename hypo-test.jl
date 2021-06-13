using Distributed
@everywhere using Pkg
@everywhere Pkg.activate(@__DIR__)

@everywhere begin
    using RiceBPH
    using RiceBPH.PostProcess
    using ProgressMeter
    using CSV, DataFrames
    const testdir = "kiem-dinh"
    const resultdir = "results"
end

mkpath(testdir)

let cases = collect(Iterators.product([0.01, 0.05], [0.1, 0.05, 0.01, 0.005]))
    @showprogress pmap(cases) do (p0, a)
        df = PostProcess.batch_test_rice(resultdir, p0; alpha=a, clean=true)
        CSV.write(joinpath(testdir, "test-p0+$p0-alpha+$a.csv"), df)
    end
end
