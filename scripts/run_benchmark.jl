const BASEPATH = joinpath(@__DIR__, "..")
using Pkg
Pkg.activate(BASEPATH)

using RiceBPH
using BenchmarkTools

const MAPSPATH = joinpath(BASEPATH, "assets", "envmaps")
const MAP = joinpath(MAPSPATH, rand(readdir(MAPSPATH)))

bm = @benchmark RiceBPH.run_simulation(; seed=nothing,
                                       init_nb_bph=200,
                                       init_pr_eliminate=0.05,
                                       init_position=:corner,
                                       envmap=MAP)
display(bm)
