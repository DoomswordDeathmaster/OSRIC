---
--- Create Combat Calc Matrix
---
---

function onInit()
	-- local node = getDatabaseNode();
	-- local bisPC = (ActorManager.isPC(node));

	-- Debug.console("char_matrix","onInit","bisPC",bisPC);

	-- DB.addHandler(DB.getPath(node, "fights_as_hd_level"), "onUpdate", createAttackMatrix);
	local node = getDatabaseNode()
	local bisPC = (ActorManager.isPC(node))
	local bUseMatrix = (DataCommonADND.coreVersion == "1e")

	if bUseMatrix then
		-- default value is 1e.
		local nLowAC = -10
		local nHighAC = 10
		local nTotalACs = 11

		if (DataCommonADND.coreVersion == "becmi") then
			nLowAC = -20
			nHighAC = 19
			nTotalACs = 20
		end

		DB.addHandler(DB.getPath(node, "combat.matrix.*"), "onUpdate", update);

		-- change combat calc matrix values for npc fights_as or pc level change matrix updates
		for i = nLowAC, nHighAC, 1 do
			-- do this only on PCs, to avoid recursion and allow proper updates for fights_as when npc combat calc window is already open
			if bisPC then
				DB.addHandler(DB.getPath(node, "thac" .. i), "onUpdate", update)
			end
		end
	else
		if (bisPC) then
			DB.addHandler(DB.getPath(node, "combat.thaco.score"), "onUpdate", update)
		else
			DB.addHandler(DB.getPath(node, "thaco"), "onUpdate", update)
		end
	end

	createAttackMatrix()
end

function onClose()
	if bUseMatrix then
		-- default value is 1e.
		local nLowAC = -10
		local nHighAC = 10
		local nTotalACs = 11

		if (DataCommonADND.coreVersion == "becmi") then
			nLowAC = -20
			nHighAC = 19
			nTotalACs = 20
		end

		DB.removeHandler(DB.getPath(node, "combat.matrix.*"), "onUpdate", update);

		for i = nLowAC, nHighAC, 1 do
			DB.removeHandler(DB.getPath(node, "thac" .. i), "onUpdate", update)
		end
	else
		if (bisPC) then
			DB.removeHandler(DB.getPath(node, "combat.thaco.score"), "onUpdate", update)
		else
			DB.removeHandler(DB.getPath(node, "thaco"), "onUpdate", update)
		end
	end
	-- local node = getDatabaseNode();
	-- local bisPC = (ActorManager.isPC(node));
	-- Debug.console("char_matrix","onClose","bisPC",bisPC);
	-- DB.removeHandler(DB.getPath(node, "fights_as_hd_level"), "onUpdate", createAttackMatrix);
end

function createAttackMatrix()
	-- default value is 1e.
	local nLowAC = -10
	local nHighAC = 10
	local nTotalACs = 11

	if (DataCommonADND.coreVersion == "becmi") then
		nLowAC = -20
		nHighAC = 19
		nTotalACs = 20
	end

	local node = getDatabaseNode()
	local bisPC = (ActorManager.isPC(node))
	local bUseMatrix = (DataCommonADND.coreVersion == "1e")
	local sHitDice = DB.getValue(node, "hitDice")
	local bClassRecord = node.getPath():match("^class%.")
	local nTHACO = DB.getValue(node, "combat.thaco.score", 20)
	local fightsAsClass = ""
	local fightsAsHdLevel = 0

	if (not bisPC) then
		nTHACO = DB.getValue(node, "thaco", 20)
	end

	-- 1e matrix
	local aMatrixRolls = {}

	-- assign the proper hit dice and class or monster matrix
	if bUseMatrix and not bisPC and not bClassRecord then
		fightsAsClass = DB.getValue(node, "fights_as")
		fightsAsClass = fightsAsClass:gsub("%s+", "")
		fightsAsHdLevel = DB.getValue(node, "fights_as_hd_level")

		--Debug.console("111", "npcHitDice", sHitDice, "fightsAsClass", fightsAsClass, "fightsAsHdLevel", fightsAsHdLevel)

		-- fights_as_hd_level not set
		if (fightsAsHdLevel == nil or fightsAsHdLevel == 0) then
			if (sHitDice == "0") then
				sHitDice = "-1"
				fightsAsHdLevel = 0
			elseif (sHitDice == "1-1") then
				-- string contains a +, as in hd 1+1
				fightsAsHdLevel = 1
			elseif string.find(sHitDice, "%+") then
				-- OSRIC
				fightsAsHdLevel = string.match(sHitDice, "%d+") + 2
				-- 1e DMG
				if (sHitDice ~= "1+1") then
					sHitDice = string.match(sHitDice, "%d+")
				else
					sHitDice = "1+"
				end
			elseif (fightsAsClass == "") then
				fightsAsHdLevel = tonumber(sHitDice) + 1
			else
				-- fights_as is set, so take the creature's hd
				fightsAsHdLevel = tonumber(sHitDice)
			end
		end

		--Debug.console("121", "fightsAsClass", fightsAsClass)
		--Debug.console("122", "fightsAsHdLevel", fightsAsHdLevel, "sHitDice", sHitDice)

		if (fightsAsClass ~= "") then
			if (fightsAsClass == "Assassin") then
				if (fightsAsHdLevel >= 13) then
					fightsAsHdLevel = 13
				end

				aMatrixRolls = DataCommonADND.aAssassinToHitMatrix[fightsAsHdLevel]
			elseif (fightsAsClass == "Cleric") then
				if (fightsAsHdLevel >= 19) then
					fightsAsHdLevel = 19
				end

				aMatrixRolls = DataCommonADND.aClericToHitMatrix[fightsAsHdLevel]
			elseif (fightsAsClass == "Druid") then
				if (fightsAsHdLevel >= 13) then
					fightsAsHdLevel = 13
				end

				aMatrixRolls = DataCommonADND.aDruidToHitMatrix[fightsAsHdLevel]
			elseif (fightsAsClass == "Fighter") then
				if (fightsAsHdLevel >= 20) then
					fightsAsHdLevel = 20
				end

				aMatrixRolls = DataCommonADND.aFighterToHitMatrix[fightsAsHdLevel]
			elseif (fightsAsClass == "Illusionist") then
				if (fightsAsHdLevel >= 21) then
					fightsAsHdLevel = 21
				end

				aMatrixRolls = DataCommonADND.aIllusionistToHitMatrix[fightsAsHdLevel]
			elseif (fightsAsClass == "MagicUser") then
				if (fightsAsHdLevel >= 21) then
					fightsAsHdLevel = 21
				end

				aMatrixRolls = DataCommonADND.aMagicUserToHitMatrix[fightsAsHdLevel]
			elseif (fightsAsClass == "Paladin") then
				if (fightsAsHdLevel >= 20) then
					fightsAsHdLevel = 20
				end

				aMatrixRolls = DataCommonADND.aPaladinToHitMatrix[fightsAsHdLevel]
			elseif (fightsAsClass == "Ranger") then
				if (fightsAsHdLevel >= 20) then
					fightsAsHdLevel = 20
				end

				aMatrixRolls = DataCommonADND.aRangerToHitMatrix[fightsAsHdLevel]
			elseif (fightsAsClass == "Thief") then
				if (fightsAsHdLevel >= 21) then
					fightsAsHdLevel = 21
				end

				aMatrixRolls = DataCommonADND.aThiefToHitMatrix[fightsAsHdLevel]
			end
		else
			if (fightsAsHdLevel >= 20) then
				fightsAsHdLevel = 20
			end

			aMatrixRolls = DataCommonADND.aOsricToHitMatrix[fightsAsHdLevel]
		end
	end

	local sACLabelName = "matrix_ac_label"
	local sRollLabelName = "matrix_roll_label"
	local matrixControlReadOnly = "false"

	-- loop through possible ac values and assign a to-hit value
	for i = nLowAC, nHighAC, 1 do
		-- to hit AC value, default to 20
		local nTHAC = DB.getValue(node, "combat.matrix.thac" .. i, 20)

		-- db values only for PCs, calculated values for NPCs
		if bUseMatrix then
			--Debug.console("char_matrix:131", bisPC)
			if bisPC or bClassRecord then
				--Debug.console("char_matrix:116", bisPC, bClassRecord)
				nTHAC = DB.getValue(node, "combat.matrix.thac" .. i, 20)
				matrixControlReadOnly = "true"
			else
				-- math.abs(i-11), this table is reverse of how we display the matrix
				-- so we start at the end instead of at the front by taking I - 11 then get the absolute value of it.
				nTHAC = aMatrixRolls[math.abs(i - 11)]

				-- get value from db, in case it's been explicitly set
				local nTHACDb = DB.getValue(node, "thac" .. i)
				--Debug.console("char_matrix:142", "nTHACDb", nTHACDb)

				-- get value from aMatrixRolls
				local nTHACM = aMatrixRolls[math.abs(i - nTotalACs)]
				--Debug.console("char_matrix:146", "nTHACM", nTHACM)

				if (fightsAsClass ~= "" or (fightsAsHdLevel ~= 0 and fightsAsHdLevel ~= tonumber(sHitDice))) then
					--Debug.console("119", fightsAsClass);
					nTHAC = nTHACM
					matrixControlReadOnly = "true"
					--Debug.console("char_matrix:151", "nTHAC", nTHAC)
				elseif (nTHACDb ~= nil and nTHACDb ~= nTHACM) then
					nTHAC = nTHACDb
					--Debug.console("char_matrix:154", "nTHAC", nTHAC)
				else
					nTHAC = nTHACM
					--Debug.console("char_matrix:157", "nTHAC", nTHAC)
				end
			end
		end

		local sMatrixACName = "matrix_ac_" .. i
		local sMatrixACValue = i
		local sMatrixNumberName = "thac" .. i

		local cntNum = nil

		cntNum = createControl("number_matrix", sMatrixNumberName)

		if (matrixControlReadOnly == "false") then
			cntNum.setReadOnly(false)
		else
			cntNum.setReadOnly(true)
		end

		cntNum.setValue(nTHAC)

		local cntAC = createControl("label_fieldtop_matrix", sMatrixACName)

		cntAC.setReadOnly(true)
		cntAC.setValue(sMatrixACValue)
		cntAC.setAnchor("left", sMatrixNumberName, "left", "absolute", 0)
	end
end

-- continue working on this
-- update for handler registration
function update()
	--Debug.console("char_matrix_thaco.lua:276", "updating combat_mini_thaco_matrix")
	local node = getDatabaseNode();
  --Debug.console("char_matrix_thaco.lua","update","node",node);
	local bisPC = (ActorManager.isPC(node)); 
  --Debug.console("char_matrix_thaco.lua","createTHACOMatrix","node",node);
	local bUseMatrix = (DataCommonADND.coreVersion ~= "2e");
  
	local nTHACO = DB.getValue(node,"combat.thaco.score",20);
	if (not bisPC) then
	  nTHACO = DB.getValue(node,"thaco",20);
	end
	for i=-10,10,1 do -- update to changed THACO. Set the new values in previously created controls
	  local nTHAC = nTHACO - i;
	  if bUseMatrix then
		nTHAC = DB.getValue(node,"combat.matrix.thac" .. i, 20);
	  end
	  
	  local sMatrixNumberName = "thac" .. i; -- control name for the THACO label
	  local cnt = self[sMatrixNumberName];   -- get the control for this, stringcontrol named thac-10 .. thac10
	  cnt.setValue(nTHAC); -- set new to hit AC value
	end
  end
