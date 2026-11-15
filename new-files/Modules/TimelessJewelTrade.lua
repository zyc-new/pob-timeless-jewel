-- Path of Building
--
-- Module: Timeless Jewel Trade
-- Shared trade URL builder for timeless jewel seeds.
-- This mirrors the query built by TreesTab:FindTimelessJewel's "Open Trade URL".

local dkjson = require "dkjson"

local TimelessJewelTrade = { }

--- Build a pathofexile.com trade search URL for a list of seeds.
--- config = {
---   jewelType = { id=..., name=... },
---   conqueror = { id=..., label=... },
---   seeds = { number, ... },
---   realm = "pc"|"sony"|"xbox",
---   league = string,
---   tradeType = "securable"|"available"|"onlineleague"|"online"|"any",
--- }
function TimelessJewelTrade.BuildUrl(config)
	if not data.timelessJewelTradeIDs[config.jewelType.id] then
		return nil
	end

	local seedTrades = { }
	local keystoneTradeIds = data.timelessJewelTradeIDs[config.jewelType.id].keystone
	local conquerorTradeIds
	if config.jewelType.id >= 7 then
		conquerorTradeIds = { keystoneTradeIds[1] }
	elseif config.conqueror.id > 1 then
		conquerorTradeIds = { keystoneTradeIds[config.conqueror.id - 1] }
	else
		conquerorTradeIds = { keystoneTradeIds[1], keystoneTradeIds[2], keystoneTradeIds[3] }
	end

	for _, seed in ipairs(config.seeds or { }) do
		for _, tradeId in ipairs(conquerorTradeIds) do
			seedTrades[#seedTrades + 1] = {
				id = tradeId,
				value = {
					min = seed,
					max = seed,
				},
			}
		end
	end
	if #seedTrades == 0 then
		return nil
	end

	local search = {
		query = {
			status = {
				option = config.tradeType or "any",
			},
			stats = {
				{
					filters = seedTrades,
					type = "count",
					value = {
						min = 1,
					},
				},
			},
		},
		sort = {
			price = "asc",
		},
	}

	local realm = (config.realm or "pc"):lower()
	local realmPath = realm == "pc" and "" or (realm .. "/")
	local encoded = dkjson.encode(search):gsub("[^a-zA-Z0-9]", function(char)
		return string.format("%%%02X", string.byte(char))
	end)
	return "https://www.pathofexile.com/trade/search/" .. realmPath .. (config.league or "Standard") .. "/?q=" .. encoded
end

return TimelessJewelTrade
