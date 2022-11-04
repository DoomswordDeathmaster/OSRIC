function onInit()
	if Session.IsHost then
		CombatRecordManager.setRecordTypeCallback("battle", CombatRecordManagerOsric.onBattleAdd)
		CombatRecordManager.setRecordTypePostAddCallback("npc", CombatRecordManagerOsric.onNPCPostAdd);
	end
end

--
--	Battle Record
--
function onBattleAdd(tCustom)
	CombatRecordManagerOsric.addBattle(tCustom)
	return true
end

function addBattle(tCustom)
	-- Setup
	if not tCustom.nodeRecord then
		return
	end
	tCustom.sListPath = LibraryData.getCustomData("battle", "npclist") or "npclist"

	-- Handle module load, since battle entries are "linked", not copied.
	tCustom.fLoadCallback = CombatRecordManager.addBattle
	if CombatRecordManager.handleBattleModuleLoad(tCustom) then
		return
	end

	-- Handle legacy override
	local fOverride = CombatManager.getCustomAddBattle()
	if fOverride then
		fOverride(tCustom.nodeRecord)
		return
	end

	-- Standard handling
	CombatRecordManagerOsric.addBattleHelper(tCustom)

	-- Open combat tracker
	Interface.openWindow("combattracker_host", "combattracker")
end

function addBattleHelper(tCustom)
	-- Cycle through the NPC list, and add them to the tracker
	for _, nodeBattleEntry in pairs(DB.getChildren(tCustom.nodeRecord, tCustom.sListPath)) do
		-- Get entry data
		local tBattleEntry = CombatRecordManagerOsric.getBattleEntryData(nodeBattleEntry)
		--Debug.console("tBattleEntry", tBattleEntry)

		if tBattleEntry and tBattleEntry.nodeRecord then
			for i = 1, tBattleEntry.nCount do
				local t = UtilityManager.copyDeep(tBattleEntry)
				t.tPlacement = t.tAllPlacements[i]
				t.tBattleEntry = tBattleEntry

				local sEntryRecordType = LibraryData.getRecordTypeFromRecordPath(t.sRecord)
				if CombatRecordManager.hasRecordTypeCallback(sEntryRecordType) then
					CombatRecordManager.onRecordTypeEvent(sEntryRecordType, t)
				end
				if not t.nodeCT then
					local s =
						string.format(
						"%s (%s) (%s)",
						Interface.getString("ct_error_addnpcfail"),
						tBattleEntry.sName,
						tBattleEntry.sRecord
					)
					ChatManager.SystemMessage(s)
				end
			end
		else
			local s
			if tBattleEntry then
				s =
					string.format(
					"%s (%s) (%s)",
					Interface.getString("ct_error_addnpcfail2"),
					tBattleEntry.sName,
					tBattleEntry.sRecord
				)
			else
				s = Interface.getString("ct_error_addnpcfail2")
			end
			ChatManager.SystemMessage(s)
		end
	end
end

function getBattleEntryData(nodeBattleEntry)
	if not nodeBattleEntry then
		return nil
	end

	-- Get entry data
	--Debug.console("nodeBattleEntry", nodeBattleEntry)

	local t = {}
	t.nodeBattleEntry = nodeBattleEntry

	t.sClass, t.sRecord = DB.getValue(nodeBattleEntry, "link", "", "")
	t.sName = DB.getValue(nodeBattleEntry, "name", "")
	
	if t.sRecord ~= "" then
		-- check for an OSRIC entry that matches in name
		local originalNodeNameProperty = t.sName
		--Debug.console("originalNodeNameProperty", originalNodeNameProperty)

		local nodeOsricNpcResult = UtilityManagerOsric.findNpcRecord(originalNodeNameProperty)

		-- if there's an existing OSRIC asset, use it and add the converted flag to the end of the name
		if nodeOsricNpcResult ~= nil then
			t.nodeRecord = nodeOsricNpcResult
			t.sName = DB.getValue(nodeBattleEntry, "name", "") .. " (c)"
		else
			t.nodeRecord = DB.findNode(t.sRecord)
		end
	end

	t.nCount = DB.getValue(nodeBattleEntry, "count", 0)
	t.sFaction = DB.getValue(nodeBattleEntry, "faction", "")
	t.sToken = DB.getValue(nodeBattleEntry, "token", "")
	t.nIdentified = DB.getValue(nodeBattleEntry, "isidentified", 1)

	t.tAllPlacements = {}
	for _, nodePlacement in pairs(DB.getChildren(nodeBattleEntry, "maplink")) do
		local tPlacement = {}
		local _, sRecord = DB.getValue(nodePlacement, "imageref", "", "")
		tPlacement.imagelink = sRecord
		tPlacement.imagex = DB.getValue(nodePlacement, "imagex", 0)
		tPlacement.imagey = DB.getValue(nodePlacement, "imagey", 0)
		table.insert(t.tAllPlacements, tPlacement)
	end

	--Debug.console(t)
	return t
end

function onNPCPostAdd(tCustom)
	-- Parameter validation
	if not tCustom.nodeRecord or not tCustom.nodeCT then
		return;
	end

	--------------------------------------
	-- call all the normal 2E stuff and deal with fights_as/saves_as
	--------------------------------------

	-- Save hidden name data
	CombatRecordManagerADND.helperAddHiddenName2(tCustom);

	-- Save Fights As and Saves As data
	helperAddFightsAsSavesAs(tCustom);

	-- add the 2e stuff, since we overrode the callback
	--CombatRecordManagerADND.onNPCPostAdd(tCustom)
	-- Handle game system specific size considerations
	CombatRecordManagerADND.helperAddSize(tCustom);

	-- Calculate and set HP
	CombatRecordManagerADND.helperAddHP(tCustom);

	-- Update CT effects
	CombatRecordManagerADND.helperAddEffects(tCustom);

	-- Set mode/display default to standard/actions
	DB.setValue(tCustom.nodeCT, "powermode", "string", "standard");
	DB.setValue(tCustom.nodeCT, "powerdisplaymode", "string", "action");

	-- Sanitize special attack/defense
	CombatRecordManagerADND.helperAddSpecialAD(tCustom);

	-- Roll initiative and sort
	CombatRecordManagerADND.helperAddInit(tCustom);

	-- Special handling for NPCs added from battles
	CombatRecordManagerADND.helperAddBattleNPC(tCustom);
end

function helperAddFightsAsSavesAs(tCustom)
	local sFightsAsClass = UtilityManagerOsric.findNpcFightsAsValue(tCustom.nodeRecord)
	local sSavesAsClass = UtilityManagerOsric.findNpcSavesAsValue(tCustom.nodeRecord)

	-- fights as
	if (sFightsAsClass ~= nil) then
		DB.setValue(tCustom.nodeCT, "fights_as", "string", sFightsAsClass)
		
		--Debug.console("tCustom.nodeCT", tCustom.nodeCT, "sFightsAsClass", sFightsAsClass)
		
		local sNpcName = DB.getValue(tCustom.nodeCT, "name", "")

		--Debug.console("sNpcName", sNpcName)

		if not string.match(sNpcName, "(fs)") then
			-- check if the CT node has a hidden name, so that we can isert the converted flag after it
			if tCustom.sNameHidden ~= nil then
				DB.setValue(tCustom.nodeCT, "name_hidden", "string", tCustom.sNameHidden .. " (fs)")
			else
				DB.setValue(tCustom.nodeCT, "name", "string", sNpcName .. " (fs)")
			end
		end
	end

	-- saves as
	if (sSavesAsClass ~= nil) then
		DB.setValue(tCustom.nodeCT, "saves_as", "string", sSavesAsClass)
		
		Debug.console("tCustom.nodeCT", tCustom.nodeCT, "sSavesAsClass", sSavesAsClass)
	end
end