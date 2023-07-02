const SOBOL_ET = SobolInput(;
   num_samples = 100,
   output = "outputs/energy-transfer-02",
   energy_transfer = (0.01f0, 0.1f0),
   init_pr_eliminate = (0.0f0, 0.0f0),
   flower_width = (0, 0),
   init_num_bphs = (200, 200),
   nboot = 1,
)

const SOBOL_ET_WIDE = SobolInput(;
   num_samples = 100,
   output = "outputs/energy-transfer-wide",
   energy_transfer = (0.00f0, 1f0),
   init_pr_eliminate = (0.0f0, 0.0f0),
   flower_width = (0, 0),
   init_num_bphs = (200, 200),
   nboot = 1,
)

const SOBOL_N0 = SobolInput(;
   num_samples = 100,
   output = "outputs/init-num-bphs",
   energy_transfer = (0.035f0, 0.035f0),
   init_pr_eliminate = (0, 0),
   flower_width = (0, 0),
   init_num_bphs = (10, 1000),
)

const SOBOL_FLOWER_PR = SobolInput(;
   num_samples=10,
   output="outputs/flower",
   energy_transfer=(0.035f0, 0.035f0),
   init_pr_eliminate=(0f0, 1f0),
   flower_width=(0, 21),
   init_num_bphs=(200,  200),
   order=[2],
   nboot=2
)
