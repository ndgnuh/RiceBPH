module GradProject

using Agents: run!

Model = include("Model.jl")
Replication = include("Replication.jl")

function run_model(params, laststep=2880; seed=rand(1:2000))
    model = Model.init_model(; seed=seed, params...)
    return run!(
        model,
        Model.agent_step!,
        model.model_step!,
        laststep;
        adata=Model.adata,
        mdata=Model.mdata,
    )
end

function replication(params, n; seed_offset=0)
    return Replication.replication(
        Model.init_model,
        Model.agent_step!,
        Model.model_step!,
        2880,
        n;
        seed_offset=seed_offset,
        adata=Model.adata,
        mdata=Model.mdata,
        post_process=Model.post_process,
        params...,
    )
end

if !isempty(PROGRAM_FILE) && realpath(PROGRAM_FILE) == @__FILE__
    Dashboard = include("Dashboard.jl")
    try
        Dashboard.start()
    catch e
        showerror(stdout, e, catch_backtrace())
    end
end

end # module
