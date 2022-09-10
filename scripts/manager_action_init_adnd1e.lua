PC_LASTINIT = 0
NPC_LASTINIT = 0

OOB_MSGTYPE_APPLYINIT = "applyinit"

function onInit()
	ActionInit.getRoll = getRollNew
	ActionInit.handleApplyInit = handleApplyInitNew

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYINIT, handleApplyInitNew)
end

-- initiative without modifiers, from item entry in ct or init button on character
function getRollNew(rActor, bSecretRoll, rItem)
	local rRoll = {}
	Debug.console("getRollNew")
	rRoll.sType = "init"
	rRoll.aDice = {"d" .. DataCommonADND.nDefaultInitiativeDice}

	rRoll.nMod = 0

	rRoll.sDesc = "[INIT]"
	rRoll.bSecret = bSecretRoll

	return rRoll
end

function handleApplyInitNew(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode)
	local nTotal = tonumber(msgOOB.nTotal) or 0

	local bOsricInitiativeSwap = (OptionsManager.getOption("useOsricInitiativeSwap") == "on")
	local bOptAutoNpcInitiative = (OptionsManager.getOption("autoNpcInitiative") == "on")

	-- npcs will have already rolled automatically, apply pc init roll to either the pcs or the npcs
	if bOptAutoNpcInitiative then
		if ActorManager.isPC(rSource) then
			-- OSRIC initiative swap
			if bOsricInitiativeSwap then
				CombatManagerADND1e.applyInitResultToAllNPCs(nTotal)
			else
				CombatManagerADND1e.applyInitResultToAllPCs(nTotal)
			end
		end
	else
		if ActorManager.isPC(rSource) then
			CombatManagerADND1e.applyInitResultToAllPCs(nTotal)
			PC_LASTINIT = nTotal
		elseif not ActorManager.isPC(rSource) then
			CombatManagerADND1e.applyInitResultToAllNPCs(nTotal)
			NPC_LASTINIT = nTotal
		end

		-- OSRIC initiative swap
		if bOsricInitiativeSwap then
			CombatManagerADND1e.applyInitResultToAllPCs(NPC_LASTINIT)
			CombatManagerADND1e.applyInitResultToAllNPCs(PC_LASTINIT)
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

		ChatManager.Message(sChatText, false);
	end
end
