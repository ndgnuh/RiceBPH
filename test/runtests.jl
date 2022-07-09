using RiceBPH.Models
using RiceBPH.Models: get_moving_directions
using Test

@testset "Moving direction" begin
    @test get_moving_directions(1) == Set([(-1, 0), (0, -1), (1, 0), (0, 1)])
    @test get_moving_directions(2) == Set([(2, 0), (-2, 0),
                                           (0, 2), (0, -2),
                                           (1, 1), (1, -1),
                                           (-1, 1), (-1, -1)])
end
