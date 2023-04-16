using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.resolve()

#= let orig_load_path = joinpath(first(Base.DEPOT_PATH) , "packages") =#
#=     push!(Base.LOAD_PATH, orig_load_path) =#
#= end =#
using PackageCompiler
const packages = collect(keys(Pkg.installed()))
const sysimage_path = "ricebph.sys.so"

@show packages
create_sysimage(packages; sysimage_build_args=`-O0`, sysimage_path=sysimage_path)
@info sysimage_path
