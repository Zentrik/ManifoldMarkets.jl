using ManifoldMarkets
using Test

@testset "ManifoldMarkets.jl" begin
    # Write your tests here.
    getAllMarkets()

    getBets()

    getUserByUsername("Spindle")
    getUserByUsername("Jack")
    getUserByUsername("BTE")
end