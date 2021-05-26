using Pkg
Pkg.activate(@__DIR__)
using GradProject
debug = let d = get(ENV, "DEBUG", "false")
    try
        d = parse(Bool, d)
    catch
        d = false
    end
    d
end
GradProject.Dashboard.start(; debug=debug)
