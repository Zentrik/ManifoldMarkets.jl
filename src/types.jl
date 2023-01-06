"""Contains the various types of data that Manifold can return."""

export Bet, Market, User

using JSON, Parameters

const I = Int64
const F = Float64

Optional(T) = Union{T, Nothing}
# struct Optional{T} = Union{T, Nothing}

function stringKeysToSymbol(dict)
    return Dict(Symbol(key) => value for (key, value) in dict)
end

@with_kw struct Fill
    amount::F
    shares::F
    isSale::Optional(Bool) = nothing

    timestamp::I

    matchedBetId::Optional(String) = nothing
end

# function Fill(; amount, shares, timestamp, matchedBetId=nothing, isSale=nothing)
#     Fill(amount, shares, isSale, timestamp, matchedBetId)
# end

function Fill(dict::Dict{String, Any})
    return Fill(;stringKeysToSymbol(dict)...)
end

@with_kw struct Bet @deftype F
    """Represents a bet."""

    amount
    shares
    sharesByOutcome::Optional(Dict{String, F}) = nothing
    outcome::String
    contractId::String # Market ID
    createdTime::I
    id::String
    limitProb::Optional(F) = nothing

    loanAmount::Optional(F) = nothing
    userId::Optional(String) = nothing # not returned when making a bet
    userAvatarUrl::Optional(String) = nothing # not returned when making a bet
    userUsername::Optional(String) = nothing # not returned when making a bet
    userName::Optional(String) = nothing # not returned when making a bet

    orderAmount::Optional(F) = nothing
    isFilled::Optional(Bool) = nothing
    fills::Optional(Vector{Fill}) = nothing

    fees::Optional(Dict{String, F}) = nothing

    isCancelled::Optional(Bool) = nothing
    isRedemption::Bool

    sale::Optional(Dict{String, Any}) = nothing

    probBefore
    probAfter

    isAnte::Bool
    isChallenge::Bool
    isSold::Optional(Bool) = nothing
    challengeSlug::Optional(String) = nothing
    isLiquidityProvision::Optional(Bool) = nothing
    dpmShares::Optional(F) = nothing
end

function Bet(dict::Dict{String, Any})
    symbolDict = stringKeysToSymbol(dict)

    if :fills in keys(symbolDict)
        symbolDict[:fills] = Fill.(symbolDict[:fills])
    end

    try
        return Bet(;symbolDict...)
    catch error
        display(dict)
        display(symbolDict)

        throw(error)
    end
end

@with_kw struct Market @deftype String
    """Represents a market."""

    # Unique identifer for this market
    id

    # Attributes about the creator
    creatorId
    creatorUsername
    creatorName
    createdTime::I # milliseconds since epoch
    creatorAvatarUrl

    # Market attributes. All times are in milliseconds since epoch
    closeTime::I # Min of creator's chosen date, and resolutionTime
    question
    tags::Vector{String}

    # This should not be optional, once market creation returns the URL in the response.
    # https://github.com/manifoldmarkets/manifold/issues/508
    url
    
    outcomeType # BINARY, FREE_RESPONSE, MULTIPLE_CHOICE, NUMERIC, or PSEUDO_NUMERIC
    mechanism # dpm-2 or cpmm-1

    probability::Optional(F) = nothing
    pool::Dict{Symbol, F}
    p::Optional(F) = nothing
    totalLiquidity::Optional(F) = nothing

    min::Optional(F) = nothing
    max::Optional(F) = nothing
    isLogScale::Optional(Bool) = nothing

    volume::F
    volume24Hours::F

    isResolved::Bool
    resolutionTime::Optional(I) = nothing
    resolution::Optional(String) = nothing
    resolutionProbability::Optional(F) = nothing

    lastUpdatedTime::Optional(I) = nothing

    answers::Optional(Vector{String}) = nothing

    description::Optional(Union{Dict{String, Any}, String}) = nothing
    textDescription::Optional(String) = nothing
end

function Market(dict::Dict{String, Any})
    symbolDict = stringKeysToSymbol(dict)
    symbolDict[:pool] = stringKeysToSymbol(symbolDict[:pool])
    try
        return Market(;symbolDict...)
    catch error
        display(dict)
        display(symbolDict)

        throw(error)
    end
end

# @with_kw struct Group
#     """Represents a group."""

#     name::String
#     creatorId::String
#     id::String
#     contractIds::Vector{String}
#     mostRecentActivityTime::I
#     anyoneCanJoin::Bool
#     mostRecentContractAddedTime::I
#     createdTime::I
#     memberIds::Vector{String}
#     slug::String
#     about::String
# end

# function Group(dict::Dict{String, Any})
#     symbolDict = stringKeysToSymbol(dict)

#     try
#         return Group(;symbolDict...)
#     catch error
#         display(dict)
#         display(symbolDict)

#         throw(error)
#     end
# end

@with_kw struct User # For some reason @with_kw is necessary
    """Basic information about a user."""

    id::String  # user's unique id
    createdTime::F  # as usual, in ms since epoch

    name::String  # display name, may contain spaces
    username::String  # username, used in urls
    url::String  # link to user's profile
    avatarUrl::String

    bio::Optional(String) = nothing
    bannerUrl::Optional(String) = nothing
    website::Optional(String) = nothing
    twitterHandle::Optional(String) = nothing
    discordHandle::Optional(String) = nothing

    # Note: the following are here for convenience only and may be removed in the future.
    balance::F
    totalDeposits::F
    profitCached::Dict{Symbol, F}
end

function User(dict::Dict{String, Any})
    symbolDict = stringKeysToSymbol(dict)

    symbolDict[:profitCached] = stringKeysToSymbol(symbolDict[:profitCached])

    try
        return User(;symbolDict...)
    catch error
        display(dict)
        display(symbolDict)

        throw(error)
    end
end