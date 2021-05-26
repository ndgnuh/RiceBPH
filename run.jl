using Pkg
Pkg.activate(@__DIR__)
using GradProject
GradProject.Dashboard.start(; debug=false)
