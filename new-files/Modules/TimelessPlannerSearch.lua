-- Path of Building
--
-- Module: Timeless Jewel Planner Search
-- Hard-constraint search for the Timeless Jewel Planner.
--
-- This module is intentionally independent from TreeTab:FindTimelessJewel.
-- It only reads the tree/data and returns seeds that satisfy the configured
-- constraints.

local ipairs = ipairs
local pairs = pairs
local next = next

local TimelessPlannerSearch = { }

local function getLegionNode(treeData, localId)
	if not localId or localId < data.timelessJewelAdditions then
		return nil
	end
	return treeData.legion.nodes[localId + 1 - data.timelessJewelAdditions]
end

local function getAdditionNode(treeData, localId)
	if not localId then
		return nil
	end
	return treeData.legion.additions[localId + 1]
end

local function makeOutcome(node, kind)
	if not node or not node.id then
		return nil
	end
	local key = kind == "addition" and ("add:" .. node.id) or node.id
	return {
		id = node.id,
		key = key,
		kind = kind,
		dn = node.dn,
		stats = node.stats,
		sortedStats = node.sortedStats,
		ks = node.ks,
		node = node,
	}
end

--- Return replacement and fixed-addition outcomes for a core notable.
--- Some jewels (e.g. Lethal Pride) add a stat to a notable instead of replacing it;
--- those additions must be selectable too.
local function getCoreResults(seed, nodeId, socketId, jewelType, treeData, isAbyss, abyssMods)
	if isAbyss then
		local modification = abyssMods and abyssMods[nodeId]
		if not modification then
			return { }
		end
		local results = { }
		for _, component in ipairs(modification) do
			local changedNode, replacesNode = data.resolveAbyssJewelComponent(component, treeData.legion)
			if changedNode then
				-- Abyss jewels can add a component without replacing the node.
				-- Both replacement and addition components are selectable.
				local outcome = makeOutcome(changedNode, replacesNode and "replacement" or "addition")
				if outcome then
					results[#results + 1] = outcome
				end
			end
		end
		return results
	end

	local jewelDataTbl = data.readLUT(seed, nodeId, jewelType.id)
	if not jewelDataTbl or not next(jewelDataTbl) then
		return { }
	end

	local results = { }
	if jewelType.id == 1 then
		if #jewelDataTbl == 2 or #jewelDataTbl == 3 then
			local node = getLegionNode(treeData, jewelDataTbl[1])
			local outcome = makeOutcome(node, "replacement")
			if outcome then
				results[1] = outcome
			end
		elseif #jewelDataTbl == 6 or #jewelDataTbl == 8 then
			-- Glorious Vanity Might/Legacy records: the first half are fixed additions.
			for i = 1, (#jewelDataTbl / 2) do
				local node = getAdditionNode(treeData, jewelDataTbl[i])
				local outcome = makeOutcome(node, "addition")
				if outcome then
					results[#results + 1] = outcome
				end
			end
		end
		return results
	end

	local localId = jewelDataTbl[1]
	if localId >= data.timelessJewelAdditions then
		local node = getLegionNode(treeData, localId)
		local outcome = makeOutcome(node, "replacement")
		if outcome then
			results[1] = outcome
		end
	else
		local node = getAdditionNode(treeData, localId)
		local outcome = makeOutcome(node, "addition")
		if outcome then
			results[1] = outcome
		end
	end
	return results
end

function TimelessPlannerSearch.Run(build, config)
	local treeData = build.spec.tree
	local jewelType = config.jewelType
	local socketId = config.socketId
	local isAbyss = jewelType.id >= 7
	local zorathPath = jewelType.id == 11 and build.spec:GetShortestPathToClassStart(socketId) or nil
	if jewelType.id == 11 and not zorathPath then
		return { }
	end

	local coreNodes = config.coreNodes or { }

	local seedMultiplier = jewelType.id == 5 and 20 or 1
	local results = { }
	for seed = data.timelessJewelSeedMin[jewelType.id] * seedMultiplier,
			data.timelessJewelSeedMax[jewelType.id] * seedMultiplier,
			seedMultiplier do
		local ok = true
		local abyssMods
		if isAbyss then
			abyssMods = data.readAbyssJewelLUT(seed, socketId, jewelType.id, zorathPath, build.spec.curAscendClassName)
		end

		-- Core: count how many of the configured cores match. When more than
		-- one core is configured this is a ranked soft constraint (at least one
		-- hit), not a hard all-must-match filter.
		local coreHits = 0
		local coreTotal = 0
		for _, core in ipairs(coreNodes) do
			if next(core.outcomes) then
				coreTotal = coreTotal + 1
				local coreResults = getCoreResults(seed, core.nodeId, socketId, jewelType, treeData, isAbyss, abyssMods)
				for _, outcome in ipairs(coreResults) do
					if core.outcomes[outcome.key] or core.outcomes[outcome.id] then
						coreHits = coreHits + 1
						break
					end
				end
			end
		end
		if coreTotal > 0 and coreHits == 0 then
			ok = false
		end

		if ok then
			results[#results + 1] = {
				seed = seed,
				socketId = socketId,
				coreHits = coreHits,
				coreTotal = coreTotal,
			}
		end
	end

	table.sort(results, function(a, b)
		if a.coreHits ~= b.coreHits then
			return a.coreHits > b.coreHits
		end
		return a.seed < b.seed
	end)
	return results
end

return TimelessPlannerSearch
