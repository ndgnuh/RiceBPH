using Distributed

import RiceBPH.Experiments as E

function main()
   E.run(E.SOBOL_ET)
   E.run(E.SOBOL_ET_WIDE)
   E.run(E.SOBOL_N0)
   E.run(E.SOBOL_FLOWER_P0)
   E.run(E.SOBOL_FLOWER_P0_WIDE)
   E.run(E.SCAN_N0)
   E.run(E.SCAN_ET)
   E.run(E.SCAN_SF_P0)
end
main()
