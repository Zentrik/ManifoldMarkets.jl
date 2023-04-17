using ManifoldMarkets
using Test

@testset "ManifoldMarkets.jl" begin
    # Write your tests here.
    getAllMarkets()

    getBets()

    getUserByUsername("Spindle")
    getUserByUsername("Jack")
    getUserByUsername("jack")
    getUserByUsername("BTE")

    getPositionsOnMarket("3XN17HvygPDpMznLeMsb")
    getPositionsOnMarket("3XN17HvygPDpMznLeMsb", userId="dNgcgrHGn8ZB30hyDARNtbjvGPm1")
    getPositionsOnMarket("3XN17HvygPDpMznLeMsb", userId=getUserByUsername("jack").id)
end