module Experiments

# Env libs
using Configurations
using Comonicon

# Local libs
using ..Models

include("Experiments/config.jl")


@main function main(; config::RunConfig)
    display(config.config)
end

end
