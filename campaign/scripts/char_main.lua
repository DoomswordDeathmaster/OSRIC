function onInit()
	local nodeChar = getDatabaseNode()
	DB.addHandler("options.HouseRule_ASCENDING_AC", "onUpdate", updateAscendingValues)

	DB.addHandler(DB.getPath(nodeChar, "abilities.*.percentbase"), "onUpdate", updateAbilityScores)
	DB.addHandler(DB.getPath(nodeChar, "abilities.*.percentbasemod"), "onUpdate", updateAbilityScores)
	DB.addHandler(DB.getPath(nodeChar, "abilities.*.percentadjustment"), "onUpdate", updateAbilityScores)
	DB.addHandler(DB.getPath(nodeChar, "abilities.*.percenttempmod"), "onUpdate", updateAbilityScores)

	DB.addHandler(DB.getPath(nodeChar, "abilities.*.base"), "onUpdate", updateAbilityScores)
	DB.addHandler(DB.getPath(nodeChar, "abilities.*.basemod"), "onUpdate", updateAbilityScores)
	DB.addHandler(DB.getPath(nodeChar, "abilities.*.adjustment"), "onUpdate", updateAbilityScores)
	DB.addHandler(DB.getPath(nodeChar, "abilities.*.tempmod"), "onUpdate", updateAbilityScores)

	DB.addHandler(DB.getPath(nodeChar, "hp.base"), "onUpdate", updateHealthScore)
	DB.addHandler(DB.getPath(nodeChar, "hp.basemod"), "onUpdate", updateHealthScore)

	DB.addHandler(DB.getPath(nodeChar, "hp.adjustment"), "onUpdate", updateHealthScore)
	DB.addHandler(DB.getPath(nodeChar, "hp.tempmod"), "onUpdate", updateHealthScore)

	DB.addHandler(DB.getPath(nodeChar, "surprise.base"), "onUpdate", updateSurpriseScores)
	DB.addHandler(DB.getPath(nodeChar, "surprise.tempmod"), "onUpdate", updateSurpriseScores)
	DB.addHandler(DB.getPath(nodeChar, "surprise.mod"), "onUpdate", updateSurpriseScores)

	DB.addHandler(DB.getPath(nodeChar, "initiative.tempmod"), "onUpdate", updateInitiativeScores)
	DB.addHandler(DB.getPath(nodeChar, "initiative.misc"), "onUpdate", updateInitiativeScores)

	DB.addHandler(DB.getPath(nodeChar, "abilities.strength.score"), "onUpdate", onEncumbranceChanged)

	updateAbilityScores(nodeChar)
	updateAscendingValues()

	updateSurpriseScores()
	updateInitiativeScores()
end

---
--- Update surprise scores
---
function updateSurpriseScores()
	local nodeChar = getDatabaseNode()
	--local surpriseBase = 2

	-- surprise.base if set, 2 if not set
	local nSurpriseBase = DB.getValue(nodeChar,"surprise.base",2);

	-- no mods in 1e/OSRIC
	local nMod = 0

	-- take this if it exists, I guess, but not aware of a place where it does
	local nTmpMod = DB.getValue(nodeChar, "surprise.tempmod", 0)
	local nTotal = nSurpriseBase + nMod + nTmpMod

	DB.setValue(nodeChar, "surprise.total", "number", nTotal)
	DB.setValue(nodeChar, "surprise.base", "number", nSurpriseBase)
end

---
--- Update initiative scores
---
function updateInitiativeScores()
	local nodeChar = getDatabaseNode()

	-- ALL MODS OFF, EXCEPT ZOMBIES
	-- default with modifiers on
	--local initiativeMod = DB.getValue(nodeChar,"initiative.misc",0);
	-- modifiers off
	--if OptionsManager.getOption("initiativeModifiersAllow") == "off" then

	-- zombies in OSRIC
	-- if (initiativeMod ~= 99) then
	--     initiativeMod = 0;
	-- end

	initiativeMod = 0

	--end

	-- where does nTmpMod come from - check 2e
	local nTmpMod = DB.getValue(nodeChar, "initiative.tempmod", 0)
	local nTotal = initiativeMod + nTmpMod

	DB.setValue(nodeChar, "initiative.total", "number", nTotal)
	DB.setValue(nodeChar, "initiative.misc", "number", nMod)
end
