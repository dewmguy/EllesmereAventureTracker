-------------------------------------------------------------------------------
-- Adventure Tracker: optional market-price adapters.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local function PublicNumber(value)
    if type(value) ~= "number" then return nil end
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    if value <= 0 then return nil end
    return value
end

local function TSMItemString(itemID, itemLink)
    local api = _G.TSM_API
    if type(api) == "table" and type(api.ToItemString) == "function" and itemLink then
        local ok, value = pcall(api.ToItemString, itemLink)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    return itemID and ("i:" .. tostring(itemID)) or nil
end

local SOURCES = {
    {
        key = "tsm",
        name = "TradeSkillMaster",
        ready = function()
            return type(_G.TSM_API) == "table"
                and type(_G.TSM_API.GetCustomPriceValue) == "function"
        end,
        price = function(itemID, itemLink)
            local itemString = TSMItemString(itemID, itemLink)
            if not itemString then return nil end
            local ok, value = pcall(_G.TSM_API.GetCustomPriceValue, "DBMarket", itemString)
            value = ok and PublicNumber(value) or nil
            if value then return value, "DBMarket" end
            ok, value = pcall(_G.TSM_API.GetCustomPriceValue, "DBMinBuyout", itemString)
            value = ok and PublicNumber(value) or nil
            return value, value and "DBMinBuyout" or nil
        end,
    },
    {
        key = "auctionator",
        name = "Auctionator",
        ready = function()
            local api = _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1
            return type(api) == "table" and type(api.GetAuctionPriceByItemID) == "function"
        end,
        price = function(itemID)
            if not itemID then return nil end
            local api = _G.Auctionator.API.v1
            local ok, value = pcall(api.GetAuctionPriceByItemID, ADDON_NAME, itemID)
            value = ok and PublicNumber(value) or nil
            return value, value and "last auction scan" or nil
        end,
    },
}

function ns.GetPriceProvider()
    if ns.Get("showProfessionMarketCosts") == false then return nil end
    for index = 1, #SOURCES do
        local source = SOURCES[index]
        local ok, ready = pcall(source.ready)
        if ok and ready then return source end
    end
    return nil
end

function ns.GetPriceProviderName()
    local source = ns.GetPriceProvider()
    return source and source.name or nil
end

function ns.GetMarketPrice(itemID, itemLink)
    local source = ns.GetPriceProvider()
    if not source then return nil end
    local ok, value, basis = pcall(source.price, tonumber(itemID), itemLink)
    value = ok and PublicNumber(value) or nil
    if not value then return nil end
    return value, source.name, basis
end

function ns.FormatMarketPrice(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    if gold > 0 then return string.format("%dg %ds %dc", gold, silver, copper) end
    if silver > 0 then return string.format("%ds %dc", silver, copper) end
    return string.format("%dc", copper)
end
