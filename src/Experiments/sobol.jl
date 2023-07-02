using Distributed
using ProgressMeter
using JDF
using GlobalSensitivity
using QuasiMonteCarlo
using Configurations
import RiceBPH.Models as M

TupleOrNum{T} = Union{Tuple{T, T}, T}
@option struct SobolInput
   num_samples::Int
   output::String
   energy_transfer::NTuple{2, Float32}
   init_pr_eliminate::NTuple{2, Float32}
   flower_width::NTuple{2, Int}
   init_num_bphs::NTuple{2, Int}
   nboot::Int = 1
   order::Vector{Int} = [0, 1]
end

function get_pnames(si::SobolInput)
   names = [
      :energy_transfer,
      :init_pr_eliminate,
      :flower_width,
      :init_num_bphs,
   ]
   filter(names) do name
      a, b = getproperty(si, name)
      return a != b
   end
end

function get_snames(si::SobolInput)
   names = [
      :energy_transfer,
      :init_pr_eliminate,
      :flower_width,
      :init_num_bphs,
   ]
   setdiff(names, get_pnames(si))
end

function get_prange(si::SobolInput)
   [getproperty(si, name) for name in get_pnames(si)]
end

function get_dims(si::SobolInput)
   length(get_pnames(si))
end

function gen_configurations(si::SobolInput)
   method = Sobol(; si.nboot, si.order)
   design = generate_sobol_inputs(
      method, get_prange(si); samples = si.num_samples
   )
   pnames = get_pnames(si)
   seed = 0
   map(eachcol(design)) do conf
      seed = seed + 1
      params = Dict(
         begin
            v = only(unique(getproperty(si, k)))
            k => v
         end for k in get_snames(si)
      )
      params[:seed] = seed
      for (i, v) in enumerate(conf)
         params[pnames[i]] = v
      end

      params[:flower_width] = trunc(
         Int, params[:flower_width]
      )
      params[:init_num_bphs] = trunc(
         Int, params[:init_num_bphs]
      )
      return params
   end
end

function generate_sobol_inputs(
   method::Sobol,
   p_range::AbstractVector;
   samples,
   kwargs...,
)
   AB = QuasiMonteCarlo.generate_design_matrices(
      samples,
      [i[1] for i in p_range],
      [i[2] for i in p_range],
      QuasiMonteCarlo.SobolSample(),
      2 * method.nboot,
   )
   A = reduce(hcat, @view(AB[1:(method.nboot)]))
   B = reduce(hcat, @view(AB[(method.nboot+1):end]))
   TA = eltype(A)

   # Copied from the first part of gsa function
   d, n = size(A)
   nboot = method.nboot # load to help alias analysis
   n = n ÷ nboot
   multioutput = false
   Anb = Vector{Matrix{TA}}(undef, nboot)
   for i in 1:nboot
      Anb[i] = A[:, (n*(i-1)+1):(n*(i))]
   end
   Bnb = Vector{Matrix{TA}}(undef, nboot)
   for i in 1:nboot
      Bnb[i] = B[:, (n*(i-1)+1):(n*(i))]
   end
   _all_points = mapreduce(hcat, Anb, Bnb) do (args...)
      GlobalSensitivity.fuse_designs(
         args...; second_order = 2 in method.order
      )
   end

   return _all_points
end


function compute_sobol(si::SobolInput, all_y)
   method = Sobol(; si.nboot, si.order)
   n = si.num_samples
   d = get_dims(si)
   GlobalSensitivity.gsa_sobol_all_y_analysis(
      method, all_y, d, n, :Jansen1999, nothing, Val(false)
   )
end
function compute_sobol(method, ally, d, n)
   GlobalSensitivity.gsa_sobol_all_y_analysis(
      method, ally, d, n, :Jansen1999, nothing, Val(false)
   )
end

function run!(config::SobolInput)
   output_file = config.output

   configurations = gen_configurations(config)
   @info "Number of configuration: $(length(configurations))"

   results = @showprogress pmap(configurations) do params
      # Init and run
      model = M.init_model(; params...)
      mdf = M.run_ricebph!(model)

      # Without this, oom
      type_compress!(mdf; compress_float = true)
      GC.gc()
      return mdf
   end
   all_result = reduce(vcat, results)
   JDF.savejdf(output_file, all_result)
   @info "Output written to $(output_file)"
end
