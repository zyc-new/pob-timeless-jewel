-- Path of Building
--
-- Timeless Jewel Planner
-- A new, independent popup for hard-constraint timeless jewel searches.
--
-- This module intentionally does not call TreeTab:FindTimelessJewel or mutate
-- timelessData. It only reads the allocated tree and timeless jewel data.

local ipairs = ipairs
local pairs = pairs
local next = next
local t_insert = table.insert
local t_sort = table.sort
local m_min = math.min
local m_max = math.max

local TimelessPlannerSearch = LoadModule("Modules/TimelessPlannerSearch")
local TimelessJewelTrade = LoadModule("Modules/TimelessJewelTrade")

local jewelTypes = {
	{ label = "Glorious Vanity", name = "vaal", id = 1 },
	{ label = "Lethal Pride", name = "karui", id = 2 },
	{ label = "Brutal Restraint", name = "maraketh", id = 3 },
	{ label = "Militant Faith", name = "templar", id = 4 },
	{ label = "Elegant Hubris", name = "eternal", id = 5 },
	{ label = "Heroic Tragedy", name = "kalguur", id = 6 },
	{ label = "Festering Vengeance", name = "abyss_murderous", id = 7 },
	{ label = "Extinguishing Grasp", name = "abyss_searching", id = 8 },
	{ label = "Baleful Dominion", name = "abyss_hypnotic", id = 9 },
	{ label = "Destructive Aspiration", name = "abyss_ghastly", id = 10 },
	{ label = "Reclaimed Malevolence", name = "abyss_special", id = 11 },
}

local conquerorTypes = {
	[1] = {
		{ label = "Any", id = 1 },
		{ label = "Doryani (Corrupted Soul)", id = 2 },
		{ label = "Xibaqua (Divine Flesh)", id = 3 },
		{ label = "Ahuana (Immortal Ambition)", id = 4 },
	},
	[2] = {
		{ label = "Any", id = 1 },
		{ label = "Kaom (Strength of Blood)", id = 2 },
		{ label = "Rakiata (Tempered by War)", id = 3 },
		{ label = "Akoya (Chainbreaker)", id = 4 },
	},
	[3] = {
		{ label = "Any", id = 1 },
		{ label = "Asenath (Dance with Death)", id = 2 },
		{ label = "Nasima (Second Sight)", id = 3 },
		{ label = "Balbala (The Traitor)", id = 4 },
	},
	[4] = {
		{ label = "Any", id = 1 },
		{ label = "Avarius (Power of Purpose)", id = 2 },
		{ label = "Dominus (Inner Conviction)", id = 3 },
		{ label = "Maxarius (Transcendence)", id = 4 },
	},
	[5] = {
		{ label = "Any", id = 1 },
		{ label = "Cadiro (Supreme Decadence)", id = 2 },
		{ label = "Victario (Supreme Grandstanding)", id = 3 },
		{ label = "Caspiro (Supreme Ostentation)", id = 4 },
	},
	[6] = {
		{ label = "Any", id = 1 },
		{ label = "Vorana (Black Scythe Training)", id = 2 },
		{ label = "Uhtred (Celestial Mathematics)", id = 3 },
		{ label = "Medved (The Unbreaking Circle)", id = 4 },
	},
	[7] = { { label = "Tecrod (Overwhelming Hate)", id = 1 } },
	[8] = { { label = "Ulaman (Weighted Exchange)", id = 1 } },
	[9] = { { label = "Kurgal (Reconstructed Essence)", id = 1 } },
	[10] = { { label = "Amanamu (The Loyal Few)", id = 1 } },
	[11] = { { label = "Zorath", id = 1 } },
}

local function getConqueror(typeId, conquerorId)
	local list = conquerorTypes[typeId] or { { label = "Any", id = 1 } }
	for _, conqueror in ipairs(list) do
		if conqueror.id == conquerorId then
			return conqueror
		end
	end
	return list[1]
end

local function getConquerorIndex(typeId, conquerorId)
	local list = conquerorTypes[typeId] or { { label = "Any", id = 1 } }
	for index, conqueror in ipairs(list) do
		if conqueror.id == conquerorId then
			return index
		end
	end
	return 1
end

local STAT_LABELS = {
	strength = "力量",
	dexterity = "敏捷",
	intelligence = "智力",
	devotion = "Devotion",
	maximum_life = "生命",
	maximum_mana = "魔力",
	maximum_energy_shield = "能量护盾",
	armour = "护甲",
	evasion = "闪避",
	ward = "Ward",
	accuracy_rating = "命中值",
	["accuracy_rating_+%"] = "命中值",
	critical_strike_chance = "暴击率",
	life_regeneration = "生命回复",
	["life_regeneration_rate_per_minute_%"] = "生命回复",
	mana_regeneration = "魔力回复",
	["mana_regeneration_rate_per_minute_%"] = "魔力回复",
	block_chance = "格挡率",
	spell_block_chance = "法术格挡率",
	["movement_speed_+%"] = "移动速度",
	["attack_speed_+%"] = "攻击速度",
	["cast_speed_+%"] = "施法速度",
	["fire_resistance_+%"] = "火焰抗性",
	["cold_resistance_+%"] = "冰霜抗性",
	["lightning_resistance_+%"] = "闪电抗性",
	["chaos_resistance_+%"] = "混沌抗性",
	["curse_effect_+%"] = "诅咒效果",
	["add_frenzy_charge_on_kill_%"] = "击杀获得狂怒球",
	["fire_damage_+%"] = "火焰伤害",
	["cold_damage_+%"] = "冰霜伤害",
	["lightning_damage_+%"] = "闪电伤害",
	["chaos_damage_+%"] = "混沌伤害",
	["physical_damage_+%"] = "物理伤害",
	["spell_damage_+%"] = "法术伤害",
	["attack_damage_+%"] = "攻击伤害",
	["elemental_damage_+%"] = "元素伤害",
}

local function statLabel(key)
	return STAT_LABELS[key] or key
end

local function coreOutcomeAttributeCount(build, state, nodeId)
	local outcomes = state.coreOutcomes and state.coreOutcomes[nodeId]
	if not outcomes then
		return 0
	end
	local seen = { }
	for key in pairs(outcomes) do
		local node
		local id = key
		if key:sub(1, 4) == "add:" then
			id = key:sub(5)
			for _, addition in pairs(build.spec.tree.legion.additions) do
				if addition.id == id then
					node = addition
					break
				end
			end
		else
			for _, legionNode in pairs(build.spec.tree.legion.nodes) do
				if legionNode.id == id then
					node = legionNode
					break
				end
			end
		end
		local primary = node and node.sortedStats and node.sortedStats[1]
		local label = primary and statLabel(primary) or (node and node.dn) or id
		seen[label] = true
	end
	local count = 0
	for _ in pairs(seen) do
		count = count + 1
	end
	return count
end

local function coreOutcomeSummary(build, state, nodeId)
	local outcomes = state.coreOutcomes and state.coreOutcomes[nodeId]
	if not outcomes then
		return nil
	end
	local labels = { }
	local seen = { }
	local count = 0
	for id in pairs(outcomes) do
		count = count + 1
		local node
		for _, legionNode in pairs(build.spec.tree.legion.nodes) do
			if legionNode.id == id then
				node = legionNode
				break
			end
		end
		local label
		if node then
			local primary = node.sortedStats and node.sortedStats[1]
			label = primary and statLabel(primary) or node.dn or id
		else
			label = id
		end
		if label and not seen[label] then
			seen[label] = true
			labels[#labels + 1] = label
		end
	end
	table.sort(labels)
	if #labels == 0 then
		return count > 0 and (count .. " 个结果") or nil
	end
	if #labels <= 3 then
		return table.concat(labels, " / ")
	end
	return labels[1] .. " / " .. labels[2] .. " 等 " .. #labels .. " 项"
end

-- Generic scrollable list used for core nodes and results.
local PlannerListClass = newClass("TimelessPlannerList", "ListControl", function(self, anchor, rect, list)
	self.ListControl(anchor, rect, 18, true, false, list)
end)

function PlannerListClass:GetRowValue(column, index, value)
	return value.label or tostring(value)
end

local function newList(anchor, rect, list)
	return new("TimelessPlannerList", anchor or { "TOPLEFT", nil, "TOPLEFT" }, rect, list)
end

-- Result list with a dedicated checkbox hit area. ListControl only fires
-- OnSelClick when the selected index changes, so a subclass is needed to make
-- the checkbox toggle reliably even when the same row is clicked twice.
local PlannerResultListClass = newClass("TimelessPlannerResultList", "ListControl", function(self, anchor, rect, list, onCheck, onPreview)
	self.ListControl(anchor, rect, 18, true, false, list)
	self.onCheck = onCheck
	self.onPreview = onPreview
end)

function PlannerResultListClass:GetRowValue(column, index, value)
	return value.label or tostring(value)
end

function PlannerResultListClass:OnKeyDown(key, doubleClick)
	if key == "LEFTBUTTON" and self:IsShown() and self:IsEnabled() and self:IsMouseOver() then
		local x, y = self:GetPos()
		local cursorX, cursorY = GetCursorPos()
		local rowRegion = self:GetRowRegion()
		if cursorX >= x + rowRegion.x and cursorY >= y + rowRegion.y
				and cursorX < x + rowRegion.x + rowRegion.width
				and cursorY < y + rowRegion.y + rowRegion.height then
			local index = math.floor((cursorY - y - rowRegion.y + self.controls.scrollBarV.offset) / self.rowHeight) + 1
			local value = self.list[index]
			if value then
				-- Clicking the checkbox area toggles the check without previewing.
				if self.onCheck and cursorX <= x + rowRegion.x + 30 then
					self.onCheck(index, value)
					self:SelectIndex(index)
					return
				end
				-- A double-click on the row previews the seed.
				if doubleClick and self.onPreview then
					self:SelectIndex(index)
					self.onPreview(index, value)
					return
				end
				-- A single click anywhere on the row also marks it as selected
				-- (checked), so the visual checkbox always matches the row state.
				if self.onCheck then
					self.onCheck(index, value)
					self:SelectIndex(index)
					return
				end
			end
		end
	end
	return self.ListControl.OnKeyDown(self, key, doubleClick)
end

local function sortedByLabel(list)
	t_sort(list, function(a, b)
		return (a.label or "") < (b.label or "")
	end)
	return list
end

local Planner = { }

function Planner.Open(treeTab)
	local build = treeTab.build
	local treeData = build.spec.tree
	local controls = { }
	local refreshingCore = false
	local keystoneDropdowns = { }
	local state = build.timelessPlannerState or {
		jewelTypeId = 1,
		conquerorId = 1,
		socketId = nil,
		coreOutcomes = { },

		results = { },
		checkedSeeds = { },
		page = 1,
	}
	build.timelessPlannerState = state

	local selectedType = jewelTypes[state.jewelTypeId] or jewelTypes[1]
	local selectedConqueror = nil
	local selectedSocketId = state.socketId
	local coreRows = { }
	local keystoneRows = { }

	local function getJewelSocketList()
		local sockets = { }
		for nodeId, node in pairs(build.spec.nodes) do
			if node.isJewelSocket and node.name ~= "Charm Socket" then
				local lit = build.spec.allocNodes[nodeId] ~= nil
				if lit then
					t_insert(sockets, {
						label = (node.dn or node.name or "Jewel Socket") .. " [" .. nodeId .. "]",
						id = nodeId,
					})
				end
			end
		end
		t_sort(sockets, function(a, b) return a.label < b.label end)
		return sockets
	end

	local sockets = getJewelSocketList()
	if selectedSocketId ~= nil then
		local valid = false
		for _, socket in ipairs(sockets) do
			if socket.id == selectedSocketId then
				valid = true
				break
			end
		end
		if not valid then
			selectedSocketId = nil
		end
	end
	if selectedSocketId == nil and sockets[1] then
		selectedSocketId = sockets[1].id
	end
	state.socketId = selectedSocketId

	local function getConqueror(typeId, conquerorId)
		local list = conquerorTypes[typeId] or { { label = "Any", id = 1 } }
		for _, conqueror in ipairs(list) do
			if conqueror.id == conquerorId then
				return conqueror
			end
		end
		return list[1]
	end
	selectedConqueror = getConqueror(selectedType.id, state.conquerorId)

	local function getLitNodes(socketId)
		local core, keystones = { }, { }
		local socketNode = treeData.nodes[socketId]
		if not socketNode or not socketNode.nodesInRadius then
			return core, keystones
		end
		local radius = socketNode.nodesInRadius[3] or { }
		local granted = build.calcsTab.mainEnv.grantedPassives or { }
		for nodeId in pairs(radius) do
			local node = treeData.nodes[nodeId]
			local lit = build.spec.allocNodes[nodeId] ~= nil or granted[nodeId] ~= nil
			if node and lit and not node.ascendancyName then
				if node.isKeystone then
					t_insert(keystones, { label = node.dn, node = node })
				elseif node.isNotable then
					t_insert(core, { label = node.dn, node = node })
				end
			end
		end
		sortedByLabel(core)
		sortedByLabel(keystones)
		return core, keystones
	end

	local function refreshNodes()
		if not selectedSocketId then
			coreRows, keystoneRows = { }, { }
			return
		end
		coreRows, keystoneRows = getLitNodes(selectedSocketId)
	end
	refreshNodes()

	local function getCoreOutcomeCount(core)
		local outcomes = state.coreOutcomes[core.node.id]
		local count = 0
		if outcomes then
			for _ in pairs(outcomes) do
				count = count + 1
			end
		end
		return count
	end

	local function refreshCoreLabels()
		for _, row in ipairs(coreRows) do
			if row.button then
				local count = coreOutcomeAttributeCount(build, state, row.node.id)
				row.button.label = count > 0 and ("已选 " .. count .. " 个属性") or "选择可接受结果..."
			end
		end
	end

	local function refreshKeystoneInfo()
		if controls.keystoneInfo then
			if #keystoneRows == 0 then
				controls.keystoneInfo.label = "^8没有已点亮 keystone"
			else
				local names = { }
				for _, row in ipairs(keystoneRows) do
					t_insert(names, row.node.dn)
				end
				local nameText = names[1] .. (#names > 1 and (" 等 " .. #names .. " 个") or "")
				local conqName = selectedConqueror.label:match("^[^%(]+") or selectedConqueror.label
				controls.keystoneInfo.label = "^7" .. nameText .. " → " .. conqName
			end
		end
	end

	-- Top controls
	controls.typeLabel = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 18, 0, 16 }, "^7珠宝类型:")
	controls.typeSelect = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { 100, 16, 210, 20 }, jewelTypes, function(index, value)
		state.coreOutcomes = { }
		state.results = { }
		state.checkedSeeds = { }
		state.page = 1
		state.jewelTypeId = value.id
		local list = conquerorTypes[value.id] or { { label = "Any", id = 1 } }
		state.conquerorId = list[1].id
		-- Rebuilding the popup is required because the visible core/keystone
		-- row controls belong to the old node table. Refreshing only labels
		-- would leave stale "已选 N 个属性" buttons on screen.
		main:ClosePopup()
		Planner.Open(treeTab)
	end)
	controls.typeSelect:SetSel(state.jewelTypeId, true)

	controls.conquerorLabel = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 330, 18, 0, 16 }, "^7征服者")
	controls.conquerorSelect = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { 400, 16, 220, 20 }, conquerorTypes[selectedType.id], function(index, value)
		selectedConqueror = value
		state.conquerorId = value.id
		for _, dropdown in ipairs(keystoneDropdowns) do
			dropdown:SetSel(index, true)
		end
		refreshKeystoneInfo()
	end)
	controls.conquerorSelect:SetSel(getConquerorIndex(selectedType.id, state.conquerorId), true)

	controls.socketLabel = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 640, 18, 0, 16 }, "^7珠宝孔")
	controls.socketSelect = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { 710, 16, 250, 20 }, sockets, function(index, value)
		if state.socketId ~= value.id then
			state.coreOutcomes = { }
			state.results = { }
			state.checkedSeeds = { }
			state.page = 1
		end
		state.socketId = value.id
		main:ClosePopup()
		Planner.Open(treeTab)
	end)

	controls.refreshButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 980, 16, 80, 20 }, "刷新树状态", function()
		main:ClosePopup()
		Planner.Open(treeTab)
	end)

	treeTab.tradeLeaguesList = treeTab.tradeLeaguesList or { }
	local realmList = treeTab.realmList or { "PC", "Sony", "Xbox" }
	local tradeTypeLabels = {
		"Instant buyout",
		"Instant buyout and in person",
		"In person (online in league)",
		"In person (online)",
		"Any (includes offline)",
	}
	local tradeTypeKeys = { "securable", "available", "onlineleague", "online", "any" }
	local defaultLeagueList = { "Standard", "Hardcore", "Ruthless", "Hardcore Ruthless" }

	local updateLeagues
	controls.realmLabel = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 48, 0, 16 }, "^7渠道:")
	controls.realmSelect = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { 70, 46, 80, 20 }, realmList, function(index, value)
		treeTab.selectedRealmIndex = index
		treeTab.selectedRealm = value
		if updateLeagues then
			updateLeagues()
		end
	end)
	controls.realmSelect:SetSel(treeTab.selectedRealmIndex or 1, true)

	controls.leagueLabel = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 160, 48, 0, 16 }, "^7联盟:")
	controls.leagueSelect = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { 220, 46, 150, 20 }, defaultLeagueList, function(index, value)
		treeTab.timelessJewelLeagueSelect = value
	end)

	controls.tradeTypeLabel = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 380, 48, 0, 16 }, "^7方式:")
	controls.tradeTypeSelect = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { 440, 46, 170, 20 }, tradeTypeLabels, function(index, value)
		treeTab.tradeTypeIndex = index
	end)
	controls.tradeTypeSelect:SetSel(treeTab.tradeTypeIndex or 1, true)

	controls.status = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 620, 48, 0, 16 }, "")

	local function applyLeagueList(list)
		if not controls.leagueSelect then
			return
		end
		controls.leagueSelect:SetList(list)
		local wanted = treeTab.timelessJewelLeagueSelect
		if wanted then
			for i, league in ipairs(list) do
				if league == wanted then
					controls.leagueSelect:SetSel(i, true)
					return
				end
			end
		end
		controls.leagueSelect:SetSel(1, true)
	end

	updateLeagues = function()
		local realm = controls.realmSelect:GetSelValue():lower()
		local list = treeTab.tradeLeaguesList and treeTab.tradeLeaguesList[realm]
		if list and #list > 0 then
			applyLeagueList(list)
			return
		end

		list = copyTable(defaultLeagueList)
		treeTab.tradeLeaguesList[realm] = list
		applyLeagueList(list)

		if not treeTab.tradeQueryRequests then
			treeTab.tradeQueryRequests = new("TradeQueryRequests")
		end
		treeTab.tradeQueryRequests:FetchLeagues(realm, function(leagues, errMsg)
			if errMsg or not leagues then
				return
			end
			local merged = copyTable(leagues)
			for _, league in ipairs(list) do
				if not isValueInTable(merged, league) then
					t_insert(merged, league)
				end
			end
			treeTab.tradeLeaguesList[realm] = merged
			if controls.realmSelect and controls.realmSelect:GetSelValue():lower() == realm then
				applyLeagueList(merged)
			end
		end)
	end

	updateLeagues()

	-- Per-node core/keystone rows: each row has its own right-side selector.
	controls.coreHeader = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 80, 0, 16 }, "^7核心天赋（已点亮）")
	local rowY = 104
	local maxRows = 11
	local function addCoreRow(row, isKeystone)
		if rowY > 104 + (maxRows - 1) * 28 then
			return
		end
		controls["rowLabel" .. rowY] = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 30, rowY, 250, 16 },
			(isKeystone and "^9[K] " or "^7") .. row.node.dn)
		if isKeystone then
			local dropdown = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, { 300, rowY - 2, 300, 20 },
				conquerorTypes[selectedType.id], function(index, value)
					selectedConqueror = value
					state.conquerorId = value.id
					controls.conquerorSelect:SetSel(index, true)
					for _, other in ipairs(keystoneDropdowns) do
						other:SetSel(index, true)
					end
					refreshKeystoneInfo()
				end)
			row.dropdown = dropdown
			dropdown:SetSel(getConquerorIndex(selectedType.id, state.conquerorId), true)
			controls["rowSelect" .. rowY] = dropdown
			t_insert(keystoneDropdowns, dropdown)
		else
			local button
			button = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 300, rowY - 2, 300, 20 },
				"选择可接受结果...", function()
					Planner.OpenCorePicker(treeTab, row, state, selectedType, button)
				end)
			row.button = button
			controls["rowButton" .. rowY] = button
		end
		rowY = rowY + 28
	end
	for _, row in ipairs(keystoneRows) do
		addCoreRow(row, true)
	end
	for _, row in ipairs(coreRows) do
		addCoreRow(row, false)
	end
	if #keystoneRows + #coreRows == 0 then
		controls.coreEmpty = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 30, 104, 0, 16 }, "^8没有已点亮、半径内的核心天赋")
	end

	-- Results
	controls.resultsHeader = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 416, 0, 16 }, "^7搜索结果")
	controls.resultsInfo = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 120, 416, 0, 16 }, "^8单击勾选 · 双击预览")
	controls.resultsList = new("TimelessPlannerResultList", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 438, 1140, 190 }, { }, function(index, item)
		state.checkedSeeds = state.checkedSeeds or { }
		state.checkedSeeds[item.seed] = not state.checkedSeeds[item.seed] and true or nil
		item.checked = state.checkedSeeds[item.seed] == true
		item.label = (item.checked and "[√] " or "[ ] ") .. item.baseLabel
		controls.joinSelectedButton.enabled = next(state.checkedSeeds) ~= nil
	end, function(index, item)
		Planner.PreviewSeed(build, selectedType, selectedConqueror, item.seed, item.socketId)
	end)
	controls.resultsList.OnSelect = function(index, value)
		controls.joinSelectedButton.enabled = next(state.checkedSeeds or { }) ~= nil
	end

	controls.prevPageButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 636, 70, 20 }, "< 上一页", function()
		if state.page > 1 then
			state.page = state.page - 1
			Planner.RefreshResults(controls, state)
		end
	end)
	controls.nextPageButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 98, 636, 70, 20 }, "下一页 >", function()
		local pages = m_max(1, math.ceil(#state.results / 10))
		if state.page < pages then
			state.page = state.page + 1
			Planner.RefreshResults(controls, state)
		end
	end)
	controls.pageLabel = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 180, 636, 0, 16 }, "")

	controls.joinSelectedButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 300, 636, 100, 20 }, "加入勾选", function()
		local added = 0
		for _, result in ipairs(state.results or { }) do
			if state.checkedSeeds and state.checkedSeeds[result.seed] then
				Planner.AddSeed(build, selectedType, selectedConqueror, result.seed, result.socketId, nil, true)
				added = added + 1
			end
		end
		if controls.statusBar then
			controls.statusBar.label = added > 0 and string.format("^2已加入勾选 %d 个 seed", added) or "^8没有勾选结果"
		end
	end)
	controls.joinPageButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 408, 636, 120, 20 }, "加入本页 10 个", function()
		Planner.JoinPage(build, selectedType, selectedConqueror, state, controls)
	end)
	controls.buyButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 536, 636, 120, 20 }, "生成购买链接", function()
		Planner.BuyPage(state, controls, selectedType, selectedConqueror)
	end)
	controls.searchButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 664, 636, 120, 20 }, "开始精准搜索", function()
		Planner.RunSearch(build, selectedType, selectedConqueror, state, coreRows, controls)
	end)

	controls.resetButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 792, 636, 70, 20 }, "重置", function()
		state.coreOutcomes = { }
		state.results = { }
		state.checkedSeeds = { }
		state.page = 1
		refreshCoreLabels()
		Planner.RefreshResults(controls, state)
	end)
	controls.closeButton = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 1080, 636, 80, 20 }, "关闭", function()
		main:ClosePopup()
	end)

	controls.statusBar = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 666, 1140, 16 }, "")

	refreshCoreLabels()
	refreshKeystoneInfo()
	Planner.RefreshResults(controls, state)

	main:OpenPopup(1180, 700, "永恒珠宝精准规划", controls, nil, nil, "closeButton")
end

function Planner.OpenCorePicker(treeTab, coreRow, state, jewelType, button)
	local build = treeTab.build
	local treeData = build.spec.tree
	local selected = { }
	local existing = state.coreOutcomes[coreRow.node.id]
	if existing then
		for id in pairs(existing) do
			selected[id] = true
		end
	end

	local candidates = { }
	if state.socketId then
		for _, node in ipairs(TimelessPlannerSearch.GetCoreOutcomes(build, jewelType, state.socketId, coreRow.node.id)) do
			if node.id and not node.ks then
				local key = node.key or node.id
				local name = node.dn or node.id
				if node.kind == "addition" then
					name = "附加：" .. name
				end
				local baseLabel = name .. "  [" .. statLabel(node.sortedStats and node.sortedStats[1] or "") .. "]"
				t_insert(candidates, {
					label = (selected[key] and "[√] " or "[ ] ") .. baseLabel,
					baseLabel = baseLabel,
					id = key,
					node = node,
				})
			end
		end
	end
	t_sort(candidates, function(a, b) return a.label < b.label end)

	local controls = { }
	controls.info = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 20, 540, 16 }, "^7为 " .. coreRow.node.dn .. " 选择可接受结果；可多选")
	controls.list = newList(nil, { 20, 48, 540, 360 }, candidates)
	controls.list.selectedSet = selected
	controls.list.OnSelClick = function(index, value)
		-- ListControl versions differ in what they pass as the second argument;
		-- use the selected row's list entry whenever possible.
		local item = type(value) == "table" and value or controls.list.list[index] or (type(value) == "number" and controls.list.list[value])
		if type(item) == "table" and item.id then
			selected[item.id] = not selected[item.id] and true or nil
			item.label = (selected[item.id] and "[√] " or "[ ] ") .. (item.baseLabel or item.label)
		end
	end
	controls.clear = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 20, 424, 90, 20 }, "清空", function()
		for id in pairs(selected) do
			selected[id] = nil
		end
	end)
	controls.cancel = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 390, 424, 80, 20 }, "取消", function()
		main:ClosePopup()
	end)
	controls.done = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, { 480, 424, 80, 20 }, "确定", function()
		state.coreOutcomes[coreRow.node.id] = selected
		main:ClosePopup()
		if button then
			local count = coreOutcomeAttributeCount(build, state, coreRow.node.id)
			button.label = count > 0 and ("已选 " .. count .. " 个属性") or "选择可接受结果..."
		end
	end)
	main:OpenPopup(600, 470, "选择可接受结果", controls, nil, nil, "cancel")
end

function Planner.RefreshResults(controls, state)
	local results = state.results or { }
	local pages = m_max(1, math.ceil(#results / 10))
	state.page = m_min(m_max(state.page or 1, 1), pages)
	local startIndex = (state.page - 1) * 10 + 1
	local endIndex = m_min(startIndex + 9, #results)
	local pageRows = { }
	for i = startIndex, endIndex do
		local result = results[i]
		local checked = state.checkedSeeds and state.checkedSeeds[result.seed]
		local baseLabel
		if result.coreTotal and result.coreTotal > 0 then
			baseLabel = string.format("seed %d   |   命中 %d/%d 个核心   |   插槽 %s",
				result.seed, result.coreHits or 0, result.coreTotal, result.socketId or "?")
		else
			baseLabel = string.format("seed %d   |   插槽 %s", result.seed, result.socketId or "?")
		end
		pageRows[#pageRows + 1] = {
			label = (checked and "[√] " or "[ ] ") .. baseLabel,
			baseLabel = baseLabel,
			checked = checked == true,
			seed = result.seed,
			socketId = result.socketId,
		}
	end
	if controls.resultsList then
		controls.resultsList.list = pageRows
		if #pageRows > 0 then
			controls.resultsList:SelectIndex(1)
		else
			controls.resultsList.selIndex = nil
			controls.resultsList.selValue = nil
		end
	end
	if controls.resultsInfo then
		controls.resultsInfo.label = string.format("^7共 %d 个 seed · 第 %d/%d 页 · 每页 10 个 · ^8单击勾选 / 双击预览", #results, state.page, pages)
	end
	if controls.pageLabel then
		controls.pageLabel.label = string.format("^7%d / %d", state.page, pages)
	end
	if controls.prevPageButton then
		controls.prevPageButton.enabled = state.page > 1
	end
	if controls.nextPageButton then
		controls.nextPageButton.enabled = state.page < pages
	end
end

function Planner.RunSearch(build, jewelType, conqueror, state, coreRows, controls)
	local coreNodes = { }
	for _, row in ipairs(coreRows) do
		local outcomes = state.coreOutcomes[row.node.id]
		if outcomes and next(outcomes) then
			coreNodes[#coreNodes + 1] = {
				nodeId = row.node.id,
				outcomes = outcomes,
			}
		end
	end
	if not state.socketId then
		controls.statusBar.label = "^1没有已点亮的珠宝孔"
		return
	end
	controls.statusBar.label = "^7搜索中..."
	local started = GetTime()
	state.results = TimelessPlannerSearch.Run(build, {
		jewelType = jewelType,
		socketId = state.socketId,
		coreNodes = coreNodes,
	})
	state.checkedSeeds = { }
	state.page = 1
	Planner.RefreshResults(controls, state)
		controls.statusBar.label = string.format("^7找到 %d 个 seed，用时 %.2fs", #state.results, (GetTime() - started) / 1000)
end

local function buildItemText(jewelType, conqueror, seed, socketLabel)
	local variant = conqueror.id == 1 and 1 or (conqueror.id - 1)
	local label = "[" .. seed .. "; 0; " .. (socketLabel or "?") .. "]"
	if jewelType.id == 1 then
		return "Glorious Vanity " .. label .. [[

Timeless Jewel
League: Legion
Limited to: 1 Historic
Variant: Doryani (Corrupted Soul)
Variant: Xibaqua (Divine Flesh)
Variant: Ahuana (Immortal Ambition)
Selected Variant: ]] .. variant .. [[

Radius: Large
Implicits: 0
{variant:1}Bathed in the blood of ]] .. seed .. [[ sacrificed in the name of Doryani
{variant:2}Bathed in the blood of ]] .. seed .. [[ sacrificed in the name of Xibaqua
{variant:3}Bathed in the blood of ]] .. seed .. [[ sacrificed in the name of Ahuana
Passives in radius are Conquered by the Vaal
Historic
]]
	elseif jewelType.id == 2 then
		return "Lethal Pride " .. label .. [[

Timeless Jewel
League: Legion
Limited to: 1 Historic
Variant: Kaom (Strength of Blood)
Variant: Rakiata (Tempered by War)
Variant: Akoya (Chainbreaker)
Selected Variant: ]] .. variant .. [[

Radius: Large
Implicits: 0
{variant:1}Commanded leadership over ]] .. seed .. [[ warriors under Kaom
{variant:2}Commanded leadership over ]] .. seed .. [[ warriors under Rakiata
{variant:3}Commanded leadership over ]] .. seed .. [[ warriors under Akoya
Passives in radius are Conquered by the Karui
Historic
]]
	elseif jewelType.id == 3 then
		return "Brutal Restraint " .. label .. [[

Timeless Jewel
League: Legion
Limited to: 1 Historic
Variant: Asenath (Dance with Death)
Variant: Nasima (Second Sight)
Variant: Balbala (The Traitor)
Selected Variant: ]] .. variant .. [[

Radius: Large
Implicits: 0
{variant:1}Denoted service of ]] .. seed .. [[ dekhara in the akhara of Asenath
{variant:2}Denoted service of ]] .. seed .. [[ dekhara in the akhara of Nasima
{variant:3}Denoted service of ]] .. seed .. [[ dekhara in the akhara of Balbala
Passives in radius are Conquered by the Maraketh
Historic
]]
	elseif jewelType.id == 4 then
		local altVariant = 2
		return "Militant Faith " .. label .. [[

Timeless Jewel
League: Legion
Limited to: 1 Historic
Has Alt Variant: true
Has Alt Variant Two: true
Variant: Avarius (Power of Purpose)
Variant: Dominus (Inner Conviction)
Variant: Maxarius (Transcendence)
Variant: Totem Damage
Variant: Brand Damage
Variant: Channelling Damage
Variant: Area Damage
Variant: Elemental Damage
Variant: Elemental Resistances
Variant: Effect of non-Damaging Ailments
Variant: Elemental Ailment Duration
Variant: Duration of Curses
Variant: Minion Attack and Cast Speed
Variant: Minions Accuracy Rating
Variant: Mana Regen
Variant: Skill Cost
Variant: Non-Curse Aura Effect
Variant: Defences from Shield
Selected Variant: ]] .. variant .. [[
Selected Alt Variant: ]] .. altVariant .. [[
Selected Alt Variant Two: 3
Radius: Large
Implicits: 0
{variant:1}Carved to glorify ]] .. seed .. [[ new faithful converted by High Templar Avarius
{variant:2}Carved to glorify ]] .. seed .. [[ new faithful converted by High Templar Dominus
{variant:3}Carved to glorify ]] .. seed .. [[ new faithful converted by High Templar Maxarius
Passives in radius are Conquered by the Templars
Historic
]]
	elseif jewelType.id == 5 then
		return "Elegant Hubris " .. label .. [[

Timeless Jewel
League: Legion
Limited to: 1 Historic
Variant: Cadiro (Supreme Decadence)
Variant: Victario (Supreme Grandstanding)
Variant: Caspiro (Supreme Ostentation)
Selected Variant: ]] .. variant .. [[

Radius: Large
Implicits: 0
{variant:1}Commissioned ]] .. seed .. [[ coins to commemorate Cadiro
{variant:2}Commissioned ]] .. seed .. [[ coins to commemorate Victario
{variant:3}Commissioned ]] .. seed .. [[ coins to commemorate Caspiro
Passives in radius are Conquered by the Eternal Empire
Historic
]]
	elseif jewelType.id == 6 then
		return "Heroic Tragedy " .. label .. [[

Timeless Jewel
League: Legion
Limited to: 1 Historic
Variant: Vorana (Black Scythe Training)
Variant: Uhtred (Celestial Mathematics)
Variant: Medved (The Unbreaking Circle)
Selected Variant: ]] .. variant .. [[

Radius: Large
Implicits: 0
{variant:1}Remembrancing ]] .. seed .. [[ songworthy deeds by the line of Vorana
{variant:2}Remembrancing ]] .. seed .. [[ songworthy deeds by the line of Uhtred
{variant:3}Remembrancing ]] .. seed .. [[ songworthy deeds by the line of Medved
Passives in radius are Conquered by the Kalguur
Historic
]]
	elseif jewelType.id == 7 then
		return "Festering Vengeance " .. label .. [[

Murderous Eye Jewel
League: Allflame
Limited to: 1 Historic
Implicits: 0
Subjugating ]] .. seed .. [[ souls in the thrall of Tecrod
Passives affected are Conquered by the Abyssal
Historic
]]
	elseif jewelType.id == 8 then
		return "Extinguishing Grasp " .. label .. [[

Searching Eye Jewel
League: Allflame
Limited to: 1 Historic
Implicits: 0
Subjugating ]] .. seed .. [[ souls in the thrall of Ulaman
Passives affected are Conquered by the Abyssal
Historic
]]
	elseif jewelType.id == 9 then
		return "Baleful Dominion " .. label .. [[

Hypnotic Eye Jewel
League: Allflame
Limited to: 1 Historic
Implicits: 0
Subjugating ]] .. seed .. [[ souls in the thrall of Kurgal
Passives affected are Conquered by the Abyssal
Historic
]]
	elseif jewelType.id == 10 then
		return "Destructive Aspiration " .. label .. [[

Ghastly Eye Jewel
League: Allflame
Limited to: 1 Historic
Implicits: 0
Subjugating ]] .. seed .. [[ souls in the thrall of Amanamu
Passives affected are Conquered by the Abyssal
Historic
]]
	elseif jewelType.id == 11 then
		return "Reclaimed Malevolence " .. label .. [[

Assembled Eye Jewel
League: Allflame
Limited to: 1 Historic
Implicits: 0
Binding ]] .. seed .. [[ souls to phylacteries to sustain Zorath
Passives affected are Conquered by the Abyssal
Historic
]]
	end
end

function Planner.PreviewSeed(build, jewelType, conqueror, seed, socketId)
	if not seed or not socketId then
		return
	end
	local itemText = buildItemText(jewelType, conqueror, seed, tostring(socketId))
	if not itemText then
		return
	end
	local itemsTab = build.itemsTab
	local state = build.timelessPlannerState
	if state.previewItemId and itemsTab.items[state.previewItemId] then
		itemsTab:DeleteItem(itemsTab.items[state.previewItemId], true)
	end
	local item = new("Item", itemText)
	itemsTab:AddItem(item, true)
	state.previewItemId = item.id
	state.previewSeed = seed
	local socket = itemsTab.sockets[socketId]
	if socket then
		socket:SetSelItemId(item.id)
	end
	itemsTab:PopulateSlots()
	build.buildFlag = true
	build.viewMode = "TREE"
	main:ClosePopup()
end

function Planner.AddSeed(build, jewelType, conqueror, seed, socketId, controls, quiet)
	if not seed then
		return
	end
	local itemText = buildItemText(jewelType, conqueror, seed, tostring(socketId or "?"))
	if not itemText then
		return
	end
	local item = new("Item", itemText)
	if item then
		build.itemsTab:AddItem(item, true)
		build.itemsTab:PopulateSlots()
		if controls and controls.statusBar then
			controls.statusBar.label = "^2已加入 seed " .. seed .. " 到 BD"
		end
		build.timelessPlannerState.added = build.timelessPlannerState.added or { }
		build.timelessPlannerState.added[seed] = true
	end
end

function Planner.JoinPage(build, jewelType, conqueror, state, controls)
	local results = state.results or { }
	local startIndex = (state.page - 1) * 10 + 1
	local endIndex = m_min(startIndex + 9, #results)
	local added = 0
	state.added = state.added or { }
	local addedSet = state.added
	for i = startIndex, endIndex do
		local result = results[i]
		if not addedSet[result.seed] then
			Planner.AddSeed(build, jewelType, conqueror, result.seed, result.socketId, nil, true)
			addedSet[result.seed] = true
			added = added + 1
		end
	end
	if controls and controls.statusBar then
		controls.statusBar.label = string.format("^2已批量加入 %d 个 seed 到 BD", added)
	end
end

function Planner.BuyPage(state, controls, jewelType, conqueror)
	local results = state.results or { }
	local seeds = { }
	if state.checkedSeeds and next(state.checkedSeeds) then
		for _, result in ipairs(results) do
			if state.checkedSeeds[result.seed] then
				t_insert(seeds, result.seed)
				if #seeds >= 10 then
					break
				end
			end
		end
	else
		local startIndex = (state.page - 1) * 10 + 1
		local endIndex = m_min(startIndex + 9, #results)
		for i = startIndex, endIndex do
			t_insert(seeds, results[i].seed)
		end
	end
	if #seeds == 0 then
		return
	end
	local realm = controls.realmSelect and controls.realmSelect:GetSelValue() or "PC"
	local league = controls.leagueSelect and controls.leagueSelect:GetSelValue() or "Standard"
	local tradeTypeKeys = { "securable", "available", "onlineleague", "online", "any" }
	local tradeType = controls.tradeTypeSelect and tradeTypeKeys[controls.tradeTypeSelect.selIndex] or "any"
	local url = TimelessJewelTrade.BuildUrl({
		jewelType = jewelType,
		conqueror = conqueror,
		seeds = seeds,
		realm = realm:lower(),
		league = league,
		tradeType = tradeType,
	})
	if url then
		OpenURL(url)
		Copy(url)
		if controls.statusBar then
			controls.statusBar.label = "^2已生成购买链接并复制到剪贴板"
		end
	end
end

local function getStateNodes(build, socketId)
	local treeData = build.spec.tree
	local core, keystones = { }, { }
	local socketNode = treeData.nodes[socketId]
	if not socketNode or not socketNode.nodesInRadius then
		return core, keystones
	end
	local radius = socketNode.nodesInRadius[3] or { }
	local granted = build.calcsTab.mainEnv.grantedPassives or { }
	for nodeId in pairs(radius) do
		local node = treeData.nodes[nodeId]
		local lit = build.spec.allocNodes[nodeId] ~= nil or granted[nodeId] ~= nil
		if node and lit and not node.ascendancyName then
			if node.isKeystone then
				t_insert(keystones, node)
			elseif node.isNotable then
				t_insert(core, node)
			end
		end
	end
	table.sort(core, function(a, b) return (a.dn or "") < (b.dn or "") end)
	table.sort(keystones, function(a, b) return (a.dn or "") < (b.dn or "") end)
	return core, keystones
end

local function getPanelSocket(build, state)
	local sockets = { }
	for nodeId, node in pairs(build.spec.nodes) do
		if node.isJewelSocket and node.name ~= "Charm Socket" and build.spec.allocNodes[nodeId] then
			t_insert(sockets, { id = nodeId, label = (node.dn or node.name or "Jewel Socket") .. " [" .. nodeId .. "]" })
		end
	end
	table.sort(sockets, function(a, b) return a.label < b.label end)
	local socketId = state.socketId
	if not socketId or not build.spec.allocNodes[socketId] then
		socketId = sockets[1] and sockets[1].id or nil
	end
	return sockets, socketId
end

function Planner.GetState(build)
	local state = build.timelessPlannerState
	if not state then
		return { ok = false, error = "Planner state missing" }
	end
	local sockets, socketId = getPanelSocket(build, state)
	local jewelType = jewelTypes[state.jewelTypeId] or jewelTypes[1]
	local conqueror = getConqueror(jewelType.id, state.conquerorId)
	local core, keystones = { }, { }
	if socketId then
		core, keystones = getStateNodes(build, socketId)
	end

	local coreResult = { }
	for _, node in ipairs(core) do
		local selected = state.coreOutcomes[node.id] or { }
		local options = { }
		for _, outcome in ipairs(TimelessPlannerSearch.GetCoreOutcomes(build, jewelType, socketId, node.id)) do
			if outcome.id and not outcome.ks then
				local label = outcome.dn or outcome.id
				if outcome.kind == "addition" then
					label = "附加：" .. label
				end
				t_insert(options, {
					id = outcome.key or outcome.id,
					key = outcome.key or outcome.id,
					kind = outcome.kind or "replacement",
					label = label,
					primary = statLabel(outcome.sortedStats and outcome.sortedStats[1] or ""),
					selected = selected[outcome.key or outcome.id] == true or selected[outcome.id] == true,
				})
			end
		end
		local selectedList = { }
		for id in pairs(selected) do
			t_insert(selectedList, id)
		end
		t_insert(coreResult, {
			id = node.id,
			name = node.dn,
			selected = selectedList,
			options = options,
		})
	end

	local keystoneResult = { }
	for _, node in ipairs(keystones) do
		t_insert(keystoneResult, {
			id = node.id,
			name = node.dn,
			result = conqueror.label,
		})
	end

	local firstSeeds = { }
	local firstResults = { }
	for i = 1, m_min(10, #(state.results or { })) do
		local result = state.results[i]
		t_insert(firstSeeds, result.seed)
		t_insert(firstResults, {
			seed = result.seed,
			socketId = result.socketId,
			coreHits = result.coreHits or 0,
			coreTotal = result.coreTotal or 0,
		})
	end

	return {
		ok = true,
		socketId = socketId,
		sockets = sockets,
		jewelType = { id = jewelType.id, label = jewelType.label, name = jewelType.name },
		conqueror = { id = conqueror.id, label = conqueror.label },
		types = jewelTypes,
		conquerors = conquerorTypes[jewelType.id],
		core = coreResult,
		keystone = keystoneResult,
		resultCount = #(state.results or { }),
		firstSeeds = firstSeeds,
		firstResults = firstResults,
		previewSeed = state.previewSeed,
		panelOpen = main.popups[1] and main.popups[1].title == "永恒珠宝精准规划" or false,
	}
end

function Planner.Preview(build, seed)
	local state = build.timelessPlannerState
	if not state then
		return nil, "Planner state missing"
	end
	local jewelType = jewelTypes[state.jewelTypeId] or jewelTypes[1]
	local conqueror = getConqueror(jewelType.id, state.conquerorId)
	Planner.PreviewSeed(build, jewelType, conqueror, seed, state.socketId)
	return { seed = seed, socketId = state.socketId }
end

function Planner.Show(build)
	if not build.treeTab then
		return false
	end
	if main.popups[1] and main.popups[1].title == "永恒珠宝精准规划" then
		main:ClosePopup()
	end
	Planner.Open(build.treeTab)
	return true
end

function Planner.Configure(build, config)
	local state = build.timelessPlannerState
	if not state then
		return nil, "Planner state missing"
	end
	if config.jewelTypeId then
		local newTypeId = tonumber(config.jewelTypeId) or state.jewelTypeId
		if newTypeId ~= state.jewelTypeId then
			-- Core outcomes are type-specific; never keep stale results from
			-- another jewel type.
			state.coreOutcomes = { }
			state.results = { }
			state.checkedSeeds = { }
			state.page = 1
		end
		state.jewelTypeId = newTypeId
		local list = conquerorTypes[state.jewelTypeId] or { { label = "Any", id = 1 } }
		state.conquerorId = list[1].id
	end
	if config.conquerorId then
		state.conquerorId = tonumber(config.conquerorId) or state.conquerorId
	end
	if config.socketId then
		state.socketId = tonumber(config.socketId)
	end
	if config.coreOutcomes then
		for nodeId, outcomes in pairs(config.coreOutcomes) do
			local set = { }
			for _, id in ipairs(outcomes) do
				set[tostring(id)] = true
			end
			state.coreOutcomes[tonumber(nodeId)] = set
		end
	end
	Planner.Show(build)
	return Planner.GetState(build)
end

function Planner.Search(build)
	local state = build.timelessPlannerState
	if not state then
		return nil, "Planner state missing"
	end
	local sockets, socketId = getPanelSocket(build, state)
	if not socketId then
		return nil, "No lit jewel socket"
	end
	state.socketId = socketId
	local jewelType = jewelTypes[state.jewelTypeId] or jewelTypes[1]
	local core, keystones = getStateNodes(build, socketId)
	local coreNodes = { }
	for _, node in ipairs(core) do
		local outcomes = state.coreOutcomes[node.id]
		if outcomes and next(outcomes) then
			t_insert(coreNodes, { nodeId = node.id, outcomes = outcomes })
		end
	end
	state.results = TimelessPlannerSearch.Run(build, {
		jewelType = jewelType,
		socketId = socketId,
		coreNodes = coreNodes,
	})
	state.checkedSeeds = { }
	state.page = 1
	Planner.Show(build)
	return Planner.GetState(build)
end

function Planner.Next(build, direction)
	local state = build.timelessPlannerState
	if not state or not state.results or #state.results == 0 then
		return nil, "No search results"
	end
	local index = nil
	for i, result in ipairs(state.results) do
		if result.seed == state.previewSeed then
			index = i
			break
		end
	end
	if index == nil then
		index = (tonumber(direction) or 1) > 0 and 1 or #state.results
	else
		index = index + (tonumber(direction) or 1)
	end
	if index < 1 then
		index = #state.results
	elseif index > #state.results then
		index = 1
	end
	local result = state.results[index]
	local jewelType = jewelTypes[state.jewelTypeId] or jewelTypes[1]
	local conqueror = getConqueror(jewelType.id, state.conquerorId)
	Planner.PreviewSeed(build, jewelType, conqueror, result.seed, result.socketId)
	return { seed = result.seed, index = index, count = #state.results }
end

setmetatable(Planner, {
	__call = function(_, treeTab)
		return Planner.Open(treeTab)
	end,
})

return Planner

