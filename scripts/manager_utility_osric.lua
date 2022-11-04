-- check all modules loaded and local records
-- for npc with name of sNpcName
function findNpcRecord(sNpcName)
	local nodeNpcResult = nil

	local vMappings = LibraryData.getMappings("npc")

	for _, sMap in ipairs(vMappings) do
		for _, nodeNpc in pairs(DB.getChildrenGlobal(sMap)) do
			local sName = DB.getValue(nodeNpc, "name")
			sName = StringManager.trim(sName)

			if (sName:lower() == sNpcName:lower()) then
				if string.match(nodeNpc.getPath(), "OSRIC") then
					--nodeNpc.getChild("token").setValue(sToken)
					nodeNpcResult = nodeNpc
					break
				end
			end
		end
	end

	return nodeNpcResult
end
--

-- look for classes in the name and try to parse out the saves as and fights as classes, at least
-- two separate functions so that we can choose the best value from each matching class
-- fights as
function findNpcFightsAsValue(nodeNpc)
	local sNpcName = nodeNpc.getChild("name").getValue()
	
	local sFightsAsClass

	-- we should iterate through the list of class when searching in a way that checks the best matrix first for multi-classed npcs
	if string.match(sNpcName, "Fighter") then
		sFightsAsClass = "Fighter"
	elseif string.match(sNpcName, "Paladin") then
		sFightsAsClass = "Paladin"
	elseif string.match(sNpcName, "Ranger") then
		sFightsAsClass = "Ranger"
	elseif string.match(sNpcName, "Cleric") then
		sFightsAsClass = "Cleric"
	elseif string.match(sNpcName, "Druid") then
		sFightsAsClass = "Druid"
	elseif string.match(sNpcName, "Assassin") then
		sFightsAsClass = "Assassin"
	elseif string.match(sNpcName, "Thief") then
		sFightsAsClass = "Thief"
	elseif string.match(sNpcName, "Mage") then
		sFightsAsClass = "Magic User"
	elseif string.match(sNpcName, "Illusionist") then
		sFightsAsClass = "Illusionist"
	end

	return sFightsAsClass
end

-- saves as
function findNpcSavesAsValue(nodeNpc)
	local sNpcName = nodeNpc.getChild("name").getValue()
	
	local sSavesAsClass

	-- we should iterate through the list of class when searching in a way that checks the best matrix first for multi-classed npcs
	if string.match(sNpcName, "Cleric") then
		sSavesAsClass = "Cleric"
	elseif string.match(sNpcName, "Druid") then
		sSavesAsClass = "Druid"
	elseif string.match(sNpcName, "Mage") then
		sSavesAsClass = "Magic User"
	elseif string.match(sNpcName, "Illusionist") then
		sSavesAsClass = "Illusionist"
	elseif string.match(sNpcName, "Thief") then
		sSavesAsClass = "Thief"
	elseif string.match(sNpcName, "Assassin") then
		sSavesAsClass = "Assassin"
	elseif string.match(sNpcName, "Fighter") then
		sSavesAsClass = "Fighter"
	elseif string.match(sNpcName, "Paladin") then
		sSavesAsClass = "Paladin"
	elseif string.match(sNpcName, "Ranger") then
		sSavesAsClass = "Ranger"
	end

	return sSavesAsClass
end
