using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.resolve()

using PackageCompiler
const packages = collect(keys(Pkg.installed()))
const sysimage_path = "ricebph.sys.so"

const package_str = join(packages, ", ")
@info "Building system images with these packages:\n- $(package_str)"
create_sysimage(packages; sysimage_build_args = `-O0`, sysimage_path = sysimage_path)
@info "System image written to $(sysimage_path)"
