function onInit()
    ActorHealthManager.getWoundPercent = getWoundPercentOsric
end

function getWoundPercentOsric(rActor)
    --Debug.console("manager_actor_helth_osric.lua 7", "getWoundPercentOsric")
    -- local rActor = ActorManager.resolveActor(node);
    -- local node = ActorManager.getCreatureNode(rActor);
    local sNodeType, node = ActorManager.getTypeAndNode(rActor)
    local nHP = 0
    local nWounds = 0

    -- Debug.console("manager_actor_adnd.lua","getWoundPercent","sNodeType",sNodeType);
    if sNodeType == "pc" then
        nHP = math.max(DB.getValue(node, "hp.total", 0), 0)
        nWounds = math.max(DB.getValue(node, "hp.wounds", 0), 0)
    elseif sNodeType == "ct" then
        nHP = math.max(DB.getValue(node, "hptotal", 0), 0)
        nWounds = math.max(DB.getValue(node, "wounds", 0), 0)
    end

    local nPercentWounded = 0
    local nCurrentHp = nHP

    if nHP > 0 then
        nPercentWounded = nWounds / nHP
        nCurrentHp = nHP - nWounds
    end

    --local bDeathsDoor = OptionsManager.isOption("HouseRule_DeathsDoor", "on"); -- using deaths door aD&D rule

    local sStatus = ActorHealthManager.STATUS_HEALTHY
    --local nLeftOverHP = (nHP - nWounds)

    -- AD&D goes to -10 then dead with deaths door
    --local nDEAD_AT = -10;

    -- changing death's door options, since it always exists in 1e
    local nDeathDoorThreshold = -9
    local nDEAD_AT = -10

    if nPercentWounded >= 1 then
        if nCurrentHp <= nDEAD_AT then
            sStatus = ActorHealthManager.STATUS_DEAD
        else
            sStatus = ActorHealthManager.STATUS_DYING
        end

        if nCurrentHp < 1 then
            sStatus = sStatus .. " (" .. nCurrentHp .. ")"
        end
    elseif OptionsManager.isOption("WNDC", "detailed") then
        if nPercentWounded >= .75 then
            sStatus = ActorHealthManager.STATUS_CRITICAL
        elseif nPercentWounded >= .5 then
            sStatus = ActorHealthManager.STATUS_HEAVY
        elseif nPercentWounded >= .25 then
            sStatus = ActorHealthManager.STATUS_MODERATE
        elseif nPercentWounded > 0 then
            sStatus = ActorHealthManager.STATUS_LIGHT
        else
            sStatus = ActorHealthManager.STATUS_HEALTHY
        end
    else
        if nPercentWounded >= .5 then
            sStatus = ActorHealthManager.STATUS_SIMPLE_HEAVY
        elseif nPercentWounded > 0 then
            sStatus = ActorHealthManager.STATUS_SIMPLE_WOUNDED
        else
            sStatus = ActorHealthManager.STATUS_HEALTHY
        end
    end

    return nPercentWounded, sStatus
end
