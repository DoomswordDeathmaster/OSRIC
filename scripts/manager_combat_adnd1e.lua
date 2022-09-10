--
-- AD&D Specific combat needs
--
--

PC_LASTINIT = 0
NPC_LASTINIT = 0
OOB_MSGTYPE_CHANGEINIT = "changeinitiative"

function onInit()
    rollEntryInitOrig = CombatManagerADND.rollEntryInit
    CombatManagerADND.rollEntryInit = rollEntryInitNew
    CombatManager2.rollEntryInit = rollEntryInitNew

    CombatManagerADND.rollRandomInit = rollRandomInitNew
    CombatManager2.rollRandomInit = rollRandomInitNew

    getACHitFromMatrixForNPCOrig = CombatManagerADND.getACHitFromMatrixForNPC
    CombatManagerADND.getACHitFromMatrixForNPC = getACHitFromMatrixForNPCNew

    CombatManagerADND.handleInitiativeChange = handleInitiativeChangeNew
    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CHANGEINIT, handleInitiativeChangeNew)

    --
    CombatManager.setCustomCombatReset(resetInitNew)
    CombatManager.setCustomRoundStart(onRoundStartNew)
end

function rollRandomInitNew(nMod)
    local nInitResult = math.random(DataCommonADND.nDefaultInitiativeDice)
    Debug.console("rollrandominitnew 39", nInitResult)
    return nInitResult
end

function rollEntryInitNew(nodeEntry)
    local bOsricInitiativeSwap = (OptionsManager.getOption("useOsricInitiativeSwap") == "on")

    Debug.console("nodeEntry", nodeEntry)

    if not nodeEntry then
        return
    end

    Debug.console("rollEntryInitNew")

    -- PC/NPC init
    local sClass, sRecord = DB.getValue(nodeEntry, "link", "", "")

    -- it's a PC
    if sClass == "charsheet" then
        -- it's an NPC
        Debug.console("PC Init")
        local nodeChar = DB.findNode(sRecord)
        -- default PC initiative totals to 0
        local nInitPC = 0
        local nInitResult = 0

        -- if init mods are on
        -- if bOptInitMods then
        --     nInitPC = DB.getValue(nodeChar,"initiative.total",0);
        -- end

        -- if grouping involving pcs is on
        -- if bOptPCVNPCINIT then --or (sOptInitGrouping == "pc" or sOptInitGrouping == "both") then
        -- roll without mods
        nInitResult = rollRandomInitNew(0)
        -- group init - apply init result to remaining PCs
        applyInitResultToAllPCs(nInitResult)
        -- set last init for comparison for ties and swapping
        PC_LASTINIT = nInitResult

        -- just set both of these values regardless of initiative die used, so we don't have to mod other places where initresult is displayed
        DB.setValue(nodeEntry, "initresult", "number", nInitResult)
        DB.setValue(nodeEntry, "initresult_d6", "number", nInitResult)
    else
        Debug.console("NPC Init")
        -- it's an npc
        -- if grouping involving npcs is on
        -- if bOptPCVNPCINIT then --or (sOptInitGrouping == "npc" or sOptInitGrouping == "both") then
        -- roll without mods
        nInitResult = rollRandomInitNew(0)
        -- group init - apply init result to remaining NPCs
        applyInitResultToAllNPCs(nInitResult)
        -- set last init for comparison for ties and swapping
        NPC_LASTINIT = nInitResult

        local nTotal = DB.getValue(nodeEntry, "initiative.total", 0)
    end

    -- init grouping swap
    if bOsricInitiativeSwap then
        Debug.console("SWAP!")
        --if bOptPCVNPCINIT then --or (sOptInitGrouping ~= "neither") then
        applyInitResultToAllPCs(NPC_LASTINIT)
        applyInitResultToAllNPCs(PC_LASTINIT)
    --end
    end
    --end
end

function applyInitResultToAllPCs(nInitResult)
    -- group init - apply init result to all PCs
    for _, v in pairs(CombatManager.getCombatantNodes()) do
        if DB.getValue(v, "friendfoe") == "friend" then
            -- just set both of these values regardless of initiative die used, so we don't have to mod other places where initresult is displayed
            DB.setValue(v, "initresult", "number", nInitResult)
            DB.setValue(v, "initresult_d6", "number", nInitResult)
            -- set init rolled
            DB.setValue(v, "initrolled", "number", 1)
        end
    end
end

function applyInitResultToAllNPCs(nInitResult)
    -- group init - apply init result to remaining NPCs
    for _, v in pairs(CombatManager.getCombatantNodes()) do
        if DB.getValue(v, "friendfoe") ~= "friend" then
            -- basically just zombies so that they go last
            local nInit = DB.getValue(v, "init", 0)

            if nInit == 99 then
                -- just set both of these values regardless of initiative die used, so we don't have to mod other places where initresult is displayed
                DB.setValue(v, "initresult", "number", 10)
                DB.setValue(v, "initresult_d6", "number", 10)
            else
                -- just set both of these values regardless of initiative die used, so we don't have to mod other places where initresult is displayed
                DB.setValue(v, "initresult", "number", nInitResult)
                DB.setValue(v, "initresult_d6", "number", nInitResult)
            end

            -- set init rolled
            DB.setValue(v, "initrolled", "number", 1)
            Debug.console("combat 254", v)
        end
    end
end

function handleInitiativeChangeNew(msgOOB)
    local nodeCT = DB.findNode(msgOOB.sCTRecord)

    if nodeCT then
        DB.setValue(nodeCT, "initresult", "number", msgOOB.nNewInit)
        DB.setValue(nodeCT, "initresult_d6", "number", msgOOB.nNewInit)
    end
end

-- 1e/OSRIC alwaysd does this
function resetInitNew()
    -- set last init results to 0
    PC_LASTINIT = 0
    NPC_LASTINIT = 0

    for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
        resetCombatantInit(nodeCT)
    end
end

function onRoundStartNew(nCurrent)
    local bOptAutoNpcInitiative = (OptionsManager.getOption("autoNpcInitiative") == "on")

    PC_LASTINIT = 0
    NPC_LASTINIT = 0

    --if bOptRoundStartResetInit then
    for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
        resetCombatantInit(nodeCT)
    end
    --end

    if bOptAutoNpcInitiative then
        local nInitResult = rollRandomInitNew(0)

        local bOsricInitiativeSwap = (OptionsManager.getOption("useOsricInitiativeSwap") == "on")

        if bOsricInitiativeSwap then
            applyInitResultToAllPCs(nInitResult)
        else
            applyInitResultToAllNPCs(nInitResult)
        end

        -- DB.setValue(nodeEntry, "initresult", "number", nInitResult)
        -- DB.setValue(nodeEntry, "initresult_d6", "number", nInitResult)
    end
end

function resetCombatantInit(nodeCT)
    DB.setValue(nodeCT, "initresult", "number", 0)
    DB.setValue(nodeCT, "initresult_d6", "number", 0)
    DB.setValue(nodeCT, "reaction", "number", 0)

    -- toggle portrait initiative icon
    CharlistManagerADND.turnOffAllInitRolled()
    -- toggle all "initrun" values to not run
    CharlistManagerADND.turnOffAllInitRun()
end

-- return the Best ac hit from a roll for this NPC
function getACHitFromMatrixForNPCNew(nodeCT, nRoll)
    --Debug.console(nodeCT, sHitDice, aMatrixRolls);

    local sClass, nodePath = DB.getValue(nodeCT, "sourcelink")
    local nodeNPC = DB.findNode(nodePath)
    --Debug.console("394", sClass, nodeNPC);
    --Debug.console("395", rActor, nodeNPC, sHitDice, aMatrixRolls);

    local nACHit = 20
    local sHitDice = DB.getValue(nodeNPC, "hitDice") --CombatManagerADND.getNPCHitDice(node);
    local aMatrixRolls = {}

    -- default value is 1e.
    local nLowAC = -10
    local nHighAC = 10
    local nTotalACs = 11

    if (DataCommonADND.coreVersion == "becmi") then
        nLowAC = -20
        nHighAC = 19
        nTotalACs = 20
    end

    Debug.console("nodeNpc", nodeNPC)
    fightsAsClass = DB.getValue(nodeNPC, "fights_as")

    Debug.console("fightsAs", DB.getValue(nodeNPC, "fights_as"))

    if fightsAsClass ~= nil then
        fightsAsClass = string.gsub(fightsAsClass, "%s+", "")
    else
        fightsAsClass = ""
    end

    fightsAsHdLevel = DB.getValue(nodeNPC, "fights_as_hd_level")

    --Debug.console("111", "npcHitDice", sHitDice, "fightsAsClass", fightsAsClass, "fightsAsHdLevel", fightsAsHdLevel);

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

    --Debug.console("121", "fightsAsClass", fightsAsClass);
    --Debug.console("122", "fightsAsHdLevel", fightsAsHdLevel, "sHitDice", sHitDice);

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

        local bUseOsricMonsterMatrix = (OptionsManager.getOption("useOsricMonsterMatrix") == "on")
        --Debug.console("514", "fightsAsHdLevel", fightsAsHdLevel, "bUseOsricMonsterMatrix", bUseOsricMonsterMatrix);

        if bUseOsricMonsterMatrix then
            aMatrixRolls = DataCommonADND.aOsricToHitMatrix[fightsAsHdLevel]
        else
            aMatrixRolls = DataCommonADND.aMatrix[sHitDice]

            -- for hit dice above 16, use 16
            if (aMatrixRolls == nil) then
                sHitDice = "16"
                aMatrixRolls = DataCommonADND.aMatrix[sHitDice]
            end
        end
    end

    --Debug.console("manager_combat_adnd_op_hr","getACHitFromMatrixForNPCNew","aMatrixRolls",aMatrixRolls);
    local nACBase = 11

    if (DataCommonADND.coreVersion == "becmi") then
        nACBase = 20
    end

    for i = #aMatrixRolls, 1, -1 do
        local sCurrentTHAC = "thac" .. i
        local nAC = nACBase - i
        local nCurrentTHAC = aMatrixRolls[i]

        -- get value from db, in case it's been explicitly set
        local nTHACDb = DB.getValue(nodeNPC, "thac" .. i)
        --Debug.console("char_matrix_thaco:151", "nTHACDb", nTHACDb);

        -- get value from aMatrixRolls
        local nTHACM = aMatrixRolls[math.abs(i - nTotalACs)]
        --Debug.console("char_matrix_thaco:155", "nTHACM", nTHACM);

        if (fightsAsClass ~= "" or (fightsAsHdLevel ~= 0 and fightsAsHdLevel ~= tonumber(sHitDice))) then
            --Debug.console("char_matrix_thaco:173", "nTHAC", nTHAC);
            --Debug.console("119", fightsAsClass, fightsAsHdLevel, tonumber(sHitDice));
            sCurrentTHAC = nTHACM
        elseif (nTHACDb ~= nil and nTHACDb ~= nTHACM) then
            --Debug.console("char_matrix_thaco:176", "nTHAC", nTHAC);
            sCurrentTHAC = nTHACDb
        else
            --Debug.console("char_matrix_thaco:179", "nTHAC", nTHAC);
            sCurrentTHAC = nTHACM
        end

        if nRoll >= nCurrentTHAC then
            -- find first AC that matches our roll
            nACHit = nAC
            break
        end
    end

    return nACHit
end
