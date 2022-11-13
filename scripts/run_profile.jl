const BASEPATH = joinpath(@__DIR__, "..")
const MAPSPATH = joinpath(BASEPATH, "assets", "envmaps")

using Pkg
Pkg.activate(BASEPATH)
@info "Adding necessary package for easy profiling"
Pkg.add("ProfileView")

using RiceBPH
using ProfileView

const MAPSPATH = joinpath(BASEPATH, "assets", "envmaps")
const MAP = joinpath(MAPSPATH, rand(readdir(MAPSPATH)))

# Trigger compilation
@profview RiceBPH.run_simulation(; envmap=MAP)
@profview RiceBPH.run_simulation(; envmap=MAP)
sleep(1000000)
