using Distributed

if nprocs() > 1
   @info "Multi-processing detected, it might takes a while for all the processes to load the package"
end
using RiceBPH.Experiments

Experiments.julia_main()
