function onInit()
    --ActionSurprise.getRoll = getRollNew
    ActionSurprise.performRoll = performRollNew
end

function performRollNew(draginfo, rActor, nTargetDC, bSecretRoll)
    local rRoll = getRollNew(rActor, nTargetDC, bSecretRoll)

    ActionsManager.performAction(draginfo, rActor, rRoll)
end

function getRollNew(rActor, nTargetDC, bSecretRoll)
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
        local node = CombatManagerADND.getCTFromActor(rActor)
        nTargetDC = getSurpriseTarget(node)
    end

    rRoll.sDesc = "[CHECK] "
    rRoll.bSecret = bSecretRoll
    rRoll.nTarget = nTargetDC

    return rRoll
end

-- return the current surprise value for this target.
function getSurpriseTarget(node)
    -- TODO: look at this more carefully, in terms of surprise base, hardcoded as 2, and the getvalue
    local nBase = DB.getValue(node, "surprise.base", 3)
    local nMod = DB.getValue(node, "surprise.mod", 0)
    local nTmpMod = DB.getValue(node, "surprise.tempmod", 0)
    local nTotal = nBase + nMod + nTmpMod

    return nTotal
end
