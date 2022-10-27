PC_LASTINIT = 0
NPC_LASTINIT = 0

OOB_MSGTYPE_APPLYINIT = "applyinit"

function onInit()
	ActionInit.getRoll = getRollOsric
	ActionInit.handleApplyInit = handleApplyInitOsric

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYINIT, handleApplyInitOsric)
end

-- initiative roll, from item entry in ct or init button on character
function getRollOsric(rActor, bSecretRoll, rItem)
	--Debug.console("getRollOsric", rActor, bSecretRoll, rItem)

	rRoll = getRollNoMods(rActor, bSecretRoll, rItem)

	return rRoll
end

-- standard roll when modifiers are turned off
function getRollNoMods(rActor, bSecretRoll, rItem)
	--Debug.console("getRollNoMods", rActor, bSecretRoll, rItem)
	local rRoll = {}

	rRoll.sType = "init"
	rRoll.aDice = {"d" .. DataCommonADND.nDefaultInitiativeDice}
	--Debug.console("getRollNoMods", rRoll.aDice)
	rRoll.nMod = 0
	rRoll.sDesc = "[INIT][Mods OFF]"
	rRoll.bSecret = bSecretRoll

	return rRoll
end

-- apply init based on chat window result
function handleApplyInitOsric(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode)
	local nodeEntry = ActorManager.getCTNode(rSource)

	local nInitRoll = tonumber(msgOOB.nTotal) or 0

	local bOptInitTies = (OptionsManager.getOption("initiativeTiesAllow") == "on")
	local bOptInitGroupingSwap = (OptionsManager.getOption("initiativeGroupingSwap") == "on")
	local sOptInitGrouping = OptionsManager.getOption("initiativeGrouping")
	local sOptInitOrdering = OptionsManager.getOption("initiativeOrdering")

	--Debug.console("handleApplyInitAdndOsric", "msgOOB", msgOOB, "sOptInitGrouping", sOptInitGrouping)

	-- set inits to 0, in case a grouping option has been changed and inits not fully reset after some inits have been rolled
	pcInit = 0
	npcInit = 0

	-- pc rolled
	if ActorManager.isPC(rSource) then
		-- npc rolled
		-- init swap
		-- apply to npcs
		npcInit = nInitRoll
		npcLastInit = npcInit
		pcInit = 0
	else
		-- init swap
		-- apply to pcs
		pcInit = nInitRoll
		pcLastInit = pcInit
		npcInit = 0
	end

	if pcInit ~= 0 then
		applyInitResultToAllPCs(pcInit)

		-- deliver init message for clarity
		-- todo: make better
		ChatManager.Message("NPC roll of " .. pcInit .. " applied to all PCs (OSRIC initiative swap)", false)
	elseif npcInit ~= 0 then
		applyInitResultToAllNPCs(npcInit)

		-- deliver init message for clarity
		-- todo: make better
		ChatManager.Message("PC roll of " .. npcInit .. " applied to all NPCs (OSRIC initiative swap)", false)
	end
end

function applyInitResultToAllPCs(nInitResult)
	--Debug.console("applyInitResultToAllPCs", nInitResult)
	-- group init - apply init result to all PCs
	for _, nodeEntry in pairs(CombatManager.getCombatantNodes()) do
		if DB.getValue(nodeEntry, "friendfoe") == "friend" then
			-- just set both of these values regardless of initiative die used, so we don't have to mod other places where initresult is displayed
			DB.setValue(nodeEntry, "initresult", "number", nInitResult)
			DB.setValue(nodeEntry, "initresult_d6", "number", nInitResult)
			-- set init rolled
			DB.setValue(nodeEntry, "initrolled", "number", 1)
		end
	end

	-- deliver init message for clarity
	-- todo: make better
	-- ChatManager.Message("NPC roll of " .. nInitResult .. " applied to all PCs (OSRIC initiative swap)", false)
end

function applyInitResultToAllNPCs(nInitResult)
	--Debug.console("applyInitResultToAllNPCs", nInitResult)
	-- group init - apply init result to remaining NPCs
	for _, nodeEntry in pairs(CombatManager.getCombatantNodes()) do
		if DB.getValue(nodeEntry, "friendfoe") ~= "friend" then
			-- reset nInitResult
			nInitResult = nInitResult
			-- get custom init value
			-- default to 0 each iteration
			local nCustomInit = 0
			-- get actual value
			nCustomInit = DB.getValue(nodeEntry, "init", 0)
			-- new var for storing any new result
			local nInitResultNew = 0

			-- Override, TODO should figure out why OSRIC isn't initializing DataCommonADND.nDefaultInitiativeDice and not sure about why 2E is initializing as string
			local initiativeDie = 6

			-- modify init for custom inits higher than the max init die (zombies, etc)
			if nCustomInit > initiativeDie then
				-- use the modifier that's already been calculated
				nInitResultNew = nCustomInit
			else
				nInitResultNew = nInitResult
			end

			--Debug.console("applyInitResultToAllNPCs", "nInitResult", nInitResult, "nCustomInit", nCustomInit, "nInitResultNew", nInitResultNew)
			Debug.console(
				"applyInitResultToAllNPCs",
				"nInitResult",
				nInitResult,
				"nCustomInit",
				nCustomInit,
				"nInitResultNew",
				nInitResultNew
			)
			-- just set both of these values regardless of initiative die used, so we don't have to mod other places where initresult is displayed
			DB.setValue(nodeEntry, "initresult", "number", nInitResultNew)
			DB.setValue(nodeEntry, "initresult_d6", "number", nInitResultNew)
			-- set init rolled
			DB.setValue(nodeEntry, "initrolled", "number", 1)
		end
	end
end

function delayActor(nodeChar)
	local nodeCT = CombatManager.getCTFromNode(nodeChar)
	local nodeCTActive = CombatManager.getActiveCT()
	if nodeCT == nodeCTActive then
		local nLastInit = 7
		CombatManagerADND.showCTMessageADND(
			nodeEntry,
			DB.getValue(nodeCT, "name", "") .. " " .. Interface.getString("char_initdelay_message")
		)
		if Session.IsHost then
			CombatManager.nextActor()
		else
			CombatManager.notifyEndTurn()
		end
		CombatManagerADND.notifyInitiativeChange(nodeCT, nLastInit)
	else
		local sName = DB.getValue(nodeChar, "name", "")
		sChatText = sName .. " tried to delay when it wasn't their turn."

		ChatManager.Message(sChatText, false)
	end
end
