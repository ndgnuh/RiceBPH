const SOBOL_ET = SobolInput(;
   num_samples = 100,
   output = "outputs/energy-transfer",
   energy_transfer = (0.01f0, 0.1f0),
   init_pr_eliminate = (0.0f0, 0.0f0),
   flower_width = (0, 0),
   init_num_bphs = (200, 200),
   nboot = 1,
)

const SOBOL_ET_WIDE = SobolInput(;
   num_samples = 100,
   output = "outputs/energy-transfer-wide",
   energy_transfer = (0.00f0, 1.0f0),
   init_pr_eliminate = (0.0f0, 0.0f0),
   flower_width = (0, 0),
   init_num_bphs = (200, 200),
   nboot = 1,
)

const SOBOL_N0 = SobolInput(;
   num_samples = 100,
   output = "outputs/init-num-bphs",
   energy_transfer = (0.03f0, 0.03f0),
   init_pr_eliminate = (0, 0),
   flower_width = (0, 0),
   init_num_bphs = (10, 1000),
)

const SOBOL_FLOWER_P0 = SobolInput(;
   num_samples = 100,
   output = "outputs/flower-p0",
   energy_transfer = (0.03f0, 0.03f0),
   init_pr_eliminate = (0.0f0, 0.2f0),
   flower_width = (0, 21),
   init_num_bphs = (200, 200),
   order = [2],
   nboot = 2,
)

const SOBOL_FLOWER_P0_WIDE = SobolInput(;
   num_samples = 100,
   output = "outputs/flower-p0-wide",
   energy_transfer = (0.03f0, 0.03f0),
   init_pr_eliminate = (0.0f0, 1.0f0),
   flower_width = (0, 50),
   init_num_bphs = (200, 200),
   order = [2],
   nboot = 2,
)

const SCAN_N0 = ModelOFAT(;
   factor = "init_num_bphs",
   values = "trunc.(Int, exp10.(range(start=log10(10), stop=log10(1000), length=10)))",
   num_steps = 2881,
   num_replications = 100,
   output = "outputs/scan-num-init-bphs",
   params = Dict([
      :map_size => 125,
      :flower_width => 0,
      :init_pr_eliminate => 0.0,
      :energy_transfer => 0.03,
   ]),
)

const SCAN_ET = ModelOFAT(;
   factor = "energy_transfer",
   values = "0.01f0:0.005f0:0.1f0",
   num_steps = 2881,
   num_replications = 100,
   output = "outputs/scan-energy-transfer",
   params = Dict([
      :map_size => 125,
      :flower_width => 0,
      :init_pr_eliminate => 0.0,
      :init_num_bphs => 200,
   ]),
)
