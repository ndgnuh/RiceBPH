push!(LOAD_PATH, "../src/")
using RiceBPH
using Documenter
using DocumenterCitations

const mathengine = Documenter.KaTeX()
Documenter.HTML(; mathengine)

const bib = CitationBibliography(joinpath(@__DIR__, "refs.bib"))
makedocs(bib; sitename = "RiceBPH")
