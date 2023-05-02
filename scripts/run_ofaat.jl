using Distributed
using Comonicon
using JDF
using RiceBPH.OFAAT: run_ofaat!
using TOML

@main function main(config_file::String, output::String)
    config = TOML.parsefile(config_file)
    options = Dict(Symbol(k) => v for (k, v) in config)
    @info options

    factor = Symbol(pop!(options, :factor))
    values = eval(Meta.parse(pop!(options, :values)))
    num_steps = pop!(options, :num_steps)
    num_replicates = pop!(options, :num_replicates)
    result = run_ofaat!(num_steps, num_replicates, factor, values; options...)
    JDF.save(output, result)
    @info "Output written to $(output)"
end
