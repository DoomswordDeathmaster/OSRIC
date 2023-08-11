function onInit()
	-- if super and super.onInit then
    --     Debug.console("super and oninit found")
    --     super.onInit()
    -- end
	ActorCommonManager.setRecordTypeSpaceReachCallback("npc", CombatRecordManagerOsric.getNPCSpaceReach);

	if Session.IsHost then
		--added 2023-08-06
		CombatRecordManager.setRecordTypeCallback("npc", CombatRecordManagerOsric.onNPCAdd);
		CombatRecordManager.setRecordTypePostAddCallback("charsheet", CombatRecordManagerOsric.onPCPostAdd);
		---------- end add

		CombatRecordManager.setRecordTypeCallback("battle", CombatRecordManagerOsric.onBattleAdd)
		CombatRecordManager.setRecordTypePostAddCallback("npc", CombatRecordManagerOsric.onNPCPostAdd);
	end
end

---------------------- added to troubleshoot npc sizes 20230806
-- JPG - 2022-09-25 - Migrated CombatManager2 to CombatRecordManagerADND
function getNPCSpaceReach(rActor)
	Debug.console("getNPCSpaceReach")
	local nSpace = GameSystem.getDistanceUnitsPerGrid();
	local nReach = nSpace;
	
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return nSpace, nReach;
	end

	local sSize = StringManager.trim(DB.getValue(nodeActor, "size", ""):lower());
	if sSize == "large" then
		nSpace = nSpace * 2;
	elseif sSize == "huge" then
		nSpace = nSpace * 3;
	elseif sSize == "gargantuan" then
		nSpace = nSpace * 4;
	end

	Debug.console("nodeActor", nodeActor, "nSpace", nSpace, "nReach", nReach, "sSize", sSize)
	return nSpace, nReach;
end

-- JPG - 2022-09-25 - Updated function to most recent CoreRPG methodology
function onPCPostAdd(tCustom)
	Debug.console("onPCPostAdd")
	
	-- Parameter validation
	if not tCustom.nodeRecord or not tCustom.nodeCT then
		return;
	end

	-- Update CT effects
	helperAddEffects(tCustom);
end

-- JPG - 2022-09-25 - Updated function to most recent CoreRPG methodology
function onNPCAdd(tCustom)
	Debug.console("onNPCAdd")

	if not tCustom.nodeRecord then
		return false;
	end
	tCustom.nodeCT = CombatManager.createCombatantNode();
	if not tCustom.nodeCT then
		return false;
	end

	helperAddHiddenName(tCustom);

	if DELAYED_COPY then
		helperCopyCTSourceToNode(tCustom.nodeRecord, tCustom.nodeCT, _tInitialCopy);
	else
		DB.copyNode(tCustom.nodeRecord, tCustom.nodeCT);
	end

	DB.setValue(tCustom.nodeCT, "locked", "number", 1);

	-- Remove any combatant specific information
	DB.setValue(tCustom.nodeCT, "active", "number", 0);
	DB.setValue(tCustom.nodeCT, "tokenrefid", "string", "");
	DB.setValue(tCustom.nodeCT, "tokenrefnode", "string", "");
	DB.deleteChildren(tCustom.nodeCT, "effects");

	CombatRecordManager.handleStandardCombatAddFields(tCustom);
	CombatRecordManager.handleStandardCombatAddSpaceReach(tCustom);
	CombatRecordManager.handleStandardCombatAddPlacement(tCustom);
	return true;
end

function helperAddHiddenName(tCustom)
	Debug.console("helperAddHiddenName")
	
	if not tCustom.sName then
		tCustom.sName = DB.getValue(tCustom.nodeRecord, "name", "");
	end
	
	tCustom.sNameHidden = tCustom.sName:match("%(.*%)");
	tCustom.sName = StringManager.trim(tCustom.sName:gsub("%(.*%)", ""));
end
function helperAddHiddenName2(tCustom)
	-- save DM only "hiddten text" if necessary to display in host CT
	if (tCustom.sNameHidden or "") ~= "" then
		DB.setValue(tCustom.nodeCT, "name_hidden", "string", tCustom.sNameHidden);
	end
end
function helperAddSize(tCustom)
	Debug.console("helperAddSize", "tCustom", tCustom)
	-- base modifier for initiative
	-- we set modifiers based on size per DMG for AD&D -celestian
	DB.setValue(tCustom.nodeCT, "init", "number", 0);

	-- Determine size
	local sSize = StringManager.trim(DB.getValue(tCustom.nodeCT, "size", "")):lower();
	local sSizeNoLower = StringManager.trim(DB.getValue(tCustom.nodeCT, "size", ""));

	Debug.console("helperAddSize", "sSize", sSize, "sSizeNoLower", sSizeNoLower)

	if sSize == "tiny" or string.find(sSizeNoLower, "T") then
		DB.setValue(tCustom.nodeCT, "init", "number", 0);
	elseif sSize == "small" or string.find(sSizeNoLower, "S") then
		DB.setValue(tCustom.nodeCT, "init", "number", 3);
	elseif sSize == "medium" or string.find(sSizeNoLower, "M") then
		DB.setValue(tCustom.nodeCT, "init", "number", 3);
	elseif sSize == "large" or string.find(sSizeNoLower, "L") then
		DB.setValue(tCustom.nodeCT, "init", "number", 6);
	elseif string.find(sSizeNoLower, "GIANT") then
		DB.setValue(tCustom.nodeCT, "space", "number", 10);
		DB.setValue(tCustom.nodeCT, "init", "number", 6);
	elseif sSize == "huge" or string.find(sSizeNoLower, "H") then
		Debug.console("(Hh)uge found")
		DB.setValue(tCustom.nodeCT, "space", "number", 10);
		DB.setValue(tCustom.nodeCT, "init", "number", 9);
	elseif sSize == "gargantuan" or string.find(sSizeNoLower, "G") then
		DB.setValue(tCustom.nodeCT, "space", "number", 15);
		DB.setValue(tCustom.nodeCT, "init", "number", 12);
	end
	
	-- allow custom TOKEN_SIZE: XX 
	if sSizeNoLower:find("TOKEN_SIZE:%s?%d+") then
		local sTokenSize = sSizeNoLower:match("TOKEN_SIZE:%s?(%d+)");
		local nTokenSize = tonumber(sTokenSize) or 5;
		DB.setValue(tCustom.nodeCT, "space", "number", nTokenSize);
		Debug.console(tCustom.nodeCT, "space", "number", nTokenSize)
	end
	-- allow custom TOKEN_REACH: XX 
	if sSizeNoLower:find("TOKEN_REACH:%s?%d+") then
		local sTokenReach = sSizeNoLower:match("TOKEN_REACH:%s?(%d+)");
		local nTokenReach = tonumber(sTokenReach) or 5;
		DB.setValue(tCustom.nodeCT, "reach", "number", nTokenReach);
		Debug.console(tCustom.nodeCT, "reach", "number", nTokenReach)
	end
end
-----------------------------------end add

--
--	Battle Record
--
function onBattleAdd(tCustom)
	CombatRecordManagerOsric.addBattle(tCustom)
	return true
end

-- tracks CoreRPG - modified 20230708
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

	-- Clean up any placement tokens from an open battle window
	CombatRecordManager.clearBattlePlacementTokens(tCustom);

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
	CombatRecordManagerOsric.helperAddSize(tCustom);

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