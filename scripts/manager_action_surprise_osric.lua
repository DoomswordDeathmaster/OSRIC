function onInit()
    --ActionSurprise.getRoll = getRollOsric
    ActionSurprise.performRoll = performRollOsric
end

function performRollOsric(draginfo, rActor, nTargetDC, bSecretRoll)
    local rRoll = getRollOsric(rActor, nTargetDC, bSecretRoll)

    ActionsManager.performAction(draginfo, rActor, rRoll)
end

function getRollOsric(rActor, nTargetDC, bSecretRoll)
    --DataCommonADND.aDefaultSurpriseDice = {"d6"}

    local rRoll = {}
    rRoll.sType = "surprise"
    rRoll.nMod = 0

    --local aDice = DB.getValue(nodeChar, "surprise.dice")

    --if aDice == nil then
        local aDice = DataCommonADND.aDefaultSurpriseDice
        --Debug.console("aDice", aDice)
    --end

    rRoll.aDice = aDice

    if (nTargetDC == nil) then
        -- local node = CombatManagerADND.getCTFromActor(rActor)
        -- nTargetDC = getSurpriseTarget(node)

        local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor)
        --Debug.console("33", "sActorType", sActorType, "nodeActor", nodeActor)

        if sActorType == "pc" then
            --local node = ActorManager.getCTNode(rActor);
            nTargetDC = getSurpriseTarget("pc", nodeActor)
        else
            local node = ActorManager.getCTNode(rActor);
            --Debug.console("node", node)
    	    nTargetDC = getSurpriseTarget("npc", node)
            --local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor)
            --node = nodeActor
        --else
            --node = nodeCT
        end
    end

    rRoll.sDesc = "[CHECK] "
    rRoll.bSecret = bSecretRoll
    rRoll.nTarget = nTargetDC

    return rRoll
end

-- return the current surprise value for this target.
function getSurpriseTarget(sActorType, node)
    -- deal with setting surprise based on surprise die
    local nSurpriseBase = DataCommonOsric.nSurpriseBase
    local nBase = nil
    --Debug.console("61", "sActorType", sActorType)

    if sActorType == "pc" then
        nBase = DB.getValue(node, "surprise.total")
        --Debug.console("65", "sActorType", sActorType, "node", node, "PC", "nSurpriseBase", nSurpriseBase, "nBase", nBase)
    else
        nBase = DB.getValue(node, "surprise.base")
        --Debug.console("68", "sActorType", sActorType, "node", node, "NPC", "nSurpriseBase", nSurpriseBase, "nBase", nBase)
    end

    -- d12 from advanced combat option, double the module surprise base
    if nSurpriseBase == 4 and nBase ~= 4 then
        nBase = nBase * 2
    end

    --Debug.console("nSurpriseBase", nSurpriseBase, "nBase", nBase)
    -- probably don't need this
    -- if > 2 then set to 2 - need to probably handle this better
    -- if nBase > nSurpriseBase then
    --     nBase = DB.getValue(node, "surprise.base", nSurpriseBase)
    -- end

    local nMod = DB.getValue(node, "surprise.mod", 0)
    local nTmpMod = DB.getValue(node, "surprise.tempmod", 0)
    local nTotal = nBase + nMod + nTmpMod

    return nTotal
end
