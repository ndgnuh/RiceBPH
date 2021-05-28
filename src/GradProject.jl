module GradProject

Model = include("Model.jl")
Dashboard = include("Dashboard.jl")
Replication = include("Replication.jl")

if !isempty(PROGRAM_FILE) && realpath(PROGRAM_FILE) == @__FILE__
    try
        Dashboard.start()
    catch e
        showerror(stdout, e, catch_backtrace())
    end
end

end # module
