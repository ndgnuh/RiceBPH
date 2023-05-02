cp(joinpath(@__DIR__, "..", "README.md"),
   joinpath(@__DIR__, "src", "index.md"), force = true)
using RiceBPH
using Documenter

makedocs(sitename = "RiceBPH")
