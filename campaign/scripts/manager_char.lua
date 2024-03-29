--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- decided to bring in this entire script for additional functionality -- Doomsword 04/06/23
-- remove these at some point, not useful in AD&D --celestian
RACE_DWARF = "dwarf"
RACE_DUERGAR = "duergar"

CLASS_BARBARIAN = "barbarian"
CLASS_MONK = "monk"
CLASS_SORCERER = "sorcerer"

TRAIT_DWARVEN_TOUGHNESS = "dwarven toughness"
TRAIT_POWERFUL_BUILD = "powerful build"
TRAIT_NATURAL_ARMOR = "natural armor"
TRAIT_CATS_CLAWS = "cat's claws"

FEATURE_WARRIOR_HITPOINT_BONUS = "warrior hitpoint bonus"

FEATURE_UNARMORED_DEFENSE = "unarmored defense"
FEATURE_DRACONIC_RESILIENCE = "draconic resilience"
FEATURE_PACT_MAGIC = "pact magic"
FEATURE_SPELLCASTING = "spellcasting"

FEAT_TOUGH = "tough"

function onInit()
    --Debug.console("manager_char.lua", "onint")
    ItemManager.setCustomCharAdd(onCharItemAdd)
    ItemManager.setCustomCharRemove(onCharItemDelete)
    -- watch PC items
    DB.addHandler("charsheet.*.inventorylist.*.isidentified", "onUpdate", onItemIDChanged)
    -- to watch npc updates
    DB.addHandler("combattracker.list.*.inventorylist.*.isidentified", "onUpdate", onItemIDChanged)
    DB.addHandler("npc.*.inventorylist.*.isidentified", "onUpdate", onItemIDChanged)
end

function outputUserMessage(sResource, ...)
    local sFormat = Interface.getString(sResource)
    local sMsg = string.format(sFormat, ...)
    UtilityManagerADND.logDebug(sMsg)
    ChatManager.SystemMessage(sMsg)
end

-- output the text to chat and log it.
--[[

  sMsg          = the text message logged.
  nodeChar      = the target character sheet
  sRecord       = the node.getPath() for the record changed
  previousValue = whatever variable was changed, it's original value
  
]]
function outputAdvancementLog(sMsg, nodeChar, sRecord, previousValue)
    if sMsg and sMsg ~= "" then
        UtilityManagerADND.logDebug(sMsg, sRecord, previousValue)
        ChatManager.SystemMessage(sMsg)
        logCharacterChange(sMsg, nodeChar, sRecord, previousValue)
    end
end
-- log change to log.advancement for use in reversion.
function logCharacterChange(sMsg, nodeChar, sRecord, previousValue)
    if nodeChar then
        local nodeLog = DB.createChild(nodeChar, "log")
        local nodeLogAdvancement = DB.createChild(nodeLog, "advancement")
        local nodeEntry = nodeLogAdvancement.createChild()
        DB.setValue(nodeEntry, "time", "string", os.time())
        --DB.setValue(nodeEntry,"text","formattedtext","<p><b>" .. os.date("%x %X") .. "</b>" .. sMsg .. "</p>");
        DB.setValue(nodeEntry, "text", "string", os.date("%x %X") .. " > " .. sMsg)
        if sRecord and sRecord ~= "" then
            -- strip out the "charsheet.id-00000X." piece.
            -- That way if they import the character we can still adjust
            if sRecord:match("^charsheet%.id%-%d+%.(.*)") then
                sRecord = sRecord:match("^charsheet%.id%-%d+%.(.*)")
            end
            DB.setValue(nodeEntry, "record", "string", sRecord)
            if previousValue then
                DB.setValue(nodeEntry, "previous", type(previousValue), previousValue)
            end
        end
    end
end

--
-- CLASS MANAGEMENT
--

function sortClasses(a, b)
    return DB.getValue(a, "name", "") < DB.getValue(b, "name", "")
end

function getClassLevelSummary(nodeChar, bShort)
    if not nodeChar then
        return ""
    end

    local aClasses = {}

    local aSorted = {}
    for _, nodeChild in pairs(DB.getChildren(nodeChar, "classes")) do
        table.insert(aSorted, nodeChild)
    end
    table.sort(aSorted, sortClasses)

    for _, nodeChild in pairs(aSorted) do
        local sClass = DB.getValue(nodeChild, "name", "")
        local nLevel = DB.getValue(nodeChild, "level", 0)
        if nLevel > 0 then
            if bShort then
                sClass = sClass:sub(1, 3)
            end
            table.insert(aClasses, sClass .. " " .. math.floor(nLevel * 100) * 0.01)
        end
    end

    local sSummary = table.concat(aClasses, " / ")
    return sSummary
end

function getClassHDUsage(nodeChar)
    local nHD = 0
    local nHDUsed = 0

    for _, nodeChild in pairs(DB.getChildren(nodeChar, "classes")) do
        local nLevel = DB.getValue(nodeChild, "level", 0)
        local nHDMult = #(DB.getValue(nodeChild, "hddie", {}))
        nHD = nHD + (nLevel * nHDMult)
        nHDUsed = nHDUsed + DB.getValue(nodeChild, "hdused", 0)
    end

    return nHDUsed, nHD
end

--
-- ITEM/FOCUS MANAGEMENT
--

function onCharItemAdd(nodeItem)
    --Debug.console("manager_char.lua onCharItemAdd nodeItem", nodeItem, DB.getValue(nodeItem, "name"))

    local sTypeLower = StringManager.trim(DB.getValue(DB.getPath(nodeItem, "type"), ""):lower())
    if
        StringManager.contains(
            {"mounts and other animals", "waterborne vehicles", "tack, harness, and drawn vehicles"},
            sTypeLower
        )
     then
        DB.setValue(nodeItem, "carried", "number", 0)
    else
        DB.setValue(nodeItem, "carried", "number", 1)
    end

    addToArmorDB(nodeItem)
    addToWeaponDB(nodeItem)
    addToPowerDB(nodeItem)
end

function onCharItemDelete(nodeItem)
    removeFromArmorDB(nodeItem)
    removeFromWeaponDB(nodeItem)
    removeFromPowerDB(nodeItem)
end

-- Use CoreRPG/base weight calc functions but add our movement/enc rank adjustments.
function calcWeightCarried(nodeChar)
    CharEncumbranceManager.calcDefaultEncumbrance(nodeChar)
    if (DataCommonADND.coreVersion == "1e") then
        CharManager.updateMoveFromEncumbrance1e(nodeChar)
    else
        CharManager.updateMoveFromEncumbrance2e(nodeChar)
    end
end

-- update speed.basemodenc due to weight adjustments for AD&D 2e
function updateMoveFromEncumbrance2e(nodeChar)
    -- Debug.console("manager_char.lua updateMoveFromEncumbrance2e nodeChar",nodeChar);
    if OptionsManager.getOption("OPTIONAL_ENCUMBRANCE") == "on" then
        if ActorManager.isPC(nodeChar) then -- only need this if the node is a PC
            -- local nEncLight = 0.33;   -- 1/3
            -- local nEncModerate = 0.5; -- 1/2
            -- local nEncHeavy = 0.67;   -- 2/3
            local sEncRankOriginal = DB.getValue(nodeChar, "speed.encumbrancerank", "")
            local sEncRank, nBaseEnc, nBaseMove = getEncumbranceRank2e(nodeChar)

            if nBaseMove == nBaseEnc then -- if base move and encumbrance move is the same, we dont need encumbrance base value set.
                DB.setValue(nodeChar, "speed.basemodenc", "number", 0)
            else
                DB.setValue(nodeChar, "speed.basemodenc", "number", nBaseEnc)
            end
            DB.setValue(nodeChar, "speed.encumbrancerank", "string", sEncRank)
            if (sEncRankOriginal ~= sEncRank) then
                local sFormat = Interface.getString("message_encumbrance_changed")
                local sMsg = string.format(sFormat, DB.getValue(nodeChar, "name", ""), sEncRank, nBaseEnc)
                ChatManager.SystemMessage(sMsg)
            end
        end
    else
        DB.setValue(nodeChar, "speed.basemodenc", "number", 0)
        DB.setValue(nodeChar, "speed.encumbrancerank", "string", "Normal")
    end
end

-- get the encumbrance rank, nBaseEnc and nBaseMove.
function getEncumbranceRank2e(nodeChar)
    local b2e = (DataCommonADND.coreVersion == "2e")
    if not b2e then
        return "", 0, 0
    end
    local nEncLight = 0.33 -- 1/3
    local nEncModerate = 0.5 -- 1/2
    local nEncHeavy = 0.67 -- 2/3
    local nBaseEnc = 0
    local sEncRank = "Normal"
    local nBaseMove = DB.getValue(nodeChar, "speed.base", 0)
    local nStrength = DB.getValue(nodeChar, "abilities.strength.score", 0)
    local nPercent = DB.getValue(nodeChar, "abilities.strength.percent", 0)
    local nWeightCarried = DB.getValue(nodeChar, "encumbrance.load", 0)

    if nStrength <= 0 then
        nStrength = 1
    end
    if nStrength >= 25 then
        nStrength = 25
    end
    -- magic armor doesn't count towards encumbrance
    local bMagicArmor, nodeArmor = ItemManager2.isWearingMagicArmor(nodeChar)
    if (bMagicArmor) then
        local nArmorWT = DB.getValue(nodeArmor, "weight", 0)
        nWeightCarried = nWeightCarried - nArmorWT
        if nWeightCarried < 0 then
            nWeightCarried = 0
        end
    end
    --

    -- Deal with 18 01-100 strength
    if ((nStrength == 18) and (nPercent > 0)) then
        local nPercentRank = 50
        if (nPercent == 100) then
            nPercentRank = 100
        elseif (nPercent >= 91 and nPercent <= 99) then
            nPercentRank = 99
        elseif (nPercent >= 76 and nPercent <= 90) then
            nPercentRank = 90
        elseif (nPercent >= 51 and nPercent <= 75) then
            nPercentRank = 75
        elseif (nPercent >= 1 and nPercent <= 50) then
            nPercentRank = 50
        end
        nStrength = nPercentRank
    end

    -- determine if wt carried is greater than a encumbrance rank for strength value
    if (nWeightCarried >= DataCommonADND.aStrength[nStrength][11]) then
        nBaseEnc = (nBaseMove - 1) -- greater than max, base is 1
        sEncRank = "MAX"
    elseif (nWeightCarried >= DataCommonADND.aStrength[nStrength][10]) then
        nBaseEnc = (nBaseMove - 1) -- greater than severe, base is 1
        sEncRank = "Severe"
    elseif (nWeightCarried >= DataCommonADND.aStrength[nStrength][9]) then
        nBaseEnc = nBaseMove * nEncHeavy -- greater than heavy
        sEncRank = "Heavy"
    elseif (nWeightCarried >= DataCommonADND.aStrength[nStrength][8]) then
        nBaseEnc = nBaseMove * nEncModerate -- greater than moderate
        sEncRank = "Moderate"
    elseif (nWeightCarried >= DataCommonADND.aStrength[nStrength][7]) then
        nBaseEnc = nBaseMove * nEncLight -- greater than light
        sEncRank = "Light"
    end

    nBaseEnc = math.floor(nBaseEnc)
    nBaseEnc = nBaseMove - nBaseEnc
    if (nBaseEnc < 1) then
        nBaseEnc = 1
    end

    return sEncRank, nBaseEnc, nBaseMove
end

-- update speed.basemodenc due to weight adjustments for AD&D 1e
function updateMoveFromEncumbrance1e(nodeChar)
    --Debug.console("manager_char.lua","updateMoveFromEncumbrance1e","nodeChar",nodeChar);
    if OptionsManager.getOption("OPTIONAL_ENCUMBRANCE") == "on" then
        if ActorManager.isPC(nodeChar) then -- only need this is the node is a PC
            local nEncLight = 0.33 -- 1/3
            local nEncModerate = 0.5 -- 1/2
            local nEncHeavy = 0.67 -- 2/3

            local nStrength = DB.getValue(nodeChar, "abilities.strength.score", 0)
            local nPercent = DB.getValue(nodeChar, "abilities.strength.percent", 0)
            local nWeightCarried = DB.getValue(nodeChar, "encumbrance.load", 0)
            local nBaseMove = DB.getValue(nodeChar, "speed.base", 0)
            local nBaseEncOriginal = DB.getValue(nodeChar, "speed.basemodenc", 0)
            local sEncRankOriginal = DB.getValue(nodeChar, "speed.encumbrancerank", "")
            local nBaseEnc = 0
            local sEncRank = "Normal"

            -- Deal with 18 01-100 strength
            if ((nStrength == 18) and (nPercent > 0)) then
                local nPercentRank = 50
                if (nPercent == 100) then
                    nPercentRank = 100
                elseif (nPercent >= 91 and nPercent <= 99) then
                    nPercentRank = 99
                elseif (nPercent >= 76 and nPercent <= 90) then
                    nPercentRank = 90
                elseif (nPercent >= 51 and nPercent <= 75) then
                    nPercentRank = 75
                elseif (nPercent >= 1 and nPercent <= 50) then
                    nPercentRank = 50
                end
                nStrength = nPercentRank
            end

            local nWeightAllowance = DataCommonADND.aStrength[nStrength][3]
            nWeightAllowance = math.floor(nWeightAllowance / 10) -- convert the coin weight 1e style to actual pounds

            local nHeavyCarry = 105
            local nModerateCarry = 70
            local nNormalCarry = 35

            -- determine if wt carried is greater than a encumbrance rank for strength value
            if (nWeightCarried >= (nHeavyCarry + nWeightAllowance)) then
                nBaseEnc = nBaseMove * nEncHeavy -- greater than heavy
                sEncRank = "Heavy"
            elseif (nWeightCarried >= (nModerateCarry + nWeightAllowance)) then
                nBaseEnc = nBaseMove * nEncModerate -- greater than moderate
                sEncRank = "Moderate"
            elseif (nWeightCarried >= (nNormalCarry + nWeightAllowance)) then
                nBaseEnc = nBaseMove * nEncLight -- greater than light
                sEncRank = "Light"
            else
                nBaseEnc = nBaseMove
            end

            if nBaseMove == nBaseEnc then
                DB.setValue(nodeChar, "speed.basemodenc", "number", 0)
            else
                nBaseEnc = math.floor(nBaseEnc)
                nBaseEnc = nBaseMove - nBaseEnc
                if (nBaseEnc < 1) then
                    nBaseEnc = 1
                end
                DB.setValue(nodeChar, "speed.basemodenc", "number", nBaseEnc)
            end
            DB.setValue(nodeChar, "speed.encumbrancerank", "string", sEncRank)
            if (sEncRankOriginal ~= sEncRank) then
                local sFormat = Interface.getString("message_encumbrance_changed")
                local sMsg = string.format(sFormat, DB.getValue(nodeChar, "name", ""), sEncRank, nBaseEnc)
                --ChatManager.SystemMessage(sMsg);
                outputAdvancementLog(sMsg, nodeChar)
            end
        end
    else
        DB.setValue(nodeChar, "speed.basemodenc", "number", 0)
        DB.setValue(nodeChar, "speed.encumbrancerank", "string", "Normal")
    end
end

function getEncumbranceMult(nodeChar)
    local sSize = StringManager.trim(DB.getValue(nodeChar, "size", ""):lower())

    local nSize = 2 -- Medium
    if sSize == "tiny" then
        nSize = 0
    elseif sSize == "small" then
        nSize = 1
    elseif sSize == "large" then
        nSize = 3
    elseif sSize == "huge" then
        nSize = 4
    elseif sSize == "gargantuan" then
        nSize = 5
    end
    if hasTrait(nodeChar, TRAIT_POWERFUL_BUILD) then
        nSize = nSize + 1
    end

    local nMult = 1 -- Both Small and Medium use a multiplier of 1
    if nSize == 0 then
        nMult = 0.5
    elseif nSize == 3 then
        nMult = 2
    elseif nSize == 4 then
        nMult = 4
    elseif nSize == 5 then
        nMult = 8
    elseif nSize == 6 then
        nMult = 16
    end

    return nMult
end

--
-- ARMOR MANAGEMENT
--

function removeFromArmorDB(nodeItem)
    -- Parameter validation
    local bArmor = ItemManager2.isArmor(nodeItem)
    local bShield = ItemManager2.isShield(nodeItem)
    local bProtOther = ItemManager2.isProtectionOther(nodeItem)

    if not bArmor and not bShield and not bProtOther then
        return
    end

    -- If this armor was worn, recalculate AC
    if DB.getValue(nodeItem, "carried", 0) == 2 then
        DB.setValue(nodeItem, "carried", "number", 1)
    end
end

function addToArmorDB(nodeItem)
    -- Parameter validation
    local bIsArmor, _, sSubtypeLower = ItemManager2.isArmor(nodeItem)
    local bShield = ItemManager2.isShield(nodeItem)
    --local bProtOther = ItemManager2.isProtectionOther(nodeItem);

    if not bIsArmor then
        return
    end
    if not (bIsShield) then
        bIsShield = (sSubtypeLower == "shield")
    end

    -- Determine whether to auto-equip armor
    local bArmorAllowed = true
    local bShieldAllowed = true
    local nodeChar = nodeItem.getChild("...")
    if hasFeature(nodeChar, FEATURE_UNARMORED_DEFENSE) then
        bArmorAllowed = false

        for _, v in pairs(nodeList.getChildren()) do
            local sClassName = StringManager.trim(DB.getValue(v, "name", "")):lower()
            if (sClassName == CLASS_BARBARIAN) then
                break
            elseif (sClassName == CLASS_MONK) then
                bShieldAllowed = false
                break
            end
        end
    end
    if hasTrait(nodeChar, TRAIT_NATURAL_ARMOR) then
        bArmorAllowed = false
        bShieldAllowed = false
    end
    if (bArmorAllowed and not bIsShield) or (bShieldAllowed and bIsShield) then
        local bArmorEquipped = false
        local bShieldEquipped = false
        for _, v in pairs(DB.getChildren(nodeItem, "..")) do
            if DB.getValue(v, "carried", 0) == 2 then
                local bIsItemArmor, _, sItemSubtypeLower = ItemManager2.isArmor(v)
                if bIsItemArmor then
                    if (sItemSubtypeLower == "shield") then
                        bShieldEquipped = true
                    else
                        bArmorEquipped = true
                    end
                end
            end
        end
        if bShieldAllowed and bIsShield and not bShieldEquipped then
            DB.setValue(nodeItem, "carried", "number", 2)
        elseif bArmorAllowed and not bIsShield and not bArmorEquipped then
            DB.setValue(nodeItem, "carried", "number", 2)
        end
    end
end

-- calculate armor class and set? -celestian
function calcItemArmorClass(nodeChar)
    local nMainArmorBase = 10
    local nMainArmorTotal = 0
    local nMainShieldTotal = 0
    local bNonCloakArmorWorn = ItemManager2.isWearingArmorNamed(nodeChar, DataCommonADND.itemArmorNonCloak)
    local bMagicArmorWorn = ItemManager2.isWearingMagicArmor(nodeChar)
    local bUsingShield = ItemManager2.isWearingShield(nodeChar)

    -- Debug.console("manager_char.lua","calcItemArmorClass","bNonCloakArmorWorn",bNonCloakArmorWorn);
    -- Debug.console("manager_char.lua","calcItemArmorClass","bMagicArmorWorn",bMagicArmorWorn);
    -- Debug.console("manager_char.lua","calcItemArmorClass","bUsingShield",bUsingShield);

    for _, vNode in pairs(DB.getChildren(nodeChar, "inventorylist")) do
        if DB.getValue(vNode, "carried", 0) == 2 then
            local sTypeLower = StringManager.trim(DB.getValue(vNode, "type", "")):lower()
            local sSubtypeLower = StringManager.trim(DB.getValue(vNode, "subtype", "")):lower()
            local bIsArmor, _, _ = ItemManager2.isArmor(vNode)
            local bIsWarding, _, _ = ItemManager2.isWarding(vNode)
            local bIsShield = (StringManager.contains(DataCommonADND.itemShieldArmorTypes, sSubtypeLower))
            if (not bIsShield) then
                bIsShield = ItemManager2.isShield(vNode)
            end
            local bIsRingOrCloak = (StringManager.contains(DataCommonADND.itemOtherArmorTypes, sSubtypeLower))
            if (not bIsRingOrCloak) then
                bIsRingOrCloak = ItemManager2.isProtectionOther(vNode)
            end

            -- cloaks of protection dont work with magic armor, shields or any armor other than leather.
            if
                ItemManager2.isItemAnyType("cloak", sTypeLower, sSubtypeLower) and
                    (bNonCloakArmorWorn or bMagicArmorWorn or bUsingShield)
             then
                bIsRingOrCloak = false
                bIsArmor = false
                bIsShield = false
            end
            -- robe of protection dont work with magic armor, shields or any armor other than leather.
            if
                ItemManager2.isItemAnyType("robe", sTypeLower, sSubtypeLower) and
                    (bNonCloakArmorWorn or bMagicArmorWorn or bUsingShield)
             then
                bIsRingOrCloak = false
                bIsArmor = false
                bIsShield = false
            end
            -- rings of protection dont work with any magic armor
            if ItemManager2.isItemAnyType("ring", sTypeLower, sSubtypeLower) and (bMagicArmorWorn) then
                bIsRingOrCloak = false
                bIsArmor = false
                bIsShield = false
            end
            --

            -- Debug.console("manager_char.lua","calcItemArmorClass","sTypeLower",sTypeLower);
            -- Debug.console("manager_char.lua","calcItemArmorClass","sSubtypeLower",sSubtypeLower);
            -- Debug.console("manager_char.lua","calcItemArmorClass","nMainArmorBase",nMainArmorBase);
            -- Debug.console("manager_char.lua","calcItemArmorClass","nMainArmorTotal",nMainArmorTotal);
            -- Debug.console("manager_char.lua","calcItemArmorClass","bIsArmor",bIsArmor);
            -- Debug.console("manager_char.lua","calcItemArmorClass","bIsWarding",bIsWarding);
            -- Debug.console("manager_char.lua","calcItemArmorClass","bIsShield",bIsShield);
            -- Debug.console("manager_char.lua","calcItemArmorClass","bIsRingOrCloak-last",bIsRingOrCloak);
            -- Debug.console("manager_char.lua","calcItemArmorClass","----------------------------");

            if bIsArmor or bIsWarding or bIsShield or bIsRingOrCloak then
                local bID = LibraryData.getIDState("item", vNode, true)
                -- we could use bID to make the AC not apply until the item is ID'd? --celestian
                if bIsShield then
                    -- we only want the "bonus" value for ring/cloaks/robes
                    if bID then
                        nMainShieldTotal =
                            nMainShieldTotal + (DB.getValue(vNode, "ac", 0)) + (DB.getValue(vNode, "bonus", 0))
                    else
                        nMainShieldTotal =
                            nMainShieldTotal + (DB.getValue(vNode, "ac", 0)) + (DB.getValue(vNode, "bonus", 0))
                    end
                elseif bIsRingOrCloak then
                    if bID then
                        nMainShieldTotal = nMainShieldTotal + DB.getValue(vNode, "bonus", 0)
                    else
                        nMainShieldTotal = nMainShieldTotal + DB.getValue(vNode, "bonus", 0)
                    end
                elseif bIsArmor or bIsWarding then
                    if bID then
                        nMainArmorBase = DB.getValue(vNode, "ac", 0)
                    else
                        nMainArmorBase = DB.getValue(vNode, "ac", 0)
                    end
                    -- convert bonus from +bonus to -bonus to adjust AC down for decending AC
                    if bID then
                        nMainArmorTotal = nMainArmorTotal - (DB.getValue(vNode, "bonus", 0))
                    else
                        nMainArmorTotal = nMainArmorTotal - (DB.getValue(vNode, "bonus", 0))
                    end
                end
            end
        end
    end

    -- if (nMainArmorTotal == 0) and (nMainShieldTotal == 0) and hasTrait(nodeChar, TRAIT_NATURAL_ARMOR) then
    -- nMainArmorTotal = 3;
    -- end

    -- Debug.console("manager_char.lua","calcItemArmorClass","nMainArmorBase2",nMainArmorBase);
    -- Debug.console("manager_char.lua","calcItemArmorClass","nMainArmorTotal2",nMainArmorTotal);

    -- flip value for decending ac in nMainShieldTotal -celestian
    nMainShieldTotal = -(nMainShieldTotal)

    DB.setValue(nodeChar, "defenses.ac.base", "number", nMainArmorBase)
    DB.setValue(nodeChar, "defenses.ac.armor", "number", nMainArmorTotal)
    DB.setValue(nodeChar, "defenses.ac.shield", "number", nMainShieldTotal)

    --steal/dex not used here
    -- DB.setValue(nodeChar, "defenses.ac.dexbonus", "string", sMainDexBonus);
    -- DB.setValue(nodeChar, "defenses.ac.disstealth", "number", nMainStealthDis);

    -- add speed penalty for armor type around here? --celestian

    -- local bArmorSpeedPenalty = false;
    -- local nArmorSpeed = 0;
    -- if bArmorSpeedPenalty then
    -- nArmorSpeed = -10;
    -- end
    -- DB.setValue(nodeChar, "speed.armor", "number", nArmorSpeed);
    -- local nSpeedTotal = DB.getValue(nodeChar, "speed.base", 12) + nArmorSpeed + DB.getValue(nodeChar, "speed.misc", 0) + DB.getValue(nodeChar, "speed.temporary", 0);
    -- DB.setValue(nodeChar, "speed.total", "number", nSpeedTotal);
end

---
--- Power Management
---

-- if the item has powers configured place them into the action->powers
function addToPowerDB(nodeItem)
    --Debug.console("manager_char.lua","addToPowerDB","nodeItem",nodeItem);
    local bItemHasPowers = (DB.getChildCount(nodeItem, "powers") > 0)
    local bItemIdentified = (DB.getValue(nodeItem, "isidentified", 1) == 1)
    if not bItemHasPowers or not bItemIdentified then
        return
    end

    -- do nothing if power already exists.
    if doesPowerDBItemExist(nodeItem) ~= nil then
        return
    end

    local nodeChar = nodeItem.getChild("...")

    local nodePowers = nodeChar.createChild("powers")
    if not nodePowers then
        return
    end
    for _, nodePowerSource in pairs(DB.getChildren(nodeItem, "powers")) do
        local nodePowerNew = nodePowers.createChild()
        DB.copyNode(nodePowerSource, nodePowerNew)
        -- only set the description if the description doesn't exist.
        if (not DB.getValue(nodePowerNew, "description")) then
            DB.setValue(nodePowerNew, "description", "formattedtext", DB.getValue(nodeItem, "description", ""))
        end
        DB.setValue(nodePowerNew, "powersource", "string", nodePowerSource.getPath())
        --DB.setValue(nodePowerNew, "powersource", "string", "....inventorylist." .. nodeItem.getName() .. ".powers." .. nodePowerSource.getName());

        DB.setValue(nodePowerNew, "shortcut", "windowreference", "item", "....inventorylist." .. nodeItem.getName())
        DB.setValue(nodePowerNew, "locked", "number", 1) -- want this to start locked
    end
end

-- remove link to powers if the object is deleted.
function removeFromPowerDB(nodeItem)
    if not nodeItem then
        return false
    end
    local bItemHasPowers = (DB.getChildCount(nodeItem, "powers") > 0)
    if not bItemHasPowers then
        return
    end

    -- Check to see if any of the power nodes linked to this item node should be deleted
    -- make sure to remove all of them if more than one entry exists somehow...
    local sItemNode = nodeItem.getNodeName()
    local sItemNode2 = "....inventorylist." .. nodeItem.getName()
    local bFound = false
    for _, v in pairs(DB.getChildren(nodeItem, "...powers")) do
        local sClass, sRecord = DB.getValue(v, "shortcut", "", "")
        if sRecord == sItemNode or sRecord == sItemNode2 then
            bFound = true
            v.delete()
        end
    end

    return bFound
end

-- does this item already have it's powers listed?
function doesPowerDBItemExist(nodeItem)
    local nodeFound = nil
    -- Check to see if any of the power nodes linked to this item node should be deleted
    local sItemNode = nodeItem.getNodeName()
    local sItemNode2 = "....inventorylist." .. nodeItem.getName()
    local bFound = false
    for _, v in pairs(DB.getChildren(nodeItem, "...powers")) do
        local sClass, sRecord = DB.getValue(v, "shortcut", "", "")
        if sRecord == sItemNode or sRecord == sItemNode2 then
            nodeFound = v
            break
        end
    end

    return nodeFound
end

--
-- WEAPON MANAGEMENT
--

function removeFromWeaponDB(nodeItem)
    if not nodeItem then
        return false
    end

    -- Check to see if any of the weapon nodes linked to this item node should be deleted
    local sItemNode = nodeItem.getNodeName()
    local sItemNode2 = "....inventorylist." .. nodeItem.getName()
    local bFound = false
    for _, v in pairs(DB.getChildren(nodeItem, "...weaponlist")) do
        local sClass, sRecord = DB.getValue(v, "shortcut", "", "")
        if sRecord == sItemNode or sRecord == sItemNode2 then
            bFound = true
            v.delete()
        end
    end

    return bFound
end

function addToWeaponDB(nodeItem)
    local bItemHasWeapons = (DB.getChildCount(nodeItem, "weaponlist") > 0)
    -- Parameter validation
    if not ItemManager2.isWeapon(nodeItem) and not bItemHasWeapons then
        return
    end

    -- Get the weapon list we are going to add to
    local nodeChar = nodeItem.getChild("...")

    local nodeWeapons = nodeChar.createChild("weaponlist")
    if not nodeWeapons then
        return
    end

    -- Set new weapons as equipped
    DB.setValue(nodeItem, "carried", "number", 2)

    -- Determine identification
    local nItemID = 0
    if LibraryData.getIDState("item", nodeItem, true) then
        nItemID = 1
    end

    -- Grab some information from the source node to populate the new weapon entries
    local nBonus = 0
    if nItemID == 1 then
        nBonus = DB.getValue(nodeItem, "bonus", 0)
    end

    if (bItemHasWeapons) then
        for _, v in pairs(DB.getChildren(nodeItem, "weaponlist")) do
            local nodeWeapon = nodeWeapons.createChild()
            DB.copyNode(v, nodeWeapon)
            -- set various items specific to this item
            DB.setValue(nodeWeapon, "shortcut", "windowreference", "item", "....inventorylist." .. nodeItem.getName())
            --Debug.console("manager_char.lua","addToWeaponDB","nodeWeapon",nodeWeapon);
        end
    end
end

function onItemIDChanged(nodeItemID)
    local nodeItem = nodeItemID.getChild("..")
    local nodeChar = nodeItemID.getChild("....")

    local sPath = nodeItem.getPath()
    for _, vWeapon in pairs(DB.getChildren(nodeChar, "weaponlist")) do
        local _, sRecord = DB.getValue(vWeapon, "shortcut", "", "")
        if sRecord == sPath then
            checkWeaponIDChange(vWeapon)
        end
    end
end

function checkWeaponIDChange(nodeWeapon)
    local sClass, sRecord = DB.getValue(nodeWeapon, "shortcut", "", "")
    if sRecord == "" then
        return
    end
    if sClass == "" or (not sClass == "item") then
        return
    end
    local nodeItem = DB.findNode(sRecord)

    if not nodeItem then
        return
    end

    local bItemID = LibraryData.getIDState("item", DB.findNode(sRecord), true)
    local bWeaponID = (DB.getValue(nodeWeapon, "isidentified", 1) == 1)
    if bItemID == bWeaponID then
        return
    end

    -- if bItemID or Session.IsHost then
    -- DB.setValue(nodeWeapon, "attackbonus", "number", DB.getValue(nodeWeapon, "attackbonus", 0) + DB.getValue(nodeItem, "bonus", 0));
    -- local aDamageNodes = UtilityManager.getSortedTable(DB.getChildren(nodeWeapon, "damagelist"));
    -- if #aDamageNodes > 0 then
    -- DB.setValue(aDamageNodes[1], "bonus", "number", DB.getValue(aDamageNodes[1], "bonus", 0) + DB.getValue(nodeItem, "bonus", 0));
    -- end
    -- else
    -- DB.setValue(nodeWeapon, "attackbonus", "number", DB.getValue(nodeWeapon, "attackbonus", 0) - DB.getValue(nodeItem, "bonus", 0));
    -- local aDamageNodes = UtilityManager.getSortedTable(DB.getChildren(nodeWeapon, "damagelist"));
    -- if #aDamageNodes > 0 then
    -- DB.setValue(aDamageNodes[1], "bonus", "number", DB.getValue(aDamageNodes[1], "bonus", 0) - DB.getValue(nodeItem, "bonus", 0));
    -- end
    -- end

    if bItemID then
        DB.setValue(nodeWeapon, "isidentified", "number", 1)
    else
        DB.setValue(nodeWeapon, "isidentified", "number", 0)
    end
end

--
-- ACTIONS
--

-- Things to do on rest.
function rest(nodeChar, bLong)
    PowerManager.resetPowers(nodeChar, bLong)
    resetHealth(nodeChar, bLong)
    local nodeCT = CombatManager.getCTFromNode(nodeChar)
    DB.deleteChild(nodeCT, "targets") -- clear targets
    TokenManagerADND.clearAllTargetsWidgets()
    TokenManagerADND.resetIndicators(nodeChar, bLong)
end

function resetHealth(nodeChar, bLong)
    local bResetWounds = false
    local bResetTemp = false
    local bResetHitDice = false
    local bResetHalfHitDice = false
    local bResetQuarterHitDice = false

    local sOptHRHV = OptionsManager.getOption("HRHV")
    if sOptHRHV == "fast" then
        if bLong then
            bResetWounds = true
            bResetTemp = true
            bResetHitDice = true
        else
            bResetQuarterHitDice = true
        end
    elseif sOptHRHV == "slow" then
        if bLong then
            bResetTemp = true
            bResetHalfHitDice = true
        end
    else
        if bLong then
            bResetWounds = true
            bResetTemp = true
            bResetHalfHitDice = true
        end
    end

    -- Reset health fields and conditions
    if bResetWounds then
        -- in AD&D we dont just reset all health on a rest.
        --DB.setValue(nodeChar, "hp.wounds", "number", 0);
        --
        DB.setValue(nodeChar, "hp.deathsavesuccess", "number", 0)
        DB.setValue(nodeChar, "hp.deathsavefail", "number", 0)
    end
    if bResetTemp then
        DB.setValue(nodeChar, "hp.temporary", "number", 0)
    end

    -- Reset all hit dice
    if bResetHitDice then
        for _, vClass in pairs(DB.getChildren(nodeChar, "classes")) do
            DB.setValue(vClass, "hdused", "number", 0)
        end
    end

    -- Reset half or quarter of hit dice (assume biggest hit dice selected first)
    if bResetHalfHitDice or bResetQuarterHitDice then
        local nHDUsed, nHDTotal = getClassHDUsage(nodeChar)
        if nHDUsed > 0 then
            local nHDRecovery
            if bResetQuarterHitDice then
                nHDRecovery = math.max(math.floor(nHDTotal / 4), 1)
            else
                nHDRecovery = math.max(math.floor(nHDTotal / 2), 1)
            end
            if nHDRecovery >= nHDUsed then
                for _, vClass in pairs(DB.getChildren(nodeChar, "classes")) do
                    DB.setValue(vClass, "hdused", "number", 0)
                end
            else
                local nodeClassMax, nClassMaxHDSides, nClassMaxHDUsed
                while nHDRecovery > 0 do
                    nodeClassMax = nil
                    nClassMaxHDSides = 0
                    nClassMaxHDUsed = 0

                    for _, vClass in pairs(DB.getChildren(nodeChar, "classes")) do
                        local nClassHDUsed = DB.getValue(vClass, "hdused", 0)
                        if nClassHDUsed > 0 then
                            local aClassDice = DB.getValue(vClass, "hddie", {})
                            if #aClassDice > 0 then
                                local nClassHDSides = tonumber(aClassDice[1]:sub(2)) or 0
                                if nClassHDSides > 0 and nClassMaxHDSides < nClassHDSides then
                                    nodeClassMax = vClass
                                    nClassMaxHDSides = nClassHDSides
                                    nClassMaxHDUsed = nClassHDUsed
                                end
                            end
                        end
                    end

                    if nodeClassMax then
                        if nHDRecovery >= nClassMaxHDUsed then
                            DB.setValue(nodeClassMax, "hdused", "number", 0)
                            nHDRecovery = nHDRecovery - nClassMaxHDUsed
                        else
                            DB.setValue(nodeClassMax, "hdused", "number", nClassMaxHDUsed - nHDRecovery)
                            nHDRecovery = 0
                        end
                    else
                        break
                    end
                end
            end
        end
    end
end

--
-- CHARACTER SHEET DROPS
--

function addInfoDB(nodeChar, sClass, sRecord)
    -- Validate parameters
    if not nodeChar then
        return false
    end
    if sClass == "reference_background" then
        addBackgroundRef(nodeChar, sClass, sRecord)
    elseif sClass == "reference_backgroundfeature" then
        addClassFeatureDB(nodeChar, sClass, sRecord)
    elseif sClass == "reference_race" or sClass == "reference_subrace" then
        addRaceRef(nodeChar, sClass, sRecord)
    elseif sClass == "reference_class" then
        addClassRef(nodeChar, sClass, sRecord)
    elseif sClass == "reference_classproficiency" then
        addClassProficiencyDB(nodeChar, sClass, sRecord)
    elseif sClass == "reference_racialproficiency" then -- import racial profs
        addClassProficiencyDB(nodeChar, sClass, sRecord)
    elseif sClass == "reference_classability" or sClass == "reference_classfeature" then
        addClassFeatureDB(nodeChar, sClass, sRecord)
    elseif sClass == "reference_feat" then
        addFeatDB(nodeChar, sClass, sRecord)
    elseif sClass == "reference_skill" then
        addSkillRef(nodeChar, sClass, sRecord)
    elseif sClass == "reference_racialtrait" or sClass == "reference_subracialtrait" then
        addTraitDB(nodeChar, sClass, sRecord)
    elseif sClass == "ref_adventure" then
        addAdventureDB(nodeChar, sClass, sRecord)
    else
        return false
    end

    return true
end

function resolveRefNode(sRecord)
    local nodeSource = DB.findNode(sRecord)
    if not nodeSource then
        local sRecordSansModule = StringManager.split(sRecord, "@")[1]
        nodeSource = DB.findNode(sRecordSansModule .. "@*")
        if not nodeSource then
            outputUserMessage("char_error_missingrecord")
        end
    end
    return nodeSource
end

function addClassProficiencyDB(nodeChar, sClass, sRecord)
    local nodeSource = resolveRefNode(sRecord)
    if not nodeSource then
        return
    end

    --local sType = nodeSource.getName();
    -- added type to each prof
    local sType = DB.getValue(nodeSource, "type", "")

    --Debug.console("manager_char.lua","addClassProficiencyDB","nodeSource",nodeSource);

    -- Skill Proficiencies
    if sType == "skills" then
        addSkillRef(nodeChar, sClass, sRecord)
    else
        -- Armor, Weapon Proficiencies
        local sText = DB.getText(nodeSource, "name") -- get name name of the weapon prof
        addProficiencyDB(nodeChar, sType, sText, nodeSource)
    end

    return true
end

function onRaceAbilitySelect(aSelection, nodeChar)
    for _, sAbility in ipairs(aSelection) do
        local k = sAbility:lower()
        if StringManager.contains(DataCommon.abilities, k) then
            local sPath = "abilities." .. k .. ".base"
            DB.setValue(nodeChar, sPath, "number", DB.getValue(nodeChar, sPath, 9) + 1)
        end
    end
end

function addAbilityAdjustment(nodeChar, sAbility, nAdj, nAbilityMax)
    local k = sAbility:lower()
    if StringManager.contains(DataCommon.abilities, k) then
        local sPath = "abilities." .. k .. ".base"
        -- default to 9, that's what we default to everywhere for ability scores we dont know
        local nCurrent = DB.getValue(nodeChar, sPath, 9)
        local nNewScore = nCurrent + nAdj
        if nAbilityMax then
            nNewScore = math.max(math.min(nNewScore, nAbilityMax), nCurrent)
        end
        if nNewScore ~= nCurrent then
            DB.setValue(nodeChar, sPath, "number", nNewScore)
            --outputUserMessage("char_abilities_message_abilityadd", StringManager.capitalize(k), nNewScore - nCurrent, DB.getValue(nodeChar, "name", ""));
            local sMsg =
                string.format(
                Interface.getString("char_abilities_message_abilityadd"),
                StringManager.capitalize(k),
                nNewScore - nCurrent,
                DB.getValue(nodeChar, "name", "")
            )
            outputAdvancementLog(sMsg, nodeChar, DB.getPath(nodeChar, sPath), nCurrent)
        end
    end
end

function onClassSkillSelect(aSelection, rSkillAdd)
    -- For each selected skill, add it to the character
    for _, sSkill in ipairs(aSelection) do
        sSkill = StringManager.trim(sSkill)
        -- see if we can find a matching name of the skill in our records
        local nodeSource = UtilityManagerADND.findSkillRecord(sSkill)
        addSkillDB(rSkillAdd.nodeChar, sSkill, nodeSource)
    end
end

function addProficiencyDB(nodeChar, sType, sText, nodeSource)
    --Debug.console("manager_char.lua","addProficiencyDB","nodeChar",nodeChar);

    -- Get the list we are going to add to
    local nodeList = nodeChar.createChild("proficiencylist")
    if not nodeList then
        return nil
    end

    -- If proficiency is not none, then add it to the list
    if sText == "None" then
        return nil
    end

    -- Make sure this item does not already exist
    for _, vProf in pairs(nodeList.getChildren()) do
        if DB.getValue(vProf, "name", "") == sText then
            return vProf
        end
    end

    local nodeEntry = nodeList.createChild()
    local sName = DB.getValue(nodeSource, "name", "")
    DB.setValue(nodeEntry, "name", "string", sName)
    -- need these values --celestian
    if nodeSource then
        local sName = DB.getValue(nodeSource, "name", "")
        local sDescription = DB.getValue(nodeSource, "text", "")
        local nHitADJ = DB.getValue(nodeSource, "hitadj", 0)
        local nDMGADJ = DB.getValue(nodeSource, "dmgadj", 0)
        DB.setValue(nodeEntry, "hitadj", "number", nHitADJ)
        DB.setValue(nodeEntry, "dmgadj", "number", nDMGADJ)
        DB.setValue(nodeEntry, "text", "formattedtext", sDescription)
        DB.setValue(nodeEntry, "locked", "number", 1)
    end

    -- Announce
    --outputUserMessage("char_abilities_message_profadd", DB.getValue(nodeEntry, "name", ""), DB.getValue(nodeChar, "name", ""));

    local sMsg =
        string.format(
        Interface.getString("char_abilities_message_profadd"),
        DB.getValue(nodeEntry, "name", ""),
        DB.getValue(nodeChar, "name", "")
    )
    outputAdvancementLog(sMsg, nodeChar, nodeEntry.getPath())

    return nodeEntry
end

function addSkillDB(nodeChar, sSkill, nodeSource)
    -- Get the list we are going to add to
    local nodeList = nodeChar.createChild("skilllist")
    if not nodeList then
        return nil
    end
    -- Make sure this item does not already exist
    local nodeSkill = nil
    for _, vSkill in pairs(nodeList.getChildren()) do
        if DB.getValue(vSkill, "name", "") == sSkill then
            nodeSkill = vSkill
            break
        end
    end
    -- Add the item
    if not nodeSkill then
        if not nodeSource then
            outputUserMessage("char_abilities_message_skillmissing", sSkill)
        end
        nodeSkill = nodeList.createChild()
        DB.setValue(nodeSkill, "name", "string", sSkill)
        if nodeSource then
            -- this seems to make more sense --celestian
            DB.copyNode(nodeSource, nodeSkill)

        -- local sStat = DB.getValue(nodeSource, "stat", "");
        -- local nMod = DB.getValue(nodeSource, "adj_mod", 0);
        -- local nBaseCheck = DB.getValue(nodeSource, "base_check", 0);
        -- local sDesc = DB.getValue(nodeSource, "text", 0);
        -- DB.setValue(nodeSkill, "stat", "string",sStat);
        -- DB.setValue(nodeSkill, "adj_mod", "number",nMod);
        -- DB.setValue(nodeSkill, "base_check", "number",nBaseCheck);
        -- DB.setValue(nodeSkill,"text","formattedtext",sDesc);
        end
    end
    -- Announce
    --outputUserMessage("char_abilities_message_skilladd", DB.getValue(nodeSkill, "name", ""), DB.getValue(nodeChar, "name", ""));
    local sMsg =
        string.format(
        Interface.getString("char_abilities_message_skilladd"),
        DB.getValue(nodeSkill, "name", ""),
        DB.getValue(nodeChar, "name", "")
    )
    outputAdvancementLog(sMsg, nodeChar, nodeSkill.getPath())

    return nodeSkill
end

-- add a "Feature" to character
function addClassFeatureDB(nodeChar, sClass, sRecord, nodeClass)
    local nodeSource = resolveRefNode(sRecord)
    if not nodeSource then
        return
    end
    -- Debug.console("manager_char","addClassFeatureDB","nodeSource",nodeSource);

    -- Get the list we are going to add to
    local nodeList = nodeChar.createChild("featurelist")
    if not nodeList then
        return false
    end

    -- Get the class name
    local sClassName = DB.getValue(nodeSource, "...name", "")

    -- Make sure this item does not already exist
    local sOriginalName = DB.getValue(nodeSource, "name", "")
    local sOriginalNameLower = StringManager.trim(sOriginalName:lower())
    -- Debug.console("manager_char.lua","addClassFeatureDB","sOriginalNameLower",sOriginalNameLower)
    local sFeatureName = sOriginalName
    for _, v in pairs(nodeList.getChildren()) do
        if DB.getValue(v, "name", ""):lower() == sOriginalNameLower then
            return false
        end
    end

    -- Pull the feature level
    local nFeatureLevel = DB.getValue(nodeSource, "level", 0)

    -- Add the item
    local vNew = nodeList.createChild()
    DB.copyNode(nodeSource, vNew)
    DB.setValue(vNew, "name", "string", sFeatureName)
    DB.setValue(vNew, "source", "string", DB.getValue(nodeSource, "...name", ""))
    DB.setValue(vNew, "locked", "number", 1)

    -- Special handling
    -- parse out choices of profs

    if sOriginalNameLower:match("non%-weapon proficiency") then
        local sText = DB.getText(nodeSource, "text")
        local sPicks, sPickSkills = sText:match("Choose (%w+) from among ([^$%.]+)")
        -- Debug.console("manager_char.lua","addClassFeatureDB","sPicks-->",sPicks)
        -- Debug.console("manager_char.lua","addClassFeatureDB","sPickSkills-->",sPickSkills)
        if (sPicks and sPickSkills) then
            sPickSkills = sPickSkills:gsub(" and ", ",")
            sPickSkills = sPickSkills:gsub(" or ", ",")
            local aPickSkills = StringManager.split(sPickSkills, ",", true)
            nPicks = convertSingleNumberTextToNumber(sPicks)
            if nPicks > 0 then
                pickSkills(nodeChar, aPickSkills, nPicks)
            end
        end
    elseif sOriginalNameLower:match("weapon specialization") or sOriginalNameLower:match("weapon proficiency") then
        -- there is no reason to function for single entry, those can be added
        -- in skills tab. Only need to know if they get a "choose" type list
        local sText = DB.getText(nodeSource, "text")
        if (sText:match("Choose ")) then
            local sChoices, sWeapons = sText:match("Choose (%w+) from among ([^$%.]+)")
            if (sChoices and sWeapons) then
                local numChoices = convertSingleNumberTextToNumber(sChoices)
                sWeapons = sWeapons:gsub(" or ", ",") -- replace or's with commas
                sWeapons = sWeapons:gsub(" and ", ",") -- replace and's with commas
                sWeapons = sWeapons:gsub("%.", "") -- replace . with nothing
                local aWeapons = StringManager.split(sWeapons, ",", true)
                if sOriginalNameLower:match("weapon specialization") then -- set bSpec boolean true
                    pickWeaponProfs(nodeChar, aWeapons, numChoices, sText, true, 0)
                else
                    pickWeaponProfs(nodeChar, aWeapons, numChoices, sText, false, 0)
                end
            end
        end
    elseif sOriginalNameLower:match("experience penalty") then
        local sEXPPenaltyText = DB.getText(nodeSource, "text"):lower()
        local sExpCost = sEXPPenaltyText:match("additional experience cost: (%d+)%%")
        if not sExpCost then
            sExpCost = sEXPPenaltyText:match("experience penalty of (%d+)%%")
        end
        if sExpCost then
            local nEXPPenalty = DB.getValue(nodeChar, "exppenalty", 0)
            local nEXPCost = tonumber(sExpCost) or 0
            nEXPPenalty = nEXPPenalty + nEXPCost
            DB.setValue(nodeChar, "exppenalty", "number", nEXPPenalty)
        end
    end

    -- Announce
    --  outputUserMessage("char_abilities_message_featureadd", DB.getValue(vNew, "name", ""), DB.getValue(nodeChar, "name", ""));
    local sMsg =
        string.format(
        Interface.getString("char_abilities_message_featureadd"),
        DB.getValue(vNew, "name", ""),
        DB.getValue(nodeChar, "name", "")
    )
    outputAdvancementLog(sMsg, nodeChar, vNew.getPath())

    return true
end

-- Give the option to select a weapon proficiency
function pickWeaponProfs(nodeChar, aWeapons, nPicks, sText, bSpecialize, nProf)
    -- Display dialog to choose skill selection
    local rWeaponAdd = {nodeChar = nodeChar, sText = sText, bSpecialize = bSpecialize, nProf = nProf}
    --Debug.console("manager_char","pickWeaponProfs","rWeaponAdd",rWeaponAdd);
    local wSelect = Interface.openWindow("select_dialog", "")
    local sTitle = Interface.getString("char_build_title_selectskills")
    local sMessage = string.format(Interface.getString("char_build_message_selectskills"), nPicks)
    wSelect.requestSelection(sTitle, sMessage, aWeapons, CharManager.onWeaponProfSelect, rWeaponAdd, nPicks)
end

-- process a weapon selection
function onWeaponProfSelect(aSelection, rWeaponAdd)
    local nodeChar = rWeaponAdd.nodeChar
    local nodeList = nodeChar.createChild("proficiencylist")
    for _, sProfName in ipairs(aSelection) do
        -- for each selection add a node.
        -- I'd much rather hand this add off to addWeaponProficiencies() but that is not possible
        -- with how I do it right now --celestian
        local nodeEntry = nodeList.createChild()
        DB.setValue(nodeEntry, "name", "string", sProfName)
        DB.setValue(nodeEntry, "text", "formattedtext", rWeaponAdd.sText)
        DB.setValue(nodeEntry, "locked", "number", 1)
        -- default specialization is +1 hit, +2 damage
        if rWeaponAdd.bSpecialize then
            local nHit = 1
            local nDMG = 2
            -- -- if bow tweak damage?
            -- if sNameLower:match("bow") then
            -- end
            DB.setValue(nodeEntry, "hitadj", "number", nHit)
            DB.setValue(nodeEntry, "dmgadj", "number", nDMG)
        end
        local sNameLower = sProfName:lower()
        -- Announce
        --outputUserMessage("char_abilities_message_profadd", DB.getValue(nodeEntry, "name", ""), DB.getValue(nodeChar, "name", ""));
        local sMsg =
            string.format(
            Interface.getString("char_abilities_message_profadd"),
            DB.getValue(nodeEntry, "name", ""),
            DB.getValue(nodeChar, "name", "")
        )
        outputAdvancementLog(sMsg, nodeChar, nodeEntry.getPath())
    end
end

-- add trait (racial stuff)
function addTraitDB(nodeChar, sClass, sRecord)
    local nodeSource = resolveRefNode(sRecord)
    if not nodeSource then
        return
    end

    -- local sTraitType = CampaignDataManager2.sanitize(DB.getValue(nodeSource, "name", ""));
    -- if sTraitType == "" then
    -- sTraitType = nodeSource.getName();
    -- end
    local sTraitType = UtilityManagerADND.sanitizeTraitText(DB.getValue(nodeSource, "name", ""))

    --Debug.console("manager_char.lua","addTraitDB","sTraitType1",sTraitType);
    if sTraitType == "abilityscoreincrease" or sTraitType == "abilityscoreadjustment" then
        local bApplied = false
        local sAdjust = DB.getText(nodeSource, "text"):lower()

        if sAdjust:match("your ability scores each increase") then
            for _, v in pairs(DataCommon.abilities) do
                local sPath = "abilities." .. v .. ".base"
                DB.setValue(nodeChar, sPath, "number", DB.getValue(nodeChar, sPath, 9) + 1)
                bApplied = true
            end
        elseif sAdjust:match("the following abilites will increase by (%d+) ([^$%.]+)") then
            local aIncreases = {}
            local sIncrease, sAbilities = sAdjust:match("the following abilites will increase by (%d+) ([^$%.]+)")
            sAbilities = sAbilities:gsub(" and ", ",") -- replace and's with commas
            local aAbilities = StringManager.split(sAbilities, ",", true)
            if #aAbilities > 0 then
                local nIncrease = tonumber(sIncrease) or 0
                for _, sAbilityName in pairs(aAbilities) do
                    sAbilityName = StringManager.trim(sAbilityName)
                    aIncreases[sAbilityName] = nIncrease
                end
            end
            for k, v in pairs(aIncreases) do
                addAbilityAdjustment(nodeChar, k, v)
                bApplied = true
            end
        else
            local aIncreases = {}

            local n1, n2
            local a1, a2, sIncrease = sAdjust:match("your (%w+) and (%w+) scores increase by (%d+)")
            if a1 then
                local nIncrease = tonumber(sIncrease) or 0
                aIncreases[a1:lower()] = nIncrease
                aIncreases[a2:lower()] = nIncrease
            else
                for a1, sIncrease in sAdjust:gmatch("your (%w+) score increases by (%d+)") do
                    local nIncrease = tonumber(sIncrease) or 0
                    aIncreases[a1:lower()] = nIncrease
                end
                for a1, sDecrease in sAdjust:gmatch("your (%w+) score is reduced by (%d+)") do
                    local nDecrease = tonumber(sDecrease) or 0
                    aIncreases[a1:lower()] = nDecrease * -1
                end
            end

            for k, v in pairs(aIncreases) do
                addAbilityAdjustment(nodeChar, k, v)
                bApplied = true
            end

            if
                sAdjust:match("two other ability scores of your choice increase") or
                    sAdjust:match("two different ability scores of your choice increase")
             then
                local aAbilities = {}
                for _, v in ipairs(DataCommon.abilities) do
                    if not aIncreases[v] then
                        table.insert(aAbilities, StringManager.capitalize(v))
                    end
                end
                local wSelect = Interface.openWindow("select_dialog", "")
                local sTitle = Interface.getString("char_build_title_selectabilityincrease")
                local sMessage = string.format(Interface.getString("char_build_message_selectabilityincrease"), 2)
                wSelect.requestSelection(sTitle, sMessage, aAbilities, CharManager.onRaceAbilitySelect, nodeChar, 2)
            end
            if sAdjust:match("your (%w+) or (%w+) score increases by (%d+)") then
                local a1, a2 = sAdjust:match("your (%w+) or (%w+) score increases by (%d+)")
                local aAbilities = {}
                table.insert(aAbilities, StringManager.capitalize(a1))
                table.insert(aAbilities, StringManager.capitalize(a2))
                local wSelect = Interface.openWindow("select_dialog", "")
                local sTitle = Interface.getString("char_build_title_selectabilityincrease")
                local sMessage = string.format(Interface.getString("char_build_message_selectabilityincrease"), 1)
                wSelect.requestSelection(sTitle, sMessage, aAbilities, CharManager.onRaceAbilitySelect, nodeChar, 1)
            end
        end
        if not bApplied then
            return false
        end
    elseif sTraitType == "age" then
        return false
    elseif sTraitType == "alignment" then
        return false
    elseif sTraitType == "size" then
        local sSize = DB.getText(nodeSource, "text")
        sSize = sSize:match("[Yy]our size is (%w+)")
        if not sSize then
            sSize = "Medium"
        end
        DB.setValue(nodeChar, "size", "string", sSize)
    elseif sTraitType == "speed" or sTraitType == "movebase" then
        local sSpeed = DB.getText(nodeSource, "text")

        local sWalkSpeed = sSpeed:match("walking speed is (%d+) feet")
        if not sWalkSpeed then
            sWalkSpeed = sSpeed:match("land speed is (%d+) feet")
        end
        if not sWalkSpeed then
            sWalkSpeed = sSpeed:match("move base is (%d+)")
        end
        if sWalkSpeed then
            local nSpeed = tonumber(sWalkSpeed) or 12
            local nCurrentSpeed = DB.getValue(nodeChar, "speed.base", 12)
            DB.setValue(nodeChar, "speed.base", "number", nSpeed)
            DB.setValue(nodeChar, "speed.basemodenc", "number", 0)
            --outputUserMessage("char_abilities_message_basespeedset", nSpeed, DB.getValue(nodeChar, "name", ""));
            local sMsg =
                string.format(
                Interface.getString("char_abilities_message_basespeedset"),
                nSpeed,
                DB.getValue(nodeChar, "name", "")
            )
            outputAdvancementLog(sMsg, nodeChar, DB.getPath(nodeChar, "speed.base"), nCurrentSpeed)
            return true
        end

        local aSpecial = {}
        local bSpecialChanged = false
        local sSpecial = StringManager.trim(DB.getValue(nodeChar, "speed.special", ""))
        if sSpecial ~= "" then
            table.insert(aSpecial, sSpecial)
        end

        local sSwimSpeed = sSpeed:match("swimming speed of (%d+) feet")
        if sSwimSpeed then
            bSpecialChanged = true
            table.insert(aSpecial, "Swim " .. sSwimSpeed .. " ft.")
        end

        local sFlySpeed = sSpeed:match("flying speed of (%d+) feet")
        if sFlySpeed then
            bSpecialChanged = true
            table.insert(aSpecial, "Fly " .. sFlySpeed .. " ft.")
        end

        local sClimbSpeed = sSpeed:match("climbing speed of (%d+) feet")
        if sClimbSpeed then
            bSpecialChanged = true
            table.insert(aSpecial, "Climb " .. sClimbSpeed .. " ft.")
        end

        if bSpecialChanged then
            DB.setValue(nodeChar, "speed.special", "string", table.concat(aSpecial, ", "))
        end
    elseif sTraitType == "fleetoffoot" then
        local sFleetOfFoot = DB.getText(nodeSource, "text")

        local sWalkSpeedIncrease = sFleetOfFoot:match("walking speed increases to (%d+) feet")
        if sWalkSpeedIncrease then
            DB.setValue(nodeChar, "speed.base", "number", tonumber(sWalkSpeedIncrease))
        end
    elseif sTraitType:match("experiencepenalty") then
        local sEXPPenaltyText = DB.getText(nodeSource, "text"):lower()
        local sExpCost = sEXPPenaltyText:match("additional experience cost: (%d+)%%")
        if not sExpCost then
            sExpCost = sEXPPenaltyText:match("experience penalty of (%d+)%%")
        end
        if sExpCost then
            local nEXPPenalty = DB.getValue(nodeChar, "exppenalty", 0)
            local nEXPCost = tonumber(sExpCost) or 0
            nEXPPenalty = nEXPPenalty + nEXPCost
            DB.setValue(nodeChar, "exppenalty", "number", nEXPPenalty)
        end
    elseif sTraitType == "darkvision" or sTraitType == "infravision" or sTraitType == "ultravision" then
        local sSenses = DB.getValue(nodeChar, "senses", "")
        if sSenses ~= "" then
            sSenses = sSenses .. ", "
        end
        sSenses = sSenses .. DB.getValue(nodeSource, "name", "")

        local sText = DB.getText(nodeSource, "text")
        if sText then
            local sDist = sText:match("%d+")
            if sDist then
                sSenses = sSenses .. " " .. sDist
            end
        end

        DB.setValue(nodeChar, "senses", "string", sSenses)
    elseif sTraitType == "superiordarkvision" then
        local sSenses = DB.getValue(nodeChar, "senses", "")

        local sDist = nil
        local sText = DB.getText(nodeSource, "text")
        if sText then
            sDist = sText:match("%d+")
        end
        if not sDist then
            return false
        end

        -- Check for regular Darkvision
        local sTraitName = DB.getValue(nodeSource, "name", "")
        if sSenses:find("Darkvision (%d+)") then
            sSenses = sSenses:gsub("Darkvision (%d+)", sTraitName .. " " .. sDist)
        else
            if sSenses ~= "" then
                sSenses = sSenses .. ", "
            end
            sSenses = sSenses .. sTraitName .. " " .. sDist
        end

        DB.setValue(nodeChar, "senses", "string", sSenses)
    elseif sTraitType == "languages" then
        local bApplied = false
        local sText = DB.getText(nodeSource, "text")
        --local sLanguages = sText:match("You can speak, read, and write ([^.]+)");
        local sLanguages = sText:match("You can speak ([^$%.]+)")
        -- if not sLanguages then
        -- sLanguages = sText:match("You can read and write ([^.]+)");
        -- end
        if not sLanguages then
            return false
        end

        sLanguages = sLanguages:gsub(" and ", ",")
        sLanguages = sLanguages:gsub("one extra language of your choice", "Choice")
        sLanguages = sLanguages:gsub("one other language of your choice", "Choice")
        -- EXCEPTION - Kenku - Languages - Volo
        sLanguages = sLanguages:gsub(", but you.*$", "")
        for s in string.gmatch(sLanguages, "(%a[%a%s]+)%,?") do
            addLanguageDB(nodeChar, s)
            bApplied = true
        end
        return bApplied
    elseif sTraitType == "extralanguage" then
        --elseif sTraitType == "armorclass" or sTraitType == "ac" then
        -- do we want to set base armor class changes?
        addLanguageDB(nodeChar, "Choice")
        return true
    elseif sTraitType:match("baseac") or sTraitType:match("basearmorclass") then
        local sBaseAC = DB.getText(nodeSource, "text")
        -- This race has a base armor class of 10
        nBaseAC = sBaseAC:match("This race has a base armor class of (%d+)")
        nBaseAC = tonumber(nBaseAC) or 10
        if nBaseAC then
            if nBaseAC < -10 or nBaseAC > 10 then
                nBaseAC = 10
            end
            DB.setValue(nodeChar, "defenses.ac.base", "number", nBaseAC)
        end
    elseif sTraitType == "subrace" then
        return false
    end
    local sText = DB.getText(nodeSource, "text", "")

    -- if sTraitType == "stonecunning" then
    -- -- Note: Bypass due to false positive in skill proficiency detection
    -- else
    -- checkSkillProficiencies(nodeChar, sText);
    -- end

    -- Get the list we are going to add to
    local nodeList = nodeChar.createChild("traitlist")
    if not nodeList then
        return false
    end

    -- Add the item
    local vNew = nodeList.createChild()
    DB.copyNode(nodeSource, vNew)
    DB.setValue(vNew, "source", "string", DB.getValue(nodeSource, "...name", ""))
    DB.setValue(vNew, "locked", "number", 1)

    if sClass == "reference_racialtrait" then
        DB.setValue(vNew, "type", "string", "racial")
    elseif sClass == "reference_subracialtrait" then
        DB.setValue(vNew, "type", "string", "subracial")
    elseif sClass == "reference_backgroundtrait" then
        DB.setValue(vNew, "type", "string", "background")
    end

    -- Special handling
    local sNameLower = DB.getValue(nodeSource, "name", ""):lower()
    if sNameLower == TRAIT_DWARVEN_TOUGHNESS then
        applyDwarvenToughness(nodeChar, true)
    elseif sNameLower == TRAIT_NATURAL_ARMOR then
        calcItemArmorClass(nodeChar)
    elseif sNameLower == TRAIT_CATS_CLAWS then
        local aSpecial = {}
        local sSpecial = StringManager.trim(DB.getValue(nodeChar, "speed.special", ""))
        if sSpecial ~= "" then
            table.insert(aSpecial, sSpecial)
        end
        table.insert(aSpecial, "Climb 20 ft.")
        DB.setValue(nodeChar, "speed.special", "string", table.concat(aSpecial, ", "))
    end
    --  end

    -- Announce
    --outputUserMessage("char_abilities_message_traitadd", DB.getValue(nodeSource, "name", ""), DB.getValue(nodeChar, "name", ""));
    local sMsg =
        string.format(
        Interface.getString("char_abilities_message_traitadd"),
        DB.getValue(nodeSource, "name", ""),
        DB.getValue(nodeChar, "name", "")
    )
    outputAdvancementLog(sMsg, nodeChar, vNew.getPath())

    return true
end

function parseSkillsFromString(sSkills)
    local aSkills = {}
    sSkills = sSkills:gsub(" and ", "")
    sSkills = sSkills:gsub(" or ", "")
    local nPeriod = sSkills:match("%.()")
    if nPeriod then
        sSkills = sSkills:sub(1, nPeriod)
    end
    for sSkill in string.gmatch(sSkills, "(%a[%a%s]+)%,?") do
        local sTrim = StringManager.trim(sSkill)
        table.insert(aSkills, sTrim)
    end
    return aSkills
end

-- pick skills from list
function pickSkills(nodeChar, aSkills, nPicks, nProf)
    -- Debug.console("manager_char.lua","pickSkills","aSkills",aSkills)
    -- Debug.console("manager_char.lua","pickSkills","nPicks",nPicks)
    -- Display dialog to choose skill selection
    local rSkillAdd = {nodeChar = nodeChar, nProf = nProf}
    local wSelect = Interface.openWindow("select_dialog", "")
    -- Debug.console("manager_char.lua","pickSkills","wSelect",wSelect)

    local sTitle = Interface.getString("char_build_title_selectskills")
    -- Debug.console("manager_char.lua","pickSkills","sTitle",sTitle)
    local sMessage = string.format(Interface.getString("char_build_message_selectskills"), nPicks)
    wSelect.requestSelection(sTitle, sMessage, aSkills, CharManager.onClassSkillSelect, rSkillAdd, nPicks)
    -- Debug.console("manager_char.lua","pickSkills","wSelect2",wSelect)
end

function addLanguageDB(nodeChar, sLanguage)
    -- Get the list we are going to add to
    local nodeList = nodeChar.createChild("languagelist")
    if not nodeList then
        return false
    end

    -- Make sure this item does not already exist
    if sLanguage ~= "Choice" then
        for _, v in pairs(nodeList.getChildren()) do
            if DB.getValue(v, "name", "") == sLanguage then
                return false
            end
        end
    end

    -- Add the item
    local vNew = nodeList.createChild()
    DB.setValue(vNew, "name", "string", sLanguage)

    -- Announce
    --outputUserMessage("char_abilities_message_languageadd", DB.getValue(vNew, "name", ""), DB.getValue(nodeChar, "name", ""));
    local sMsg =
        string.format(
        Interface.getString("char_abilities_message_languageadd"),
        DB.getValue(vNew, "name", ""),
        DB.getValue(nodeChar, "name", "")
    )
    outputAdvancementLog(sMsg, nodeChar, vNew.getPath())

    return true
end

function addBackgroundRef(nodeChar, sClass, sRecord)
    local nodeSource = resolveRefNode(sRecord)
    if not nodeSource then
        return
    end

    -- Notify
    --outputUserMessage("char_abilities_message_backgroundadd", DB.getValue(nodeSource, "name", ""), DB.getValue(nodeChar, "name", ""));
    local sMsg =
        string.format(
        Interface.getString("char_abilities_message_backgroundadd"),
        DB.getValue(nodeSource, "name", ""),
        DB.getValue(nodeChar, "name", "")
    )
    outputAdvancementLog(sMsg, nodeChar)

    -- Add the name and link to the main character sheet
    DB.setValue(nodeChar, "background", "string", DB.getValue(nodeSource, "name", ""))
    DB.setValue(nodeChar, "backgroundlink", "windowreference", sClass, nodeSource.getNodeName())

    for _, v in pairs(DB.getChildren(nodeSource, "features")) do
        addClassFeatureDB(nodeChar, "reference_backgroundfeature", v.getPath())
    end

    checkSkillsNodeToAdd(nodeChar, nodeSource)

    -- local sTools = DB.getValue(nodeSource, "tool", "");
    -- if sTools ~= "" and sTools ~= "None" then
    -- addProficiencyDB(nodeChar, "tools", sTools, nodeSource);
    -- end

    local sLanguages = DB.getValue(nodeSource, "languages", "")
    if sLanguages ~= "" and sLanguages ~= "None" then
        addLanguageDB(nodeChar, sLanguages)
    end

    addAttackAbilities(nodeSource, nodeChar)
    addSkillAbilities(nodeSource, nodeChar)
    addPowerAbilities(nodeSource, nodeChar)
    addProficiencySlots(nodeSource, nodeChar)
    addWeaponProficiencies(nodeSource, nodeChar, "reference_backgroundproficiency")
    addEffectFeature(nodeSource.getChild("effectlist"), nodeChar)
end

-- this checks the "skill" field on the nodeSource record and if it exists process.
function checkSkillsNodeToAdd(nodeChar, nodeSource)
    local sSkills = DB.getValue(nodeSource, "skill", "")
    if sSkills ~= "" and sSkills ~= "None" then
        local nPicks = 0
        local aPickSkills = {}
        if sSkills:match("Choose %w+ from among ") then
            local sPicks, sPickSkills = sSkills:match("Choose (%w+) from among (.*)")
            sPickSkills = sPickSkills:gsub(" and ", ",")
            sPickSkills = sPickSkills:gsub(" or ", ",")

            sSkills = ""
            nPicks = convertSingleNumberTextToNumber(sPicks)

            for sSkill in string.gmatch(sPickSkills, "(%a[%a%s]+)%,?") do
                local sTrim = StringManager.trim(sSkill)
                table.insert(aPickSkills, sTrim)
            end
        elseif sSkills:match("plus %w+ from among ") then
            local sPicks, sPickSkills = sSkills:match("plus (%w+) from among (.*)")
            sPickSkills = sPickSkills:gsub(" and ", ",")
            sPickSkills = sPickSkills:gsub(" or ", ",")

            sPickSkills = sPickSkills:gsub(", as appropriate for your order", "")

            sSkills = sSkills:gsub("plus one from among (.*)", "")
            nPicks = convertSingleNumberTextToNumber(sPicks)

            nPicks = 1
            for sSkill in string.gmatch(sPickSkills, "(%a[%a%s]+)%,?") do
                local sTrim = StringManager.trim(sSkill)
                if sTrim ~= "" then
                    table.insert(aPickSkills, sTrim)
                end
            end
        elseif sSkills:match("plus your choice of one from among") then
            local sPickSkills = sSkills:match("plus your choice of one from among (.*)")
            sPickSkills = sPickSkills:gsub(" and ", ",")
            sPickSkills = sPickSkills:gsub(" or ", ",")

            sSkills = sSkills:gsub("plus your choice of one from among (.*)", "")

            nPicks = 1
            for sSkill in string.gmatch(sPickSkills, "(%a[%a%s]+)%,?") do
                local sTrim = StringManager.trim(sSkill)
                if sTrim ~= "" then
                    table.insert(aPickSkills, sTrim)
                end
            end
        end

        if nPicks > 0 then
            pickSkills(nodeChar, aPickSkills, nPicks)
        end
    end
end

-- add weapon profs
function addWeaponProficiencies(nodeSource, nodeChar, sClass)
    -- Add proficiencies
    for _, v in pairs(DB.getChildren(nodeSource, "proficiencies")) do
        addClassProficiencyDB(nodeChar, sClass, v.getPath())
    end
end

function addRaceRef(nodeChar, sClass, sRecord)
    local nodeSource = resolveRefNode(sRecord)
    if not nodeSource then
        return
    end

    if sClass == "reference_race" then
        local aTable = {}
        aTable["char"] = nodeChar
        aTable["class"] = sClass
        aTable["record"] = nodeSource

        aTable["suboptions"] = {}
        local sRaceLower = DB.getValue(nodeSource, "name", ""):lower()
        local aMappings = LibraryData.getMappings("race")
        for _, vMapping in ipairs(aMappings) do
            for _, vRace in pairs(DB.getChildrenGlobal(vMapping)) do
                if sRaceLower == StringManager.trim(DB.getValue(vRace, "name", "")):lower() then
                    for _, vSubRace in pairs(DB.getChildren(vRace, "subraces")) do
                        table.insert(
                            aTable["suboptions"],
                            {
                                text = DB.getValue(vSubRace, "name", ""),
                                linkclass = "reference_subrace",
                                linkrecord = vSubRace.getPath()
                            }
                        )
                    end
                end
            end
        end

        if #(aTable["suboptions"]) == 0 then
            addRaceSelect(nil, aTable)
        elseif #(aTable["suboptions"]) == 1 then
            addRaceSelect(aTable["suboptions"], aTable)
        else
            -- Display dialog to choose subrace
            local wSelect = Interface.openWindow("select_dialog", "")
            local sTitle = Interface.getString("char_build_title_selectsubrace")
            local sMessage =
                string.format(
                Interface.getString("char_build_message_selectsubrace"),
                DB.getValue(nodeSource, "name", ""),
                1
            )
            wSelect.requestSelection(sTitle, sMessage, aTable["suboptions"], addRaceSelect, aTable)
        end
    else
        local sSubRaceName = DB.getValue(nodeSource, "name", "")

        local aTable = {}
        aTable["char"] = nodeChar
        aTable["class"] = "reference_race"
        aTable["record"] = nodeSource.getChild("...")
        aTable["suboptions"] = {
            {text = DB.getValue(nodeSource, "name", ""), linkclass = "reference_subrace", linkrecord = sRecord}
        }

        addRaceSelect(aTable["suboptions"], aTable)
    end
    checkSkillsNodeToAdd(nodeChar, nodeSource)
end

function addRaceSelect(aSelection, aTable)
    -- If subraces available, make sure that exactly one is selected
    if aSelection then
        if #aSelection ~= 1 then
            outputUserMessage("char_error_addsubrace")
            return
        end
    end

    local nodeChar = aTable["char"]
    local nodeSource = aTable["record"]

    -- Determine race to display on sheet and in notifications
    local sRace = DB.getValue(nodeSource, "name", "")
    local sSubRace = nil
    if aSelection then
        if type(aSelection[1]) == "table" then
            sSubRace = aSelection[1].text
        else
            sSubRace = aSelection[1]
        end
        if sSubRace:match(sRace) then
            sRace = sSubRace
        else
            sRace = sRace .. " (" .. sSubRace .. ")"
        end
    end

    -- Notify

    -- Add the name and link to the main character sheet
    DB.setValue(nodeChar, "race", "string", sRace)
    DB.setValue(nodeChar, "racelink", "windowreference", aTable["class"], nodeSource.getNodeName())

    outputAdvancementLog("=== Adding Race " .. sRace .. " ===", nodeChar)

    --outputUserMessage("char_abilities_message_raceadd", sRace, DB.getValue(nodeChar, "name", ""));
    local sMsg =
        string.format(Interface.getString("char_abilities_message_raceadd"), sRace, DB.getValue(nodeChar, "name", ""))
    outputAdvancementLog(sMsg, nodeChar, DB.getPath(nodeChar, "race"), "")

    for _, v in pairs(DB.getChildren(nodeSource, "traits")) do
        addTraitDB(nodeChar, "reference_racialtrait", v.getPath())
    end

    -- for _,v in pairs(DB.getChildren(nodeSource, "proficiencies")) do
    -- addClassProficiencyDB(nodeChar, "reference_racialproficiency", v.getPath());
    -- end
    addWeaponProficiencies(nodeSource, nodeChar, "reference_racialproficiency")

    for _, v in pairs(DB.getChildren(nodeSource, "nonweaponprof")) do
        addClassProficiencyDB(nodeChar, "reference_racialproficiency", v.getPath())
    end

    if sSubRace then
        for _, vSubRace in ipairs(aTable["suboptions"]) do
            if sSubRace == vSubRace.text then
                for _, v in pairs(DB.getChildren(DB.getPath(vSubRace.linkrecord, "traits"))) do
                    addTraitDB(nodeChar, "reference_subracialtrait", v.getPath())
                end
                break
            end
        end
    end
    -- effects
    local nodeEffects = nodeSource.getChild("effectlist")
    addEffectFeature(nodeEffects, nodeChar)

    outputAdvancementLog("___ COMPLETED Race Add ___", nodeChar)
end

function addClassRef(nodeChar, sClass, sRecord)
    local nodeSource = resolveRefNode(sRecord)
    if not nodeSource then
        return
    end

    -- Translate Hit Die
    local bHDFound = false
    local nHDMult = 1
    local nHDSides = 6
    local sHD = DB.getText(nodeSource, "hp.hitdice.text")
    if sHD then
        local sMult, sSides = sHD:match("(%d)d(%d+)")
        if sMult and sSides then
            nHDMult = tonumber(sMult)
            nHDSides = tonumber(sSides)
            bHDFound = true
        end
    end

    -- Get the list we are going to add to
    local nodeList = nodeChar.createChild("classes")
    if not nodeList then
        return
    end
    -- Check to see if the character already has this class
    local sRecordSansModule = StringManager.split(sRecord, "@")[1]
    local nodeClass = nil
    local sClassName = DB.getValue(nodeSource, "name", "")
    local sClassNameLower = StringManager.trim(sClassName):lower()
    for _, v in pairs(nodeList.getChildren()) do
        local sExistingClassName = StringManager.trim(DB.getValue(v, "name", "")):lower()
        if sExistingClassName ~= "" and (sExistingClassName == sClassNameLower) then
            nodeClass = v
            break
        end
    end

    -- If class already exists, then add a level; otherwise, create a new class entry
    local nLevel = 1
    local bExistingClass = false
    if nodeClass then
        bExistingClass = true
        nLevel = DB.getValue(nodeClass, "level", 1) + 1
    else
        nodeClass = nodeList.createChild()
    end

    if not bExistingClass then
        -- Add proficiencies
        addWeaponProficiencies(nodeSource, nodeChar, "reference_classproficiency")
        for _, v in pairs(DB.getChildren(nodeSource, "nonweaponprof")) do
            -- these are skills
            DB.setValue(v, "type", "string", "skills")
            addClassProficiencyDB(nodeChar, "reference_classproficiency", v.getPath())
        end
    end

    local nCasterLevel = nLevel
    local nPactMagicLevel = nLevel

    -- Any way you get here, overwrite or set the class reference link with the most current
    DB.setValue(nodeClass, "shortcut", "windowreference", sClass, sRecord)

    -- Add basic class information
    DB.setValue(nodeClass, "level", "number", nLevel)
    if not bExistingClass then
        DB.setValue(nodeClass, "name", "string", sClassName)
        DB.setValue(nodeClass, "classactive", "number", 1)
    end

    -- Calculate total level
    local nTotalLevel = 0
    for _, vClass in pairs(nodeList.getChildren()) do
        nTotalLevel = nTotalLevel + DB.getValue(vClass, "level", 0)
    end

    -- this will make sure penalty is at least -6. If multiclass/dual class the class
    -- with the least penalty will be used.
    local nCharWeaponPenalty = DB.getValue(nodeChar, "proficiencies.weapon.penalty", -10)
    local nClassWeaponPenalty = DB.getValue(nodeSource, "weapon_penalty", -6)
    if (nClassWeaponPenalty > nCharWeaponPenalty or (nCharWeaponPenalty == 0)) then
        DB.setValue(nodeChar, "proficiencies.weapon.penalty", "number", nClassWeaponPenalty)
        --ChatManager.SystemMessage("Weapon non-proficiency penalty set to " .. nClassWeaponPenalty);
        outputAdvancementLog(
            "Weapon non-proficiency penalty set to " .. nClassWeaponPenalty,
            nodeChar,
            DB.getPath(nodeChar, "proficiencies.weapon.penalty"),
            nCharWeaponPenalty
        )
    end
    -- end weapon prof penalty

    -- get "advancement" fields, look for matching level and process.
    local bHadAdvancement = false
    for _, nodeAdvance in pairs(DB.getChildren(nodeSource, "advancement")) do
        --addClassProficiencyDB(nodeChar, "reference_classproficiency", v.getPath());
        local nAdvanceLevel = DB.getValue(nodeAdvance, "level", 0)
        if (nAdvanceLevel == nLevel) then
            addAdvancement(nodeChar, nodeAdvance, nodeClass, nodeSource)
            bHadAdvancement = true
            break
        end
    end

    -- do best effort to configure class w/o advancement --celestian
    -- this section should probably be removed
    -- if not bHadAdvancement then
    -- if not bExistingClass then
    -- local aDice = {};
    -- for i = 1, nHDMult do
    -- table.insert(aDice, "d" .. nHDSides);
    -- end
    -- DB.setValue(nodeClass, "hddie", "dice", aDice);
    -- end

    -- -- we don't need this since we added advancement
    -- if not bHDFound then
    -- ChatManager.SystemMessage(Interface.getString("char_error_addclasshd"));
    -- end
    -- -- Add hit points based on level added
    -- local nHP = DB.getValue(nodeChar, "hp.base", 0);
    -- local nConBonus = tonumber(DB.getValue(nodeChar, "abilities.constitution.hitpointadj", 0));
    -- if type(nConBonus) ~= "number" then
    -- nConBonus = 0;
    -- end

    -- if nTotalLevel == 1 then
    -- local nAddHP = (nHDMult * nHDSides);
    -- nHP = nHP + nAddHP + nConBonus;
    -- outputUserMessage("char_abilities_message_hpaddmax", DB.getValue(nodeSource, "name", ""), " (" .. nAddHP .. "+" .. nConBonus .. ")");
    -- else
    -- -- for now we're going to manually roll hp. We don't have charts with the varying HD
    -- outputUserMessage("char_abilities_message_hpaddmax", DB.getValue(nodeChar, "name", ""),DB.getValue(nodeSource, "name", ""));
    -- -- this just sets it's to what it was for now till we get tables of exp/hd if we
    -- -- we ever get it. Let them manually apply it for now --celestian
    -- nHP = DB.getValue(nodeChar, "hp.base", 0);
    -- end
    -- DB.setValue(nodeChar, "hp.base", "number", nHP);
    -- end
    -- ^^^ this section should probably be removed

    -- Notify
    --outputUserMessage("char_abilities_message_classadd", DB.getValue(nodeSource, "name", ""), DB.getValue(nodeChar, "name", ""));
    local sMsg =
        string.format(
        Interface.getString("char_abilities_message_classadd"),
        DB.getValue(nodeSource, "name", ""),
        DB.getValue(nodeChar, "name", "")
    )
    outputAdvancementLog(sMsg, nodeChar)

    -- Determine whether a specialization is added this level
    local nodeSpecializationFeature = nil
    local aOptions = {}
    for _, v in pairs(DB.getChildren(nodeSource, "features")) do
        if (DB.getValue(v, "level", 0) == nLevel) and (DB.getValue(v, "specializationchoice", 0) == 1) then
            nodeSpecializationFeature = v
            for _, v in pairs(DB.getChildrenGlobal(nodeSource, "abilities")) do
                table.insert(
                    aOptions,
                    {text = DB.getValue(v, "name", ""), linkclass = "reference_classability", linkrecord = v.getPath()}
                )
            end
            break
        end
    end

    -- Add features, with customization based on whether specialization is added this level
    local rClassAdd = {
        nodeChar = nodeChar,
        nodeSource = nodeSource,
        nLevel = nLevel,
        nodeClass = nodeClass,
        nCasterLevel = nCasterLevel,
        nPactMagicLevel = nPactMagicLevel
    }

    if #aOptions == 0 then
        addClassFeatureHelper(nil, rClassAdd)
    elseif #aOptions == 1 then
        addClassFeatureHelper({aOptions[1].text}, rClassAdd)
    else
        -- Display dialog to choose specialization
        local wSelect = Interface.openWindow("select_dialog", "")
        local sTitle = Interface.getString("char_build_title_selectspecialization")
        local sMessage =
            string.format(
            Interface.getString("char_build_message_selectspecialization"),
            DB.getValue(nodeSpecializationFeature, "name", ""),
            1
        )
        wSelect.requestSelection(sTitle, sMessage, aOptions, addClassFeatureHelper, rClassAdd)
    end

    outputAdvancementLog("___ COMPLETED " .. sClassName .. " to level " .. nLevel .. " ___", nodeChar)
end

-- process hp/spellslots/saves/thaco/weaponprof and nonweaponprof slots
function addAdvancement(nodeChar, nodeAdvance, nodeClass, nodeClassSource)
    local sClassName = DB.getValue(nodeClass, "name", "")
    local sClassNameLower = sClassName:lower()
    local nLevel = DB.getValue(nodeClass, "level", 0)

    outputAdvancementLog("=== Advancing " .. sClassName .. " to level " .. nLevel .. " ===", nodeChar)

    -- class settings
    -- exp needed for next level
    local nEXPNeeded = DB.getValue(nodeAdvance, "expneeded", 0)
    DB.setValue(nodeClass, "expneeded", "number", nEXPNeeded)

    -- character settings
    -- get thaco from nodeAdvance or use thaco that exists already if not
    -- thaco
    local nTHACO = DB.getValue(nodeAdvance, "thaco", 0)
    local nodeCombat = nodeChar.createChild("combat") -- make sure these exist
    local nodeTHACO = nodeCombat.createChild("thaco") -- make sure these exist
    local nodeCharMATRIX = nodeCombat.createChild("matrix") -- make sure these exist

    local nCurrentTHACO = DB.getValue(nodeChar, "combat.thaco.score", 20)
    if (nTHACO ~= 0 and nTHACO < nCurrentTHACO) or (nTHACO == 0 and nCurrentTHACO == 1) then
        DB.setValue(nodeChar, "combat.thaco.score", "number", nTHACO)
        --ChatManager.SystemMessage("THACO updated to new value of " .. nTHACO);
        outputAdvancementLog(
            "THACO updated to new value of " .. nTHACO,
            nodeChar,
            DB.getPath(nodeChar, "combat.thaco.score"),
            nCurrentTHACO
        )
    end
    -- setup 1e matrix 10 to -10
    if (DataCommonADND.coreVersion == "1e") then
        for i = 10, -10, -1 do
            local sCurrentTHAC = "thac" .. i
            local nCurrentTHAC = DB.getValue(nodeCharMATRIX, sCurrentTHAC, 100)
            local nNewTHAC = DB.getValue(nodeAdvance, "combat.matrix." .. sCurrentTHAC)
            -- only match of new value and new value != 0 as long as current nTHAC == 1.
            if (not nNewTHAC) or (nNewTHAC < nCurrentTHAC) and (nNewTHAC ~= 0 or nCurrentTHAC == 1) then
                if not nNewTHAC then
                    nNewTHAC = 20
                end
                --ChatManager.SystemMessage(string.upper(sCurrentTHAC) .. " updated from ".. nCurrentTHAC .. " to new value of " .. nNewTHAC);
                outputAdvancementLog(
                    string.upper(sCurrentTHAC) .. " updated from " .. nCurrentTHAC .. " to new value of " .. nNewTHAC,
                    nodeChar,
                    DB.getPath(nodeCharMATRIX, sCurrentTHAC),
                    nCurrentTHAC
                )
                DB.setValue(nodeCharMATRIX, sCurrentTHAC, "number", nNewTHAC)
            end
        end
    end
    -- setup becmi matrix 19 to -20
    if (DataCommonADND.coreVersion == "becmi") then
        for i = 19, -20, -1 do
            local sCurrentTHAC = "thac" .. i
            local nCurrentTHAC = DB.getValue(nodeCharMATRIX, sCurrentTHAC, 100)
            local nNewTHAC = DB.getValue(nodeAdvance, "combat.matrix." .. sCurrentTHAC)
            -- only match of new value and new value != 0 as long as current nTHAC == 1.
            if (not nNewTHAC) or (nNewTHAC < nCurrentTHAC) and (nNewTHAC ~= 0 or nCurrentTHAC == 1) then
                if not nNewTHAC then
                    nNewTHAC = 20
                end
                --ChatManager.SystemMessage(string.upper(sCurrentTHAC) .. " updated from ".. nCurrentTHAC .. " to new value of " .. nNewTHAC);
                outputAdvancementLog(
                    string.upper(sCurrentTHAC) .. " updated from " .. nCurrentTHAC .. " to new value of " .. nNewTHAC,
                    nodeChar,
                    DB.getPath(nodeCharMATRIX, sCurrentTHAC),
                    nCurrentTHAC
                )
                DB.setValue(nodeCharMATRIX, sCurrentTHAC, "number", nNewTHAC)
            end
        end
    end

    --profs
    -- get prof advancement rates, if not set, get defaults from the class itself
    local nCharWeaponsCurrent = DB.getValue(nodeChar, "proficiencies.weapon.max", 0)
    local nCharNonWeaponsCurrent = DB.getValue(nodeChar, "proficiencies.nonweapon.max", 0)
    local nCharWeapons = DB.getValue(nodeChar, "proficiencies.weapon.max", 0)
    local nCharNonWeapons = DB.getValue(nodeChar, "proficiencies.nonweapon.max", 0)

    if nLevel == 1 then
        -- if level 1 and has more than 1 class we reset the profs to whatever is best.
        -- this will save rate for when leveling up
        local _, _ = getBestProficiencyRate(nodeChar, nodeClass, nodeClassSource)
        -- get initial prof rate
        local nWeapons, nNonWeapons = getBestProficiencyInitial(nodeChar, nodeClass, nodeClassSource)
        if getActiveClassCount(nodeChar) > 1 then
            nCharWeapons = nWeapons
            nCharNonWeapons = nNonWeapons
            --ChatManager.SystemMessage("Recalculating initial proficiencies for multi-classing.");
            outputAdvancementLog("Recalculating initial proficiencies for multi-classing.", nodeChar)
        else -- dual class or single classed
            nCharWeapons = nCharWeapons + nWeapons
            nCharNonWeapons = nCharNonWeapons + nNonWeapons
        end
        DB.setValue(nodeChar, "proficiencies.weapon.max", "number", nCharWeapons)
        DB.setValue(nodeChar, "proficiencies.nonweapon.max", "number", nCharNonWeapons)
        --ChatManager.SystemMessage("Initial weapon proficiency slot(s): " .. nCharWeapons);
        --ChatManager.SystemMessage("Initial non-weapon proficiency slot(s): " .. nCharNonWeapons);
        outputAdvancementLog(
            "Initial weapon proficiency slot(s): " .. nCharWeapons,
            nodeChar,
            DB.getPath(nodeChar, "proficiencies.weapon.max"),
            nCharWeaponsCurrent
        )
        outputAdvancementLog(
            "Initial non-weapon proficiency slot(s): " .. nCharNonWeapons,
            nodeChar,
            DB.getPath(nodeChar, "proficiencies.nonweapon.max"),
            nCharNonWeaponsCurrent
        )
    end

    -- if above level 1 we check to add weapon/non-weapon profs at given
    if nLevel > 1 then
        local nMaxActiveLevel, oMaxClass = getActiveClassMaxLevel(nodeChar)
        Debug.console("getActiveClassMaxLevel ", DB.getValue(oMaxClass, "name"), oMaxClass, nMaxActiveLevel)
        local nWeaponProfRate, nNonWeaponProfRate = getBestProficiencyRate(nodeChar, nodeClass, nodeClassSource)
        if (oMaxClass == nodeClass) then
            if (nMaxActiveLevel) % nWeaponProfRate == 0 then
                nCharWeapons = nCharWeapons + 1
                DB.setValue(nodeChar, "proficiencies.weapon.max", "number", nCharWeapons)
                --ChatManager.SystemMessage("Gained weapon a proficiency slot for leveling.");
                outputAdvancementLog(
                    "Gained weapon a proficiency slot for leveling.",
                    nodeChar,
                    DB.getPath(nodeChar, "proficiencies.weapon.max"),
                    nCharWeaponsCurrent
                )
            end
            if (nMaxActiveLevel) % nNonWeaponProfRate == 0 then
                nCharNonWeapons = nCharNonWeapons + 1
                DB.setValue(nodeChar, "proficiencies.nonweapon.max", "number", nCharNonWeapons)
                --ChatManager.SystemMessage("Gained non-weapon a proficiency slot for leveling.");
                outputAdvancementLog(
                    "Gained non-weapon a proficiency slot for leveling.",
                    nodeChar,
                    DB.getPath(nodeChar, "proficiencies.nonweapon.max"),
                    nCharNonWeaponsCurrent
                )
            end
        end
    --Debug.console("","manager_char.lua","nLevel-1",(nLevel-1));
    --Debug.console("","manager_char.lua","(nLevel-1) % nWeaponProfRate",(nLevel-1) % nWeaponProfRate);
    end

    addProficiencySlots(nodeAdvance, nodeChar)

    --saves
    local bDualClassOverHump = (hasInActiveClass(nodeChar) and getInActiveClassMaxLevel(nodeChar) < nLevel)
    local nodeAdvanceSaves = nodeAdvance.getChild("saves")
    if nodeAdvanceSaves then
        local nodeCharSaves = nodeChar.getChild("saves")
        if (not nodeCharSaves) then
            nodeCharSaves = nodeChar.createChild("saves")
            for i = 1, #DataCommon.saves do
                local node = nodeCharSaves.createChild(i)
            end
        end
        for i = 1, #DataCommon.saves do
            local sPath = "saves." .. DataCommon.saves[i] .. ".base"
            local nValue = DB.getValue(nodeAdvance, sPath, 0)
            if (nValue ~= 0) then
                local nCurrentValue = DB.getValue(nodeChar, sPath, 20)
                -- use lower class value regardless for dual class?
                --              if (hasInActiveClass(nodeChar) and not bDualClassOverHump) then
                --                  DB.setValue(nodeChar,sPath,"number",nValue);
                --              elseif
                if (nCurrentValue > nValue) then
                    -- set value
                    DB.setValue(nodeChar, sPath, "number", nValue)
                    outputAdvancementLog(
                        "Save for " .. DataCommon.saves[i] .. " improved to " .. nValue,
                        nodeChar,
                        DB.getPath(nodeChar, sPath),
                        nCurrentValue
                    )
                end
            end -- save didnt' change
        end -- for
    end -- no saves listed

    -- turn undead
    local nTurnLevel = DB.getValue(nodeAdvance, "turnlevel", 0)
    local nCurrentTurnLevel = DB.getValue(nodeChar, "turn.total", 0)
    if nCurrentTurnLevel < nTurnLevel then
        DB.setValue(nodeChar, "turn.total", "number", nTurnLevel)
        --ChatManager.SystemMessage("Turning improves by " .. nTurnLevel);
        outputAdvancementLog(
            "Turning improves by " .. nTurnLevel,
            nodeChar,
            DB.getPath(nodeChar, "turn.total"),
            nCurrentTurnLevel
        )
    end

    -- spell slots
    local nodeSpells = nodeAdvance.getChild("spells")
    local nodeArcaneSlots = nil
    local nodeDivineSlots = nil
    if (nodeSpells) then
        nodeArcaneSlots = nodeSpells.getChild("arcane")
        nodeDivineSlots = nodeSpells.getChild("divine")
    end
    -- spell slots
    -- arcane
    if (nodeArcaneSlots) then
        -- set the "spell level" so we can access it in spells
        local nNewArcaneLevel = DB.getValue(nodeAdvance, "arcane.totallevel", 0)
        if nNewArcaneLevel > 0 then
            local nPreviousArcaneLevel = DB.getValue(nodeChar, "arcane.totalLevel", 0)
            DB.setValue(nodeChar, "arcane.totalLevel", "number", nNewArcaneLevel)
            --ChatManager.SystemMessage("Arcane spellcasting level is now " .. nNewArcaneLevel);
            outputAdvancementLog(
                "Arcane spellcasting level is now " .. nNewArcaneLevel,
                nodeChar,
                DB.getPath(nodeChar, "arcane.totalLevel"),
                nPreviousArcaneLevel
            )
        end
        for i = 1, 9 do
            local nSlots = DB.getValue(nodeArcaneSlots, "level" .. i, 0)
            if (nSlots > 0) then
                local nCurrentSlots = DB.getValue(nodeChar, "powermeta.spellslots" .. i .. ".max", 0)
                local nAdjustedSlots = nCurrentSlots + nSlots
                DB.setValue(nodeChar, "powermeta.spellslots" .. i .. ".max", "number", nAdjustedSlots)
                outputAdvancementLog(
                    "Updated Arcane spell level " .. i .. " slots by " .. nSlots,
                    nodeChar,
                    DB.getPath(nodeChar, "powermeta.spellslots" .. i .. ".max"),
                    nCurrentSlots
                )
            end
        end
    end
    -- divine
    if (nodeDivineSlots) then
        local nNewDivineLevel = DB.getValue(nodeAdvance, "divine.totallevel", 0)
        -- set the "spell level" so we can access it in spells
        if nNewDivineLevel > 0 then
            local nPreviousDivineLevel = DB.getValue(nodeChar, "divine.totalLevel", 0)
            DB.setValue(nodeChar, "divine.totalLevel", "number", nNewDivineLevel)
            --ChatManager.SystemMessage("Divine spellcasting level is now " .. nNewDivineLevel);
            outputAdvancementLog(
                "Divine spellcasting level is now " .. nNewDivineLevel,
                nodeChar,
                DB.getPath(nodeChar, "divine.totalLevel"),
                nPreviousDivineLevel
            )
        end
        for i = 1, 7 do
            local nSlots = DB.getValue(nodeDivineSlots, "level" .. i, 0)
            if (nSlots > 0) then
                local nCurrentSlots = DB.getValue(nodeChar, "powermeta.pactmagicslots" .. i .. ".max", 0)
                local nAdjustedSlots = nCurrentSlots + nSlots
                DB.setValue(nodeChar, "powermeta.pactmagicslots" .. i .. ".max", "number", nAdjustedSlots)
                outputAdvancementLog(
                    "Updated Divine spell level " .. i .. " slots by " .. nSlots,
                    nodeChar,
                    DB.getPath(nodeChar, "powermeta.pactmagicslots" .. i .. ".max"),
                    nCurrentSlots
                )
            end
        end
    end

    -- psionic nonsense
    local nPSPGained = getPSPRollForAdvancement(nodeChar, nodeAdvance, nLevel)
    local nPSPBase = DB.getValue(nodeChar, "combat.psp.base", 0)
    DB.setValue(nodeChar, "combat.psp.base", "number", nPSPGained + nPSPBase)
    if nPSPGained > 0 then
        local nLevelPrevious = DB.getValue(nodeChar, "psionic.totalLevel", 0)
        DB.setValue(nodeChar, "psionic.totalLevel", "number", nLevel)
        --ChatManager.SystemMessage("Psionic power level improved to " .. nLevel);
        outputAdvancementLog(
            "Psionic power level improved to " .. nLevel,
            nodeChar,
            DB.getPath(nodeChar, "psionic.totalLevel"),
            nLevelPrevious
        )
        --ChatManager.SystemMessage("Gained [" .. nPSPGained .. "] addiontional Psionic strength points.");
        outputAdvancementLog(
            "Gained [" .. nPSPGained .. "] addiontional Psionic strength points.",
            nodeChar,
            DB.getPath(nodeChar, "combat.psp.base"),
            nPSPBase
        )
    end
    local nMTHACO = DB.getValue(nodeAdvance, "mthaco", 0)
    local nodeMTHACO = nodeCombat.createChild("mthaco") -- make sure these exist
    local nCurrentMTHACO = DB.getValue(nodeChar, "combat.mthaco.base", 20)
    if (nMTHACO ~= 0 and nMTHACO < nCurrentMTHACO) or (nMTHACO == 0 and nCurrentMTHACO == 1) then
        DB.setValue(nodeChar, "combat.mthaco.score", "number", nMTHACO)
        --ChatManager.SystemMessage("MTHACO updated to new value of " .. nMTHACO);
        outputAdvancementLog(
            "MTHACO updated to new value of " .. nMTHACO,
            nodeChar,
            DB.getPath(nodeChar, "combat.mthaco.base"),
            nCurrentMTHACO
        )
    end
    -- end psionic

    -- armor class
    local nACNew = DB.getValue(nodeAdvance, "ac")
    local nAC = DB.getValue(nodeChar, "defenses.ac.base", 10)
    if (nACNew ~= nil) then
        if (nACNew < nAC) then
            DB.setValue(nodeChar, "defenses.ac.base", "number", nACNew)
            --ChatManager.SystemMessage("AC updated to new value of " .. nACNew);
            outputAdvancementLog(
                "AC updated to new value of " .. nACNew,
                nodeChar,
                DB.getPath(nodeChar, "defenses.ac.base"),
                nAC
            )
        end
    end

    -- move base
    local nSpeedNew = DB.getValue(nodeAdvance, "speed")
    local nSpeed = DB.getValue(nodeChar, "speed.base", 12)
    if (nSpeedNew ~= nil) then
        if (nSpeedNew > nSpeed) then
            DB.setValue(nodeChar, "speed.base", "number", nSpeedNew)
            DB.setValue(nodeChar, "speed.basemodenc", "number", 0)
            --ChatManager.SystemMessage("Move base updated to new value of " .. nSpeedNew);
            outputAdvancementLog(
                "Move base updated to new value of " .. nSpeedNew,
                nodeChar,
                DB.getPath(nodeChar, "speed.base"),
                nSpeed
            )
        end
    end

    -- effects
    local nodeEffects = nodeAdvance.getChild("effectlist")
    addEffectFeature(nodeEffects, nodeChar)

    -- add/update skills
    addSkillAbilities(nodeAdvance, nodeChar)

    -- add attack abilities for this level if there are any
    addAttackAbilities(nodeAdvance, nodeChar)

    -- add spell/power abilities for this level if there are any
    addPowerAbilities(nodeAdvance, nodeChar)

    -- calculate hit points for new level (deals with single/multi/dual classing).
    updateHPForLevel(nodeChar, nodeClass, nodeAdvance)
end

-- add weapon/nonweapon slots granted
function addProficiencySlots(nodeAdvance, nodeChar)
    -- get current prof slots
    local nCharWeaponsCurrent = DB.getValue(nodeChar, "proficiencies.weapon.max", 0)
    local nCharNonWeaponsCurrent = DB.getValue(nodeChar, "proficiencies.nonweapon.max", 0)
    local nCharWeapons = DB.getValue(nodeChar, "proficiencies.weapon.max", 0)
    local nCharNonWeapons = DB.getValue(nodeChar, "proficiencies.nonweapon.max", 0)
    -- get profs for leveling (if used)
    local nWeaponProfs = DB.getValue(nodeAdvance, "weaponprofs", 0)
    if (nWeaponProfs > 0) then
        nCharWeapons = nCharWeapons + nWeaponProfs
        DB.setValue(nodeChar, "proficiencies.weapon.max", "number", nCharWeapons)
        --ChatManager.SystemMessage("Gained weapon proficiency slot(s): " .. nWeaponProfs);
        outputAdvancementLog(
            "Gained weapon proficiency slot(s): " .. nWeaponProfs,
            nodeChar,
            DB.getPath(nodeChar, "proficiencies.weapon.max"),
            nCharWeaponsCurrent
        )
    end
    local nNonWeaponProfs = DB.getValue(nodeAdvance, "nonweaponprofs", 0)
    if (nNonWeaponProfs > 0) then
        nCharNonWeapons = nCharNonWeapons + nNonWeaponProfs
        DB.setValue(nodeChar, "proficiencies.nonweapon.max", "number", nCharNonWeapons)
        --ChatManager.SystemMessage("Gained non-weapon proficiency slot(s): " .. nNonWeaponProfs);
        outputAdvancementLog(
            "Gained non-weapon proficiency slot(s): " .. nNonWeaponProfs,
            nodeChar,
            DB.getPath(nodeChar, "proficiencies.nonweapon.max"),
            nCharNonWeaponsCurrent
        )
    end
end

-- add attacks/weapon style abilities
function addAttackAbilities(nodeAdvance, nodeChar)
    local bItemHasWeapons = (DB.getChildCount(nodeAdvance, "weaponlist") > 0)
    --Debug.console("manager_char.lua","addAttackAbilities","bItemHasWeapons",bItemHasWeapons);
    if (bItemHasWeapons) then
        local nodeWeapons = nodeChar.createChild("weaponlist")
        if not nodeWeapons then
            return
        end
        for _, v in pairs(DB.getChildren(nodeAdvance, "weaponlist")) do
            local nodeWeapon = nodeWeapons.createChild()
            DB.copyNode(v, nodeWeapon)
            --DB.setValue(nodeWeapon, "shortcut", "windowreference", "item", "....inventorylist." .. nodeItem.getName());
            local sName = DB.getValue(nodeWeapon, "name")
            --ChatManager.SystemMessage("Adding new attack: " .. sName .. ".");
            outputAdvancementLog("Adding new attack: " .. sName .. ".", nodeChar, v.getPath())
        end
    end
end

-- add skill/non-weapon style abilities
function addSkillAbilities(nodeAdvance, nodeChar)
    local bHasSkills = (DB.getChildCount(nodeAdvance, "skilllist") > 0)
    --Debug.console("manager_char.lua","addAttackAbilities","bHasSkills",bHasSkills);
    if (bHasSkills) then
        local nodeSkills = nodeChar.createChild("skilllist")
        if not nodeSkills then
            return
        end
        for _, advancementSkill in pairs(DB.getChildren(nodeAdvance, "skilllist")) do
            local originalSkill = skillExists(nodeChar, DB.getValue(advancementSkill, "name"))
            if (originalSkill) then
                -- skill exists already with same name, only update values that are improvements.
                local sName = DB.getValue(originalSkill, "name", "")
                local bAdditive = (DB.getValue(advancementSkill, "skill_additive", 0) == 1)

                -- flip through all values and update
                local aValues = {"base_check", "adj_armor", "adj_class", "adj_racial", "adj_mod", "adj_stat", "misc"}
                for _, sValue in ipairs(aValues) do
                    local nCheck = DB.getValue(originalSkill, sValue, 0)
                    local nCheckNew = DB.getValue(advancementSkill, sValue, 0)
                    -- this adjusts the skill +/- the skill value
                    if (bAdditive) then
                        nCheckNew = nCheck + nCheckNew
                    end
                    if (nCheckNew ~= nCheck) then
                        --ChatManager.SystemMessage("Updated Skill: " .. sName .. " " .. sValue .. " to new value of " .. nCheckNew);
                        outputAdvancementLog(
                            "Updated Skill: " .. sName .. " " .. sValue .. " to new value of " .. nCheckNew,
                            nodeChar,
                            DB.getPath(originalSkill, sValue),
                            nCheck
                        )
                        DB.setValue(originalSkill, sValue, "number", nCheckNew)
                    end
                end -- end flipping through sValues

                -- <stat type="string">percent</stat>
                local stat = DB.getValue(originalSkill, "stat", "")
                local statNew = DB.getValue(advancementSkill, "stat", "")
                if (statNew ~= stat) then
                    --ChatManager.SystemMessage("Updated Skill:" .. sName .. " stat to new value of " .. statNew);
                    outputAdvancementLog(
                        "Updated Skill:" .. sName .. " stat to new value of " .. statNew,
                        nodeChar,
                        DB.getPath(originalSkill, "stat"),
                        stat
                    )
                    DB.setValue(originalSkill, "stat", "string", statNew)
                end
                -- formatted text
                local text = DB.getValue(originalSkill, "text", "")
                local textNew = DB.getValue(advancementSkill, "text", "")
                if (textNew ~= text) then
                    --ChatManager.SystemMessage("Updated Skill: " .. sName .. " text to new value.");
                    outputAdvancementLog(
                        "Updated Skill: " .. sName .. " text to new value.",
                        nodeChar,
                        DB.getPath(originalSkill, "text"),
                        text
                    )
                    DB.setValue(originalSkill, "text", "formattedtext", textNew)
                end
            else
                -- brand new skill
                local newSkill = nodeSkills.createChild()
                local sName = DB.getValue(advancementSkill, "name", "")
                --ChatManager.SystemMessage("Adding new skill: " .. sName .. ".");
                outputAdvancementLog("Adding new skill: " .. sName .. ".", nodeChar, newSkill.getPath())
                DB.copyNode(advancementSkill, newSkill)
            end
        end
    end
end

-- return node of a skill name that matches sSkillName
function skillExists(nodeChar, sSkillName)
    local nodeSkillFound = nil
    for _, nodeSkill in pairs(DB.getChildren(nodeChar, "skilllist")) do
        local sName = DB.getValue(nodeSkill, "name")
        if StringManager.trim(sName:lower()) == sSkillName:lower() then
            nodeSkillFound = nodeSkill
            break -- found matching skill, get out
        end
    end
    return nodeSkillFound
end

-- add spells/powers
function addPowerAbilities(nodeAdvance, nodeChar)
    local bItemHasPowers = (DB.getChildCount(nodeAdvance, "powers") > 0)
    --Debug.console("manager_char.lua","addAttackAbilities","bItemHasPowers",bItemHasPowers);
    if (bItemHasPowers) then
        local nodePowers = nodeChar.createChild("powers")
        if not nodePowers then
            return
        end
        for _, v in pairs(DB.getChildren(nodeAdvance, "powers")) do
            local nodePower = nodePowers.createChild()
            DB.copyNode(v, nodePower)
            --DB.setValue(nodePower, "description","formattedtext",DB.getValue(nodeItem,"description",""));
            --DB.setValue(nodePower, "shortcut", "windowreference", "item", "....inventorylist." .. nodeItem.getName());
            DB.setValue(nodePower, "locked", "number", 1) -- want this to start locked
            local sName = DB.getValue(nodePower, "name")
            --ChatManager.SystemMessage("Adding new power: " .. sName .. ".");
            outputAdvancementLog("Adding new power: " .. sName .. ".", nodeChar, nodePower.getPath())
        end
    end
end

-- add advanced effects to character
function addEffectFeature(nodeEffects, nodeChar)
    if nodeEffects and nodeEffects.getChildCount() > 0 then
        local nodeCharEffectList = nodeChar.createChild("effectlist")
        for _, nodeEffect in pairs(nodeEffects.getChildren()) do
            local addNode = nodeCharEffectList.createChild()
            local sEffectLabel = DB.getValue(nodeEffect, "effect", "")
            DB.copyNode(nodeEffect, addNode)
            outputAdvancementLog("Adding new effect: " .. sEffectLabel .. ".", nodeChar, addNode.getPath())
        end
    end
end

function addClassFeatureHelper(aSelection, rClassAdd)
    local nodeSource = rClassAdd.nodeSource
    local nodeChar = rClassAdd.nodeChar

    -- Check to see if we added specialization
    if aSelection then
        if #aSelection ~= 1 then
            --ChatManager.SystemMessage(Interface.getString("char_error_addclassspecialization"));
            outputAdvancementLog(Interface.getString("char_error_addclassspecialization"))
            return
        end

        -- Add specialization
        for _, v in pairs(DB.getChildrenGlobal(nodeSource, "abilities")) do
            if DB.getValue(v, "name", "") == aSelection[1] then
                addClassFeatureDB(nodeChar, "reference_classability", v.getPath(), rClassAdd.nodeClass)
            end
        end
    end

    -- Add features
    for _, v in pairs(DB.getChildren(nodeSource, "features")) do
        if
            (DB.getValue(v, "level", 0) < 1 or DB.getValue(v, "level", 0) == rClassAdd.nLevel) and
                (DB.getValue(v, "specializationchoice", 0) == 0)
         then
            local sFeatureName = DB.getValue(v, "name", "")
            local sFeatureSpec = DB.getValue(v, "specialization", "")
            if sFeatureSpec == "" or hasFeature(nodeChar, sFeatureSpec) then
                addClassFeatureDB(nodeChar, "reference_classfeature", v.getPath(), rClassAdd.nodeClass)
            end
        end
    end
end

-- return total exp on all classes (active or not)
function getTotalEXP(nodeChar)
    if not nodeChar then
        return 0
    end
    local nCount = DB.getValue(nodeChar, "exp", 0) -- all exp ever earned
    return nCount
end

-- return experience that we have not applied yet.
function getEXPNotApplied(nodeChar)
    if not nodeChar then
        return
    end
    local nGrantedEXP = DB.getValue(nodeChar, "xpgranted", 0) -- exp that has been granted already
    local nTotalEXP = getTotalEXP(nodeChar) -- all exp ever earned
    local nDiffEXP = nTotalEXP - nGrantedEXP
    -- if total exp is reset to 0 then we flush everything.
    if (nTotalEXP == 0) then
        DB.setValue(nodeChar, "xpgranted", "number", 0)
        nDiffEXP = 0
    end
    return nDiffEXP
end
-- apply experience to active classes.
function applyEXPToActiveClasses(nodeChar)
    if not nodeChar then
        return
    end
    --local nActiveClasses = getClassCount(nodeChar);     --
    local nActiveClasses = getActiveClassCount(nodeChar)
    local nTotalEXPEarned = DB.getValue(nodeChar, "exp", 0) -- all exp ever earned
    local nApplyAmount = getEXPNotApplied(nodeChar)
    -- nothing to give
    if nActiveClasses < 1 then
        return
    end
    local nApplyPerClass = math.ceil(nApplyAmount / nActiveClasses)

    for _, vClass in pairs(DB.getChildren(nodeChar, "classes")) do
        local sClass = DB.getValue(vClass, "name", "UNKNOWN")
        --Debug.console("manager_char.lua","applyEXPToActiveClasses","sClass",sClass);
        local bActive = (DB.getValue(vClass, "classactive", 0) == 1)

        if (bActive) then
            local nEXP = DB.getValue(vClass, "exp", 0)
            local nApplyEXP = nApplyPerClass
            local nBonusXP = tonumber(DB.getValue(vClass, "bonusxp", "0")) or 0
            if (nBonusXP > 0) then -- give bonus XX%, 5 or 10 exp
                nBonusXP = nBonusXP * 0.01 -- convert to percent
                nApplyEXP = math.ceil(nApplyPerClass + (nApplyPerClass * nBonusXP))
            end

            local nTotalAmount = nEXP + nApplyEXP
            DB.setValue(vClass, "exp", "number", nTotalAmount)
            local sFormat = Interface.getString("message_exp_applied")
            local sMsg = string.format(sFormat, DB.getValue(nodeChar, "name", ""), nApplyEXP, sClass)
            --ChatManager.SystemMessage(sMsg);
            outputAdvancementLog(sMsg, nodeChar, DB.getPath(vClass, "exp"), nEXP)
        end
    end
    -- exp applied, match exp to expgranted now
    DB.setValue(nodeChar, "xpgranted", "number", nTotalEXPEarned)
end

function addSkillRef(nodeChar, sClass, sRecord)
    local nodeSource = resolveRefNode(sRecord)
    if not nodeSource then
        return
    end
    --Debug.console("manager_char.lua","addSkillRef","nodeSource",nodeSource);

    -- Add skill entry
    local nodeSkill = addSkillDB(nodeChar, DB.getValue(nodeSource, "name", ""), nodeSource)
    if nodeSkill then
        DB.setValue(nodeSkill, "text", "formattedtext", DB.getValue(nodeSource, "text", ""))
    end
end

function calcSpellcastingLevel(nodeChar)
    local nCurrSpellClass = 0
    for _, vClass in pairs(DB.getChildren(nodeChar, "classes")) do
        if DB.getValue(vClass, "casterlevelinvmult", 0) > 0 then
            nCurrSpellClass = nCurrSpellClass + 1
        end
    end

    local nCurrSpellCastLevel = 0
    for _, vClass in pairs(DB.getChildren(nodeChar, "classes")) do
        if DB.getValue(vClass, "casterpactmagic", 0) == 0 then
            local nClassSpellSlotMult = DB.getValue(vClass, "casterlevelinvmult", 0)
            if nClassSpellSlotMult > 0 then
                local nClassSpellCastLevel = DB.getValue(vClass, "level", 0)
                if nCurrSpellClass > 1 then
                    nClassSpellCastLevel = math.floor(nClassSpellCastLevel * (1 / nClassSpellSlotMult))
                else
                    nClassSpellCastLevel = math.ceil(nClassSpellCastLevel * (1 / nClassSpellSlotMult))
                end
                nCurrSpellCastLevel = nCurrSpellCastLevel + nClassSpellCastLevel
            end
        end
    end

    return nCurrSpellCastLevel
end

function calcPactMagicLevel(nodeChar)
    local nPactMagicLevel = 0
    for _, vClass in pairs(DB.getChildren(nodeChar, "classes")) do
        if DB.getValue(vClass, "casterpactmagic", 0) > 0 then
            local nClassSpellSlotMult = DB.getValue(vClass, "casterlevelinvmult", 0)
            if nClassSpellSlotMult > 0 then
                local nClassSpellCastLevel = DB.getValue(vClass, "level", 0)
                nClassSpellCastLevel = math.ceil(nClassSpellCastLevel * (1 / nClassSpellSlotMult))
                nPactMagicLevel = nPactMagicLevel + nClassSpellCastLevel
            end
        end
    end

    return nPactMagicLevel
end

function addAdventureDB(nodeChar, sClass, sRecord)
    local nodeSource = resolveRefNode(sRecord)
    if not nodeSource then
        return
    end

    -- Get the list we are going to add to
    local nodeList = nodeChar.createChild("adventurelist")
    if not nodeList then
        return nil
    end

    -- Copy the adventure record data
    local vNew = nodeList.createChild()
    DB.copyNode(nodeSource, vNew)
    DB.setValue(vNew, "locked", "number", 1)

    -- Notify
    --outputUserMessage("char_logs_message_adventureadd", DB.getValue(nodeSource, "name", ""), DB.getValue(nodeChar, "name", ""));
    local sMsg =
        string.format(
        Interface.getString("char_logs_message_adventureadd"),
        DB.getValue(nodeSource, "name", ""),
        DB.getValue(nodeChar, "name", "")
    )
    outputAdvancementLog(sMsg, nodeChar, vNew.getPath())
end

function hasTrait(nodeChar, sTrait)
    return (getTraitRecord(nodeChar, sTrait) ~= nil)
end

function getTraitRecord(nodeChar, sTrait)
    local sTraitLower = StringManager.trim(sTrait):lower()
    for _, v in pairs(DB.getChildren(nodeChar, "traitlist")) do
        if StringManager.trim(DB.getValue(v, "name", "")):lower() == sTraitLower then
            return v
        end
    end
    return nil
end

function hasFeature(nodeChar, sFeature)
    local sFeatureLower = sFeature:lower()
    for _, v in pairs(DB.getChildren(nodeChar, "featurelist")) do
        if DB.getValue(v, "name", ""):lower() == sFeatureLower then
            return true
        end
    end

    return false
end

function hasFeat(nodeChar, sFeat)
    return (getFeatRecord(nodeChar, sFeat) ~= nil)
end

function getFeatRecord(nodeChar, sFeat)
    if not sFeat then
        return nil
    end
    local sFeatLower = sFeat:lower()
    for _, v in pairs(DB.getChildren(nodeChar, "featlist")) do
        if DB.getValue(v, "name", ""):lower() == sFeatLower then
            return v
        end
    end
    return nil
end

-- return the CTnode by using character sheet node
function getCTNodeByNodeChar(nodeChar)
    local nodeCT = nil
    for _, node in pairs(DB.getChildren("combattracker.list")) do
        local _, sRecord = DB.getValue(node, "link", "", "")
        if sRecord ~= "" and sRecord == nodeChar.getPath() then
            nodeCT = node
            break
        end
    end
    return nodeCT
end
function convertSingleNumberTextToNumber(s)
    if s then
        if s == "one" then
            return 1
        end
        if s == "two" then
            return 2
        end
        if s == "three" then
            return 3
        end
        if s == "four" then
            return 4
        end
        if s == "five" then
            return 5
        end
        if s == "six" then
            return 6
        end
        if s == "seven" then
            return 7
        end
        if s == "eight" then
            return 8
        end
        if s == "nine" then
            return 9
        end
    end
    return 0
end

-- return the nodeChar by using the combattracker nodeCT
function getNodeByCT(nodeCT)
    local _, sRecord = DB.getValue(nodeCT, "link", "", "")
    local nodeChar = DB.findNode(sRecord)
    return nodeChar
end

-- returns the number of classes the character has
function getClassCount(nodeChar)
    local nClassCount = 0

    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        nClassCount = nClassCount + 1
    end

    return nClassCount
end

-- returns the number of classes the character has
function getActiveClassCount(nodeChar)
    local nClassCount = 0
    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        local nClassActive = DB.getValue(nodeClass, "classactive", 0)
        if (nClassActive ~= 0) then
            nClassCount = nClassCount + 1
        end
    end
    return nClassCount
end

-- returns the highest level for all active classes.
function getActiveClassMaxLevel(nodeChar)
    --Debug.console("manager_char.lua","getActiveClassMaxLevel","nodeChar",nodeChar);
    local nMaxLevel = 0
    local oMaxClass = nil
    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        local bClassActive = (DB.getValue(nodeClass, "classactive", 0) ~= 0)
        local nLevel = DB.getValue(nodeClass, "level", 0)
        if (bClassActive and nLevel > nMaxLevel) then
            oMaxClass = nodeClass
            nMaxLevel = nLevel
        end
    end
    return nMaxLevel, oMaxClass
end

-- returns the highest level for all classes, active or not
function getAbsoluteClassMaxLevel(nodeChar)
    local nMaxLevel = 0
    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        local nLevel = DB.getValue(nodeClass, "level", 0)
        if (nLevel > nMaxLevel) then
            nMaxLevel = nLevel
        end
    end
    return nMaxLevel
end

-- get class level by name
function getClassLevelByName(nodeChar, sClassName)
    local nMaxLevel = 0
    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        local nLevel = DB.getValue(nodeClass, "level", 0)
        local sClass = DB.getValue(nodeClass, "name", "<unknown>")
        if (sClass:lower() == sClassName:lower()) then
            nMaxLevel = nLevel
        end
    end
    return nMaxLevel
end

-- get list of all class names for this character and return as array
function getAllClassNames(nodeChar)
    local aClasses = {}
    for _, nodeChild in pairs(DB.getChildren(nodeChar, "classes")) do
        local sName = DB.getValue(nodeChild, "name", "")
        table.insert(aClasses, sName)
    end
    return aClasses
end

-- return true if the node has sClass i.e. Cleric or Paladin or Fighter.
function hasClass(nodeChar, sClass)
    local bHasClass = false
    for _, nodeChild in pairs(DB.getChildren(nodeChar, "classes")) do
        local sName = DB.getValue(nodeChild, "name", "")
        if sName:lower() == sClass:lower() then
            bHasClass = true
            break
        end
    end
    return bHasClass
end
-- return if has inactive class
function hasInActiveClass(nodeChar)
    local bInactive = false
    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        local nClassActive = DB.getValue(nodeClass, "classactive", 0)
        if (nClassActive == 0) then
            bInactive = true
            break
        end
    end

    return bInactive
end
-- returns the highest level for inActive classes.
function getInActiveClassMaxLevel(nodeChar)
    local nMaxLevel = 0
    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        local nClassActive = DB.getValue(nodeClass, "classactive", 0)
        local nLevel = DB.getValue(nodeClass, "level", 0)
        if ((nClassActive == 0) and (nLevel > nMaxLevel)) then
            nMaxLevel = nLevel
        end
    end
    return nMaxLevel
end

-- increase HP for character for new level added
function updateHPForLevel(nodeChar, nodeClass, nodeAdvance)
    local nOriginalHP = DB.getValue(nodeChar, "hp.base", 0)
    Debug.console("manager_char.lua", "updateHPForLevelnew", "nOriginalHP", nOriginalHP)
    local nHP = DB.getValue(nodeChar, "hp.base", 0)
    local nClassCount = getActiveClassCount(nodeChar)
    local nLevel = DB.getValue(nodeClass, "level", 0)
    local sClassName = DB.getValue(nodeClass, "name", "")
    local nHPRoll = 0
    local nConBonus = 0
    -- check for multi-class PC

    Debug.console("manager_char.lua updateHPForLevelnew", nOriginalHP, nHP, nClassCount, nLevel, sClassName)

    if nClassCount == 1 then
        -- everything else, single classed
        nHPRoll, nConBonus = getHPRollForAdvancement(nodeChar, nodeClass, nodeAdvance, nClassCount, nLevel)
        Debug.console("manager_char.lua updateHPForLevelnew nHPRoll 1", nHPRoll)
        Debug.console("manager_char.lua updateHPForLevelnew nConBonus 1", nConBonus)
    elseif nClassCount > 1 and not hasInActiveClass(nodeChar) then
        -- if level 1 across the board we need to recalculate hp
        -- to adjust for division of hp for a new class
        if (getActiveClassMaxLevel(nodeChar) == 1) then
            DB.setValue(nodeChar, "hp.base", "number", 0) -- reset base to 0
            reCalculateHPForMultiClass(nodeChar, nodeClass) -- recalculate hps for other classes
            nHP = DB.getValue(nodeChar, "hp.base", 0)
            local sMsg =
                string.format(
                "Recalculating hitpoints for additional class in multi-class configuration. Previous %d, adjusted to %d.",
                nOriginalHP,
                nHP
            )
            --ChatManager.SystemMessage(sMsg);
            outputAdvancementLog(sMsg, nodeChar, DB.getPath(nodeChar, "hp.base"), nOriginalHP)
        end
        -- now we can get the new hp from new class
        nHPRoll, nConBonus = getHPRollForAdvancement(nodeChar, nodeClass, nodeAdvance, nClassCount, nLevel) -- add current class hp
    elseif hasInActiveClass(nodeChar) and getInActiveClassMaxLevel(nodeChar) < nLevel then
        -- this is dual class character, we don't add hp unless the level of the new class is
        -- greater than the inactive class
        nHPRoll, nConBonus = getHPRollForAdvancement(nodeChar, nodeClass, nodeAdvance, nClassCount, nLevel)
    else
        Debug.console("manager_char.lua updateHPForLevelnew Dual class but new class isn't greater than previous.")
    end

    -- now display text from level up hp
    local sFormat = Interface.getString("char_abilities_message_leveledup")
    local sMsg = string.format(sFormat, DB.getValue(nodeChar, "name", ""), nLevel, sClassName, nHPRoll)
    --DB.setValue(nodeChar, "hp.total", "number", nHP+nHPRoll);
    local nNewHPBase = nHP + nHPRoll
    DB.setValue(nodeChar, "hp.base", "number", nNewHPBase)
    --ChatManager.SystemMessage(sMsg);
    outputAdvancementLog(sMsg, nodeChar, DB.getPath(nodeChar, "hp.base"), nOriginalHP)
end

-- get constitution bonus for this character/class for hp update
function getConstitutionHPBonus(nodeChar, nodeClass, nodeAdvance)
    -- Add hit points based on level added
    local sClassName = DB.getValue(nodeClass, "name", "")
    local aHDice = nil
    if nodeAdvance then
        aHDice = DB.getValue(nodeAdvance, "hp.dice")
    end
    local sConBonus = DB.getValue(nodeChar, "abilities.constitution.hitpointadj")
    local nConBonus = 0

    if (sConBonus ~= "" and string.match(sConBonus, "/")) then
        local aConBonus = StringManager.split(sConBonus, "/", true)
        -- if fighter, give higher bonus
        --if StringManager.contains(DataCommonADND.fighterTypes, sClassName:lower()) then
        if
            UtilityManagerADND.containsAny(DataCommonADND.fighterTypes, sClassName:lower()) or
                hasFeature(nodeChar, FEATURE_WARRIOR_HITPOINT_BONUS)
         then
            if aConBonus[2] then
                nConBonus = tonumber(aConBonus[2])
            else
                nConBonus = tonumber(aConBonus[1])
            end
        else
            nConBonus = tonumber(aConBonus[1])
        end
    elseif (sConBonus ~= "") then
        nConBonus = tonumber(sConBonus)
    else
        nConBonus = 0
    end
    -- we don't grant con bonus if no longer using hit dice (i.e. only using nHPAdjustment)
    if (nodeAdvance and aHDice == nil) then
        nConBonus = 0
    end
    return nConBonus
end

-- return the class node fromo the name sClass ("Fighter","Wizard","Bard"/etc)
function getClassFromName(sClass)
    local node = nil
    --Debug.console("manager_char.lua","getClassFromName","sClass",sClass);
    local vMappings = LibraryData.getMappings("class")
    for _, sMap in ipairs(vMappings) do
        for _, nodeClass in pairs(DB.getChildrenGlobal(sMap)) do
            local sName = DB.getValue(nodeClass, "name", "")
            --Debug.console("manager_char.lua","getClassFromName","sName",sName);
            if (sClass == sName) then
                node = nodeClass
                break
            end
        end
        if node then
            break
        end
    end
    return node
end

-- flip through all classes and levels of each and return the total
-- constitution adjustments they should have for current con value.
function getAllClassAndLevelConAdjustments(nodeChar)
    local nConBonus = 0
    local nClassCount = getClassCount(nodeChar)
    local nFoundClassCount = 0
    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        --Debug.console("manager_char.lua","getAllConAdjustments","nodeClass",nodeClass);
        local sClassName = DB.getValue(nodeClass, "name", "")
        local nLevel = DB.getValue(nodeClass, "level", 0)
        --Debug.console("manager_char.lua","getAllConAdjustments","sClassName",sClassName);
        --Debug.console("manager_char.lua","getAllConAdjustments","nLevel",nLevel);
        local nodeClass = getClassFromName(sClassName)
        --Debug.console("manager_char.lua","getAllConAdjustments","nodeClass",nodeClass);
        if (nodeClass) then
            nFoundClassCount = nFoundClassCount + 1
            for i = 1, nLevel do
                --Debug.console("manager_char.lua","getAllConAdjustments","Level:i",i);
                for _, nodeAdvance in pairs(DB.getChildren(nodeClass, "advancement")) do
                    --Debug.console("manager_char.lua","getAllConAdjustments","nodeAdvance",nodeAdvance);
                    local nAdvLevel = DB.getValue(nodeAdvance, "level", 0)
                    if (nAdvLevel == i) then
                        local nCon = getConstitutionHPBonus(nodeChar, nodeClass, nodeAdvance)
                        nConBonus = nConBonus + nCon
                    --Debug.console("manager_char.lua","getAllConAdjustments","nCon",nCon);
                    --Debug.console("manager_char.lua","getAllConAdjustments","nConBonus1",nConBonus);
                    end
                end
            end
        end
    end
    -- make sure we found all the classes we have
    if nFoundClassCount == nClassCount and nFoundClassCount ~= 0 and nClassCount ~= 0 then
        nConBonus = math.floor(nConBonus / nClassCount) or 0
    else
        -- if not we just say nil and it wont change whats current
        nConBonus = nil
    end
    --Debug.console("manager_char.lua","getAllConAdjustments","nConBonus2",nConBonus);
    return nConBonus
end

-- recalculate hp based on new class added at level 1 for multi-class characters
-- ignore the class we're adding, just recalculate the rest
function reCalculateHPForMultiClass(nodeChar, nodeClass)
    local sCurrentClass = DB.getValue(nodeClass, "name", "")
    local nClassCount = getActiveClassCount(nodeChar)
    local nHPRecalculated = 0
    for _, nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
        local sClassName = DB.getValue(nodeClass, "name", "")
        if sClassName ~= sCurrentClass then -- skip current class, only deal with others
            local nodeAdvance = nil
            local sClass, sRecord = DB.getValue(nodeClass, "shortcut", "", "")
            if sRecord and sRecord ~= "" then
                nodeAdvance = DB.findNode(sRecord)
                if nodeAdvance then
                    for _, node in pairs(DB.getChildren(nodeAdvance, "advancement")) do
                        local nAdvanceLevel = DB.getValue(node, "level", 0)
                        if nAdvanceLevel == 1 then
                            local nHP, nConBonus = getHPRollForAdvancement(nodeChar, nodeClass, node, nClassCount, 1)
                            -- take new value based on new multi-class count
                            nHPRecalculated = nHPRecalculated + nHP
                            Debug.console(
                                "manager_char.lua",
                                "reCalculateHPForMultiClass",
                                "nHPRecalculated",
                                nHPRecalculated
                            )
                            DB.setValue(nodeChar, "hp.base", "number", nHPRecalculated)
                            local sFormat = Interface.getString("char_abilities_message_leveledup")
                            local sMsg =
                                string.format(
                                sFormat,
                                DB.getValue(nodeChar, "name", ""),
                                1,
                                sClassName .. "(multi)",
                                nHP
                            )
                            --ChatManager.SystemMessage(sMsg);
                            outputAdvancementLog(sMsg, nodeChar)
                            break -- we stop at first one that matches level 1
                        end
                    end -- for
                end
            end
        end
    end -- for
    -- if nHPRecalculated < 1 then
    -- nHPRecalculated = 1;
    -- end
    --DB.setValue(nodeChar,"hp.base","number", nHPRecalculated);
end

-- get hp calculations for new level
function getHPRollForAdvancement(nodeChar, nodeClass, nodeAdvance, nClassCount, nLevel)
    local nHP = 0
    local aHDice = DB.getValue(nodeAdvance, "hp.dice")
    local nHPAdjustment = DB.getValue(nodeAdvance, "hp.adjustment")
    local nHPRoll = 0
    --local nConBonus = getConstitutionHPBonus(nodeChar,nodeClass,nodeAdvance);
    --local nConBonus = 0; -- disabled getting con bonus, it's calculated on the fly now --celestian
    if aHDice ~= nil then
        -- level 1 gets max hp
        if nLevel == 1 then
            -- first level, max hp roll
            nHPRoll = StringManager.evalDice(aHDice, nHPAdjustment, true)
            -- multi-class divides hp
            if (nClassCount > 1 and not hasInActiveClass(nodeChar)) then
                nHPRoll = math.floor((nHPRoll / nClassCount) + 0.5)
            end
        else
            nHPRoll = StringManager.evalDice(aHDice, nHPAdjustment)
            -- multi-class divides hp
            if (nClassCount > 1 and not hasInActiveClass(nodeChar)) then
                nHPRoll = math.floor((nHPRoll / nClassCount) + 0.5)
            end
        end
    else
        nHPRoll = nHPAdjustment
        -- multi-class divides hp
        if (nClassCount > 1 and not hasInActiveClass(nodeChar)) then
            nHPRoll = math.floor((nHPRoll / nClassCount) + 0.5)
        end
    end

    -- Debug.console("manager_char.lua getHPRollForAdvancement", nHPRoll);
    nHP = nHPRoll
    return nHP, 0
end

-- flip though all slots and if has spell slot return true
function hasSpellSlots(nodeSpellSlots, sSpellType)
    local nMaxSlots = 9
    local bHasNewSlots = false
    if (sSpellType == "divine") then
        nMaxSlots = 7
    end
    for i = 1, nMaxSlots do
        local nSlots = DB.getValue(nodeSpellSlots, "level" .. i, 0)
        if (nSlots > 0) then
            bHasNewSlots = true
            break
        end
    end
    return bHasNewSlots
end

-- get Psionic strength point calculations for new level
function getPSPRollForAdvancement(nodeChar, nodeAdvance, nLevel)
    local nRollResults = 0
    local aPSPDice = DB.getValue(nodeAdvance, "psp.dice")
    local nPSPAdjustment = DB.getValue(nodeAdvance, "psp.adjustment", 0)
    local sPSPDice = StringManager.convertDiceToString(aPSPDice, nPSPAdjustment)
    local nPSPBonuses = getWisIntConPSPBonus(nodeChar, nodeAdvance)
    if aPSPDice ~= nil then
        -- level 1 gets +15 psp
        if nLevel == 1 then
            nRollResults = StringManager.evalDice(aPSPDice, nPSPAdjustment + nPSPBonuses) + 15
        else
            nRollResults = StringManager.evalDice(aPSPDice, nPSPAdjustment + nPSPBonuses)
        end
    elseif nPSPAdjustment > 0 then
        nRollResults = nPSPAdjustment + nPSPBonuses
    end
    return nRollResults
end
-- get Wisdom/Intelligence/Consitution bonus for this character/class for PSionic strength points
function getWisIntConPSPBonus(nodeChar, nodeAdvance)
    -- Add hit points based on level added
    local aPSPDice = DB.getValue(nodeAdvance, "psp.dice")
    local dbAbilityWis = AbilityScoreADND.getWisdomProperties(nodeChar)
    local nWisBonus = dbAbilityWis.psp_bonus or 0
    local dbAbilityInt = AbilityScoreADND.getIntelligenceProperties(nodeChar)
    local nIntBonus = dbAbilityInt.psp_bonus or 0
    local dbAbilityCon = AbilityScoreADND.getConstitutionProperties(nodeChar)
    local nConBonus = dbAbilityCon.psp_bonus or 0
    -- no more con/int bonuses once we stop using dice
    if (aPSPDice == nil) then
        nConBonus = 0
        nIntBonus = 0
    end
    return nWisBonus + nIntBonus + nConBonus
end

-- get prof rate from nodeClass (or nodeClassSource if note set)
function getProficiencyRate(nodeChar, nodeClass, nodeClassSource)
    local nSourceWeapon = DB.getValue(nodeClassSource, "profs.rate.weapon", 0) or 0
    local nSourceNonWeapon = DB.getValue(nodeClassSource, "profs.rate.nonweapon", 0) or 0

    local nWeaponRate = DB.getValue(nodeClass, "profs.rate.weapon", nSourceWeapon)
    DB.setValue(nodeClass, "profs.rate.weapon", "number", nWeaponRate) -- set this so we can access it from other classes during multiclass stuff
    local nNonWeaponRate = DB.getValue(nodeClass, "profs.rate.nonweapon", nSourceNonWeapon)
    DB.setValue(nodeClass, "profs.rate.nonweapon", "number", nNonWeaponRate) -- set this so we can access it from other classes during multiclass stuff
    return nWeaponRate, nNonWeaponRate
end

-- get Best proficiency rate and return it
function getBestProficiencyRate(nodeChar, nodeClass, nodeClassSource)
    local nWeaponRate, nNonWeaponRate = getProficiencyRate(nodeChar, nodeClass, nodeClassSource)

    local nClassCount = getActiveClassCount(nodeChar)
    if (nClassCount > 1) then
        for _, oClass in pairs(DB.getChildren(nodeChar, "classes")) do
            local bActive = (DB.getValue(oClass, "classactive", 0) == 1)
            --local sClassName = DB.getValue(oClass, "name","")
            if bActive and oClass ~= nodeClass then
                local nWeap, nNonWeap = getProficiencyRate(nodeChar, oClass, nil)
                if (nWeapon ~= 0 and nWeap < nWeaponRate) then
                    nWeaponRate = nWeap
                end
                if (nNonWeap ~= 0 and nNonWeap < nNonWeaponRate) then
                    nNonWeaponRate = nNonWeap
                end
            end
        end
     -- for
    end
    return nWeaponRate, nNonWeaponRate
end

-- get prof initial from nodeClass (or nodeClassSource if note set)
function getProficiencyInitial(nodeChar, nodeClass, nodeClassSource)
    local nSourceWeapon = DB.getValue(nodeClassSource, "profs.initial.weapon", 0) or 0
    local nSourceNonWeapon = DB.getValue(nodeClassSource, "profs.initial.nonweapon", 0) or 0

    local nWeapons = DB.getValue(nodeClass, "profs.initial.weapon", nSourceWeapon)
    DB.setValue(nodeClass, "profs.initial.weapon", "number", nWeapons) -- set this so we can access it from other classes during multiclass stuff
    local nNonWeapons = DB.getValue(nodeClass, "profs.initial.nonweapon", nSourceNonWeapon)
    DB.setValue(nodeClass, "profs.initial.nonweapon", "number", nNonWeapons) -- set this so we can access it from other classes during multiclass stuff
    return nWeapons, nNonWeapons
end
-- get Best initial proficiency slots and return it
function getBestProficiencyInitial(nodeChar, nodeClass, nodeClassSource)
    local nWeapons, nNonWeapon = getProficiencyInitial(nodeChar, nodeClass, nodeClassSource)
    local nClassCount = getActiveClassCount(nodeChar)
    if (nClassCount > 1) then
        for _, oClass in pairs(DB.getChildren(nodeChar, "classes")) do
            local bActive = (DB.getValue(oClass, "classactive", 0) == 1)
            --local sClassName = DB.getValue(oClass, "name","")
            if bActive and oClass ~= nodeClass then
                local nWeap, nNonWeap = getProficiencyInitial(nodeChar, oClass, nil)
                if (nWeap ~= 0 and nWeap > nWeapons) then
                    nWeapons = nWeap
                end
                if (nNonWeap ~= 0 and nNonWeap > nNonWeapon) then
                    nNonWeapon = nNonWeap
                end
            end
        end
     -- for
    end

    return nWeapons, nNonWeapon
end

---
-- Manage hitpoint modifiers and total
-- (needs to pickup constitution score adjustments automatically still --celestian)
---
function updateHealthScore(nodeChar)
    --Debug.console("manager_char.lua","updateHealthScore","nodeChar",nodeChar);
    local bNPC = (not ActorManager.isPC(nodeChar))
    if (bNPC) then
        -- npcs don't use this, need to not set it
        --DB.setValue(nodeChar,"hptotal","number",nTotal);
        local nodeCT = CombatManager.getCTFromNode(nodeChar)
        local nBaseNPC = DB.getValue(nodeCT, "hpbase", 0)
        local rSource = ActorManager.resolveActor(nodeCT)
        local aHPAddDice, nHPAddMod, nHPEffectCount = EffectManager5E.getEffectsBonus(rSource, {"HP"}, false, {})
        local nTotalNPC = nBaseNPC + nHPAddMod
        DB.setValue(nodeCT, "hptotal", "number", nTotalNPC)
    else
        local nBase = DB.getValue(nodeChar, "hp.base", 0)
        local nBaseMod = DB.getValue(nodeChar, "hp.basemod", 0)
        local nAdj = DB.getValue(nodeChar, "hp.adjustment", 0)
        local nTemp = DB.getValue(nodeChar, "hp.tempmod", 0)
        -- we dont use nBaseMod yet but... if we do later (effects?) this will
        -- make it work properly, if greater than 0 then use it.
        if (nBaseMod > 0) then
            nBase = nBaseMod
        end
        local nConMod = CharManager.getAllClassAndLevelConAdjustments(nodeChar)
        --Debug.console("manager_char.lua","updateHealthScore","nConMod",nConMod);
        if (nConMod == nil) then
            -- we didn't find all our classes, module not loaded?
            -- so we just keep the value currently set
            nConMod = DB.getValue(nodeChar, "hp.conmod", 0)
        else
            DB.setValue(nodeChar, "hp.conmod", "number", nConMod)
        end

        local rSource = ActorManager.resolveActor(CombatManager.getCTFromNode(nodeChar))
        local aHPAddDice, nHPAddMod, nHPEffectCount = EffectManager5E.getEffectsBonus(rSource, {"HP"}, false, {})
        local nTotal = nBase + nConMod + nAdj + nTemp + nHPAddMod
        --Debug.console("manager_char.lua","updateHealthScore","bNPC",bNPC);
        --Debug.console("manager_char.lua","updateHealthScore","nodeChar",nodeChar);

        DB.setValue(nodeChar, "hp.total", "number", nTotal)
    end
end
