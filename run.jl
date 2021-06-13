using Pkg
Pkg.activate(@__DIR__)
using RiceBPH
debug = let d = get(ENV, "DEBUG", "false")
    try
        d = parse(Bool, d)
    catch
        d = false
    end
    d
end
RiceBPH.Dashboard.start(; debug=debug)
