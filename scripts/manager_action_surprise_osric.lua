function onInit()
    --ActionSurprise.getRoll = getRollOsric
    ActionSurprise.performRoll = performRollOsric
end

function performRollOsric(draginfo, rActor, nTargetDC, bSecretRoll)
    local rRoll = getRollOsric(rActor, nTargetDC, bSecretRoll)

    ActionsManager.performAction(draginfo, rActor, rRoll)
end

function getRollOsric(rActor, nTargetDC, bSecretRoll)
    DataCommonADND.aDefaultSurpriseDice = {"d6"}

    local rRoll = {}
    rRoll.sType = "surprise"
    rRoll.nMod = 0

    local aDice = DB.getValue(nodeChar, "surprise.dice")

    if aDice == nil then
        aDice = DataCommonADND.aDefaultSurpriseDice
    end

    rRoll.aDice = aDice

    if (nTargetDC == nil) then
        -- local node = CombatManagerADND.getCTFromActor(rActor)
        -- nTargetDC = getSurpriseTarget(node)
        local nodeCT = ActorManager.getCTNode(rActor);
    	nTargetDC = getSurpriseTarget(nodeCT);
    end

    rRoll.sDesc = "[CHECK] "
    rRoll.bSecret = bSecretRoll
    rRoll.nTarget = nTargetDC

    return rRoll
end

-- return the current surprise value for this target.
function getSurpriseTarget(node)
    -- hardcode to 2 if > 2
    -- TODO: get these set correctly
    -- set to 2 if nothing returned
    local nBase = DB.getValue(node, "surprise.base", 2)

    -- if > 2 then set to 2 - need to probably handle this better
    if nBase > 2 then
        nBase = DB.getValue(node, "surprise.base", 2)
    end

    local nMod = DB.getValue(node, "surprise.mod", 0)
    local nTmpMod = DB.getValue(node, "surprise.tempmod", 0)
    local nTotal = nBase + nMod + nTmpMod

    return nTotal
end
