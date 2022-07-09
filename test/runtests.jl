using RiceBPH.Models
using RiceBPH.Models: get_moving_directions, BPH
using Test

@testset "Moving direction" begin
    @test get_moving_directions(1) == Set([(-1, 0), (0, -1), (1, 0), (0, 1)])
    @test get_moving_directions(2) == Set([(2, 0), (-2, 0),
                                           (0, 2), (0, -2),
                                           (1, 1), (1, -1),
                                           (-1, 1), (-1, -1)])
end

@testset "Agent quantization" begin
    bph = BPH(; id=1, pos=(1, 1), energy=0.1, age=3, is_female=true, is_shortwing=true)
    @test typeof(bph) == BPH{Int,Float64}
    bph = BPH(; id=1, pos=(1, 1), energy=0.1f0, age=3, is_female=true, is_shortwing=true)
    @test typeof(bph) == BPH{Int,Float32}
    bph = BPH(; id=1, pos=(1, 1), energy=0.1f0, age=Int32(3), is_female=true,
              is_shortwing=true)
    @test typeof(bph) == BPH{Int32,Float32}
    bph = BPH(; id=1, pos=(1, 1), energy=0.1f0, age=Int16(3), is_female=true,
              is_shortwing=true)
    @test typeof(bph) == BPH{Int16,Float32}
end
