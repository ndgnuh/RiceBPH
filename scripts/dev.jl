
using Distributed
@everywhere using RiceBPH.Model: init_model, run!, ModelParams
@everywhere using SQLite
@everywhere using SQLite.DBInterface
@everywhere using ProgressMeter
@everywhere using Printf
@everywhere using CSV, DataFrames



function save!(db, param::ModelParams)
    names = propertynames(param)
    stmt = """\
    insert into params($(join(names, ",")) \
    \nvalues\
    \n('$(join(((getproperty(param, k)) for k in names), "','"))');\
    """
    @show stmt
end

const db = SQLite.DB("test.db")

@info "Initializing"
@everywhere const model, as!, ms! = init_model(
    seed=1,
    envmap="assets/envmaps/nf-100.csv",
    init_nb_bph=200,
    init_pr_eliminate=0.15,
    energy_transfer=0.08f0,
    energy_consume=0.08f0 / 3,
    moving_speed_shortwing=1,
    moving_speed_longwing=1,
    init_position="corner",
)

@info save!(db, model.params)

@info "Running model"
@time run!(model, as!, ms!, 2880)
@time run!(model, as!, ms!, 2880)
#= @time let =#
#=     model_data = [ =#
#=         :num_rices, =#
#=         :num_eggs, =#
#=         :num_nymphs, =#
#=         :num_macros, =#
#=         :num_brachys, =#
#=     ] =#

#=     @showprogress pmap(1:300) do i =#
#=         model, _, _ = init_model( =#
#=             seed=i, =#
#=             envmap="assets/envmaps/nf-100.csv", =#
#=             init_nb_bph=200, =#
#=             init_pr_eliminate=0.05f0, =#
#=             energy_transfer=0.08f0, =#
#=             energy_consume=0.08f0 / 3, =#
#=             moving_speed_shortwing=1, =#
#=             moving_speed_longwing=1, =#
#=             init_position="corner", =#
#=         ) =#
#=         _, df = run!(model, as!, ms!, 2880; mdata=model_data) =#
#=         output_file_name = @sprintf "dev/0.5m/output-%04d.csv" i =#
#=         #= CSV.write(output_file_name, df) =# =#
#=     end =#

#= end =#
