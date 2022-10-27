-- kept the naming convention but this is only for open doors right now, maybe something else later
function performRoll(draginfo, rActor, sCheck, nTargetDC, bSecretRoll, aCheckDice)
    local rRoll = getRoll(rActor, sCheck, nTargetDC, bSecretRoll, aCheckDice)

    ActionsManager.performAction(draginfo, rActor, rRoll)
end

function getRoll(rActor, sCheck, nTargetDC, bSecretRoll, aCheckDice)
    local rRoll = {}

    rRoll.sType = "check"
    rRoll.aDice = {"d6"}

    if aCheckDice then
        rRoll.aDice = aCheckDice
    end

    local nMod, bADV, bDIS, sAddText = ActorManagerADND.getCheck(rActor, sCheck:lower())

    rRoll.nMod = nMod
    rRoll.sDesc = "[CHECK]"
    rRoll.sDesc = rRoll.sDesc .. " " .. StringManager.capitalize(sCheck)

    if sAddText and sAddText ~= "" then
        rRoll.sDesc = rRoll.sDesc .. " " .. sAddText
    end

    if bADV then
        rRoll.sDesc = rRoll.sDesc .. " [ADV]"
    end

    if bDIS then
        rRoll.sDesc = rRoll.sDesc .. " [DIS]"
    end

    rRoll.bSecret = bSecretRoll
    rRoll.nTarget = nTargetDC

    return rRoll
end
