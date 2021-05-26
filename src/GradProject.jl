module GradProject

Model = include("Model.jl")
Dashboard = include("Dashboard.jl")

if !isempty(PROGRAM_FILE) && realpath(PROGRAM_FILE) == @__FILE__
	Dashboard.start()
end

end # module
