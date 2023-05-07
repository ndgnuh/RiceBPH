push!(LOAD_PATH, "../src/")
cp(joinpath(@__DIR__, "..", "README.md"),
   joinpath(@__DIR__, "src", "index.md"), force = true)
using RiceBPH
using Documenter
using DocumenterCitations

const mathengine = Documenter.KaTeX()
Documenter.HTML(; mathengine)

const bib = CitationBibliography(joinpath(@__DIR__, "refs.bib"))
makedocs(bib; sitename = "RiceBPH")
