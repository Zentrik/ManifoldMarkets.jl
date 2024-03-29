"""Contains the client interface."""

export urlToSlug, getAllMarkets, getMarketBySlug, getMarketById, getPositionsOnMarket, getLimitOrdersOnMarket, getBet, getBets, getAllBets, getUserByUsername, getUserById, createBet, cancelBet

using ..ManifoldMarkets

using HTTP, JSON, OpenSSL

const BASE_URI = "http://manifold.markets/api/v0"

function getHTTP(url; query=nothing)
    if query !== nothing
        query = filter(pair -> pair.second !== nothing, query)
    end

    response = HTTP.get(url, query=query, connect_timeout=15, readtimeout=15, retry=true, retries=10, connection_limit=25, socket_type_tls=OpenSSL.SSLStream)
    return JSON.parse(String(response.body))

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

function getAllMarkets(;limit = nothing, before = nothing)
    response = getHTTP(BASE_URI * "/markets", query=["limit" => limit, "before" => before])
    return Market.(response)
end

function getMarketBySlug(slug, raw=false)
    response = getHTTP(BASE_URI * "/slug/" * slug)
    if raw
        return response
    end

    return Market(response)
end

function getMarketById(Id)
    response = getHTTP(BASE_URI * "/market/" * Id)
    return Market(response)
end

function getPositionsOnMarket(marketId; order=nothing, top=nothing, bottom=nothing, userId=nothing)
    response = getHTTP(BASE_URI * "/market/" * marketId * "/positions", query=["order" => order, "top" => top, "bottom" => bottom, "userId" => userId])
    return ContractMetric.(response)
end

function getLimitOrdersOnMarket(marketId, APIKEY, limit=1000)
    response = HTTP.get("http://pxidrgkatumlvfqaxcll.supabase.co/rest/v1/contract_bets?select=data&limit=$limit&order=data->>createdTime.asc&data->isFilled=eq.false&data->isCancelled=eq.false&contract_id=eq.$marketId", headers= ["apikey" => APIKEY, "Content-Type" => "application/json"])
    responseJSON = JSON.parse(String(response.body))
    return map(limitOrder -> Bet(limitOrder["data"]), responseJSON)
end

function getBet(betId, APIKEY)
    response = HTTP.get("http://pxidrgkatumlvfqaxcll.supabase.co/rest/v1/contract_bets?select=data&bet_id=eq.$betId", headers= ["apikey" => APIKEY, "Content-Type" => "application/json"])
    responseJSON = JSON.parse(String(response.body))
    return Bet(responseJSON[1]["data"])
end

function getBets(;limit=1000, before=nothing, username=nothing, slug=nothing, marketId=nothing)
    Bets = Bet[] # size unknown, as we don't know number of bets in market
    numberOfBets = 0
    lastBedID = before

    while numberOfBets < limit
        response = getHTTP(BASE_URI * "/bets", query=["limit" => min(1000, limit - numberOfBets), "before" => lastBedID, "username" => username, "market" => slug, "contractId" => marketId]) # When we've fetched all bets, this returns an empty list

        if isempty(response)
            break
        end 

        numberOfBets += min(1000, limit - numberOfBets)
        append!(Bets, Bet.(response))
        lastBedID = Bets[end].id

        if numberOfBets % 1000 != 0 || numberOfBets != length(Bets) # If its not a multiple of 1000, we've reached the limit or all bets have been fetched
            break
        end
    end
    return Bets
end

getAllBets(;before=nothing, username=nothing, slug=nothing, marketId = nothing) = getBets(limit=2^60, before=before, username=username, slug=slug, marketId=marketId)

function getUserByUsername(handle)
    response = getHTTP(BASE_URI * "/user/" * handle)
    return User(response)
end

function getUserById(userId)
    response = getHTTP(BASE_URI * "/user/by-id/" * userId)
    return User(response)
end

function authHeader(API_KEY)
    return ["Authorization" => "Key " * API_KEY]
end

function createBet(API_KEY, marketId, amount, outcome, limitProb=nothing)
    body = Dict("amount" => amount, "contractId" => marketId, "outcome" => outcome)
    
    if limitProb !== nothing
        body["limitProb"] = limitProb
    end

    response = HTTP.post(BASE_URI * "/bet", headers = vcat(authHeader(API_KEY), "Content-Type" => "application/json"), body=JSON.json(body))
    bet = JSON.parse(String(response.body))
    bet["id"] = pop!(bet, "betId")
    return Bet(bet)
end

function cancelBet(API_KEY, betId)
    body = Dict("bedId" => betId)

    response = HTTP.post(BASE_URI * "/bet/cancel/" * betId, vcat(authHeader(API_KEY), "Content-Type" => "application/json"), body=JSON.json(body))
    bet = JSON.parse(String(response.body))

    return Bet(bet)
end