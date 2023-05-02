cp(joinpath(@__DIR__, "..", "README.md"),
   joinpath(@__DIR__, "src", "index.md"))
using RiceBPH
using Documenter

makedocs(sitename = "RiceBPH")
