############################## BINARY MARKETS ONLY
export sortLimitOrders!, getLimitOrders, probToPool, changeInPool, betToShares

using ..ManifoldMarkets

# @code_warntype sortLimitOrders(bets, Dict())
function sortLimitOrders!(userBalance, bets)
    limitOrdersByProb = Dict()
    userIds = Set()

    begin 
        for bet in bets
            if bet.limitProb !== nothing && !bet.isCancelled && !bet.isFilled
                outcome = Symbol(bet.outcome)

                if outcome ∉ keys(limitOrdersByProb)
                    limitOrdersByProb[outcome] = Dict()
                end

                if bet.limitProb ∉ keys(limitOrdersByProb[outcome])
                    limitOrdersByProb[outcome][bet.limitProb] = [bet]
                else
                    push!(limitOrdersByProb[outcome][bet.limitProb], bet)
                end

                # # @async begin # So this is ready for limitOrders()
                # if bet.userId ∉ keys(userBalance)
                #     @async userBalance[bet.userId] = getUserById(bet.userId).balance
                #     # userBalance[bet.userId] = 100.
                # end
                # end
                
                push!(userIds, bet.userId)
            end
        end

        for (outcome, limitOrdersOutcome) in limitOrdersByProb, (limitProb, limitBets) in limitOrdersOutcome
            limitOrdersByProb[outcome][limitProb] = sort(limitBets; by=bet->bet.createdTime)
        end
    end

    return (limitOrdersByProb=limitOrdersByProb, userIds=userIds)
end

############### NEED TO SORT KEYS OF LIMIT ORDERS

# @code_warntype limitOrders(l, b)
function getLimitOrders(sortedLimitOrders, userBalance)
    limitOrdersAmountsShares = Dict(:YES=>Dict{Float64, Vector{Float64}}(), :NO=> Dict{Float64, Vector{Float64}}()) 

    splitBets = Dict(:YES=>Float64[], :NO=> Float64[])  # If a limit order is greater than a user's balance it can only be partially filled, as filling more than balance simply cancels it. So we need to keep track of how much we can bet before we start cancelling limit orders and not filling them at all.

    for outcome in keys(sortedLimitOrders) # Which direction limit order is in
        cumulativeBet = 0
        userBalanceRemaining = deepcopy(userBalance) # Tracks how much balance they have remaining in mana 

        buyingOutcome = outcome == :YES ? :NO : :YES

        if buyingOutcome == :YES
            sortedLimitProbs = sortedLimitOrders[outcome] |> keys |> collect |> sort
        elseif buyingOutcome == :NO # needs to be reversed so we go through highest prob first
            sortedLimitProbs = sortedLimitOrders[outcome] |> keys |> collect |> x -> sort(x, rev=true)
        end

        for limitProb in sortedLimitProbs
            bets = sortedLimitOrders[outcome][limitProb]

            for bet in bets
                filledSoFar = bet.amount

                amountRemaining = bet.orderAmount - filledSoFar #in MANA

                amountRemaining = min(amountRemaining, userBalanceRemaining[bet.userId]) # Accounts for user balance not being large enough to fill limit order

                if outcome == :YES
                    shares = amountRemaining / limitProb # The limit order is buying YES, so if we are buying NO
                    amount = shares * (1 - limitProb) # How much to buy to fill limit order
                elseif outcome == :NO
                    shares = amountRemaining / (1 - limitProb) # The limit order is buying NO, so if we are buying YES
                    amount = shares * limitProb # How much to buy to fill limit order
                end

                cumulativeBet += amount

                if bet.orderAmount - filledSoFar > userBalanceRemaining[bet.userId] # If limit order will get cancelled if we fill it fully
                    if (length(splitBets[buyingOutcome]) >= 1 && cumulativeBet != splitBets[buyingOutcome][end]) || length(splitBets[buyingOutcome]) == 0 # If cumulative bet isnt same as last cumulative bet
                        push!(splitBets[buyingOutcome], cumulativeBet) # Last cumulative bet is never added, should it?
                    end
                end
                userBalanceRemaining[bet.userId] -= amountRemaining

                if amount != 0
                    if limitProb in keys(limitOrdersAmountsShares[buyingOutcome])
                        limitOrdersAmountsShares[buyingOutcome][limitProb] += [amount, shares]
                    else
                        limitOrdersAmountsShares[buyingOutcome][limitProb] = [amount, shares]
                    end
                end
            end
        end
    end
    
    return (limitOrdersAmountsShares=limitOrdersAmountsShares, splitBets=splitBets)
end

# function getLimitOrders(bets::Vector{Bet})
#     # @sync begin
#     #     tmp = sortLimitOrders(bets)
#     #     print(tmp[2])
#     #     return getLimitOrders(tmp...)
#     # end
#     return getLimitOrders(sortLimitOrders(bets)...)
# end


function probToPool(p, pool, targetProb)
    p = p
    k = pool[:YES]^p * pool[:NO]^(1-p)

    ephi = p*(targetProb - 1) / (targetProb * (p-1))
    noShares = k * ephi^(-p)
    yesShares = ephi * noShares

    # return Dict(:NO=>noShares, :YES=>yesShares)
    return (NO=noShares, YES=yesShares)
end

poolToProb(p, pool) = p * pool[:NO] / (p * pool[:NO] + (1-p) * pool[:YES])

@inline @fastmath function betCPPM(p, pool, betAmount, outcome)
    # betAmount = max(betAmount - .1, 0.) # Fee?

    y = pool[:YES]
    n = pool[:NO]

    # implement Maniswap
    k = y^p * n^(1-p)

    y += betAmount
    n += betAmount

    if outcome == :YES
        newPool = (NO=n, YES=(k / n^(1-p))^(1/p))
        newProb = poolToProb(p, newPool)
        shares = y - (k / n^(1-p))^(1/p)
    elseif outcome == :NO
        newPool = (NO=(k / y^p)^(1/(1 - p)), YES=y)
        newProb = poolToProb(p, newPool)
        shares = n - (k / y^p)^(1/(1 - p))
    end

    return (shares=shares, probability=newProb, pool=newPool)
end

changeInPool(oldPool, newPool) = (NO=newPool[:NO] - oldPool[:NO], YES=newPool[:YES] - oldPool[:YES])
# changeInPool(oldPool, newPool) = (NO=newPool.NO - oldPool.NO, YES=newPool.YES - oldPool.YES)

## ASSUMING NO LIMIT ORDERS
function poolToBet(oldPool, newPool)
    ΔPool = changeInPool(oldPool, newPool)

    if ΔPool[:YES] > ΔPool[:NO]
        amount = ΔPool[:YES]
        outcome = :NO
        shares = ΔPool[:YES] - ΔPool[:NO]
    elseif ΔPool[:YES] < ΔPool[:NO]
        amount = ΔPool[:NO]
        outcome = :YES
        shares = ΔPool[:NO] - ΔPool[:YES]
    elseif isapprox(ΔPool[:YES], 0, atol=1e-6) && isapprox(ΔPool[:NO], 0., atol=1e-6)
        amount = 0.
        outcome = :NONE
        shares = 0.
    end

    return (outcome=outcome, amount=amount, shares=shares) # here outcome is which direction we are buying in.
end

@inline betToShares(market, limitOrders, sortedLimitProbs, betAmount) = betToShares(market.p, market.pool, market.probability, limitOrders, sortedLimitProbs, betAmount)

function betToShares(p, pool, probability, limitOrders, sortedLimitProbs, betAmount) # Include any limit orders that will be filled to get to targetProb (excludes targetProb)
    # limitOrders is a dict with price: amount, shares (amount and shares that I will buy, not what the limit order buys)

    oldPool = pool
    newProb = probability

    amount = 0.
    shares = 0.

    if -1 < betAmount < 1 # can only place bets >= 1 in magnitude
        return (shares=shares, probability=newProb)
    end

    outcome = betAmount > 0 ? :YES : :NO
    betAmount = abs(betAmount)

    for limitProb in sortedLimitProbs[outcome]
        limitAmountsShares = limitOrders[outcome][limitProb]

        # AMM
        newProb = limitProb
        newPool = probToPool(p, oldPool, limitProb)
        betToMake = poolToBet(oldPool, newPool)

        if amount + betToMake.amount >= betAmount
            newShares, newProb = betCPPM(p, oldPool, betAmount - amount, outcome)
            shares += newShares

            amount = betAmount
            break
        end

        amount += betToMake.amount
        shares += betToMake.shares

        oldPool = newPool
        
        # Limit Orders
        if amount + limitAmountsShares[1] >= betAmount
            if outcome == :YES
                shares += (betAmount - amount) / limitProb 
            elseif outcome == :NO
                shares += (betAmount - amount) / (1-limitProb) 
            end

            amount = betAmount

            break
        end

        amount += limitAmountsShares[1]
        shares += limitAmountsShares[2]
    end
    
    if amount < betAmount
        newShares, newProb = betCPPM(p, oldPool, betAmount - amount, outcome)
        shares += newShares

        amount = betAmount
    end

    return (shares=shares, probability=newProb)
end