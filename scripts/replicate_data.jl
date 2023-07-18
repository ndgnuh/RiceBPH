using Distributed

import RiceBPH.Experiments as E
import RiceBPH.Results as R
using JDF

function main()
   # Dummy experiment to test the code
   #= rm(E.SCAN_DUMMY.output, force=true, recursive=true) =#
   #= rm(E.SOBOL_DUMMY.output, force=true, recursive=true) =#
   #= run(E.SCAN_DUMMY) =#
   #= run(E.SOBOL_DUMMY) =#

   # Real experiment
   E.run(E.SOBOL_ET)
   E.run(E.SOBOL_ET_WIDE)
   E.run(E.SOBOL_N0)
   E.run(E.SOBOL_FLOWER_P0)
   E.run(E.SOBOL_FLOWER_P0_WIDE)
   E.run(E.SCAN_N0)
   E.run(E.SCAN_ET)
   E.run(E.SCAN_SF_P0)
   E.run(E.SCAN_SF_P0_WIDE)
end
main()
