"""Contains the client interface."""

export urlToSlug, getAllMarkets, getMarketBySlug, getMarketById, getBets, getAllBets, getUserByUsername, getUserById, createBet, cancelBet

using ..ManifoldMarkets

using HTTP, JSON3

const BASE_URI = "https://manifold.markets/api/v0"

function getHTTP(url, query=nothing)
    if query !== nothing
        query = filter(pair -> pair.second !== nothing, query)
    end

    response = HTTP.get(url, query=query, connect_timeout=15, readtimeout=15, connection_limit=64)
    return JSON3.read(response.body)

    # slow? should be faster i think if we do it right
    # HTTP.open(:GET, url, query=) do http
    #     JSON.parse(http)
    # end
end

"""Generate the slug of a market, given it has an assigned URL."""
function urlToSlug(url)
    return split(url, "/")[end]
end

"""A client for interacting with the website manifold.markets."""

getAllMarkets(;limit = nothing, before = nothing) = getHTTP(BASE_URI * "/markets", ["limit" => limit, "before" => before])

@inline getMarketBySlug(slug) = getHTTP(BASE_URI * "/slug/" * slug)

getMarketById(Id) = getHTTP(BASE_URI * "/market/" * Id)

getBets(;limit=1000, before=nothing, username=nothing, slug=nothing, marketId = nothing) = response = getHTTP(BASE_URI * "/bets", ["limit" => limit, "before" => before, "username" => username, "contractSlug" => slug, "contractId" => marketId]) # When we've fetched all bets, this returns an empty list

# function getBets(;limit=1000, before=nothing, username=nothing, slug=nothing, marketId = nothing)
#     numberOfBets = 0
#     lastBedID = before

#     while numberOfBets < limit
#         response = getHTTP(BASE_URI * "/bets", query=["limit" => min(1000, limit - numberOfBets), "before" => lastBedID, "username" => username, "contractSlug" => slug, "contractId" => marketId]) # When we've fetched all bets, this returns an empty list

#         if isempty(response)
#             break
#         end 

#         numberOfBets += min(1000, limit - numberOfBets)
#         append!(Bets, Bet.(response))
#         lastBedID = Bets[end].id

#         if numberOfBets % 1000 != 0 || numberOfBets != length(Bets) # If its not a multiple of 1000, we've reached the limit or all bets have been fetched
#             break
#         end
#     end
#     return Bets
# end

# getAllBets(;before=nothing, username=nothing, slug=nothing, marketId = nothing) = getBets(limit=2^60, before=before, username=username, slug=slug, marketId = marketId)

getUserByUsername(handle) = getHTTP(BASE_URI * "/user/" * handle)

getUserById(userId) = getHTTP(BASE_URI * "/user/by-id/" * userId)

function authHeader(API_KEY)
    return ["Authorization" => "Key " * API_KEY]
end

function createBet(API_KEY, marketId, amount, outcome, limitProb=nothing)
    body = Dict("amount" => amount, "contractId" => marketId, "outcome" => outcome)
    
    if limitProb !== nothing
        body["limitProb"] = limitProb
    end

    response = HTTP.post(BASE_URI * "/bet", headers = vcat(authHeader(API_KEY), "Content-Type" => "application/json"), body=JSON3.write(body))
    bet = JSON3.read(response.body)
    # bet["id"] = pop!(bet, "betId")
    return bet
end

function cancelBet(API_KEY, betId)
    body = Dict("bedId" => betId)

    response = HTTP.post(BASE_URI * "/bet/cancel/" * betId, vcat(authHeader(API_KEY), "Content-Type" => "application/json"), body=JSON3.write(body))
    bet = JSON3.read(response.body)

    return bet
end