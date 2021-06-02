using Distributed

function exit(code=0)
    println("Exitting, press enter three times...")
    readline()
    readline()
    readline()
    return Base.exit(code)
end

function usage()
    return println("""
             julia replicate.jl [input]

             where input is the file that contains all the parameter sets
             """)
end

# PREPROCESS OUTPUT

config_file = "config.jl"
if !isfile(config_file)
    @warn "config file not found, generating one"
    config_str = """
Dict(#
    :replication => 1000,
    :output_directory => "results",
    :nprocs => 1,
    :overwrite => true,
)"""
    println(config_str)
    write(config_file, config_str)
    @info "New config file is generated at $(config_file)"
    exit()
end
config = include(config_file)
if !iszero(config[:nprocs] - 1) # Add process if doing parallel
    @info "Adding more process(es)"
    addprocs(config[:nprocs] - 1)
end
mkpath(config[:output_directory])

# Preprocess input

if isempty(ARGS) && !haskey(config, :input)
    usage()
    exit(-1)
end
inputfile = if !isempty(ARGS)
    ARGS[1]
else
    config[:input]
end
if !isfile(inputfile)
    usage()
    @error "Input file $(inputfile) not found"
    exit(-1)
end
params = include(inputfile)

# Load the model in every process
@everywhere using Pkg
@everywhere Pkg.activate(@__DIR__)
@everywhere using GradProject
@everywhere Model = GradProject.Model
@everywhere Replication = GradProject.Replication
@everywhere using JLD2

@info "Running using $(nprocs()) process(es)"

for param in params
    filename = Replication.generate_filename(; param...)
    filepath = joinpath(config[:output_directory], filename * ".jld2")
    if isfile(filepath) && !config[:overwrite]
        @error "$filepath exists, and overwrite is false"
        exit(-1)
    end
    replication = config[:replication]
    @info "Running $filename"
    data = @time GradProject.replication(param, replication)
    jldopen(filepath, "a") do f
        if !haskey(f, "metadata")
            f["metadata"] = param
        end
        for (seed, df) in data
            key = string(seed)
            if haskey(f, key)
                @warn "$key already exists, skipping"
            else
                f[key] = df
            end
        end
    end
    @everywhere GC.gc()
end
