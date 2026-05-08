local trackedClasses = {
    "sent_ktne_bomb",
    "sent_ktne_abberant_mp",
    "sent_ktne_pkb_mp",
    "sent_ktne_seismic_mp",
    "sent_ktne_bomb_solo",
    "sent_ktne_detpack_solo",
    "sent_ktne_emp_solo",
    "sent_ktne_incendiary_solo",
}

local function eachTrackedBomb(fn)
    for _, className in ipairs(trackedClasses) do
        for _, ent in ipairs(ents.FindByClass(className)) do
            if IsValid(ent) then
                fn(ent)
            end
        end
    end
end

local function releasePlayerFromBombs(ply, includeSpawn)
    if not IsValid(ply) then return end

    eachTrackedBomb(function(ent)
        if ent.ReleasePlayer then
            ent:ReleasePlayer(ply, {skipClose = not includeSpawn})
        end
    end)
end

local function playerHasTrackedBombUi(ply)
    if not IsValid(ply) then return false end

    local hasUi = false
    eachTrackedBomb(function(ent)
        if hasUi then return end
        if ent.PanelPlayer == ply or ent.ManualPlayer == ply then
            hasUi = true
        end
    end)
    return hasUi
end

local function clearStaleClaimsForPlayer(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64() or ""
    if sid == "" then return end

    eachTrackedBomb(function(ent)
        if ent.ReleasePlayerBySID then
            local changed = ent:ReleasePlayerBySID(sid)
            if changed and ent.SyncState then
                ent:SyncState(true)
            end
        end
    end)
end

hook.Add("PlayerDeath", "KTNE_PlayerSlots_DeathRelease", function(ply)
    releasePlayerFromBombs(ply, false)
end)

hook.Add("PlayerDisconnected", "KTNE_PlayerSlots_DisconnectRelease", function(ply)
    releasePlayerFromBombs(ply, false)
end)

hook.Add("PlayerSpawn", "KTNE_PlayerSlots_SpawnRelease", function(ply)
    releasePlayerFromBombs(ply, true)
end)

hook.Add("PlayerInitialSpawn", "KTNE_PlayerSlots_InitialSpawnCleanup", function(ply)
    clearStaleClaimsForPlayer(ply)
end)

hook.Add("SetupMove", "KTNE_PlayerSlots_BlockMovementWhileInUi", function(ply, mv, cmd)
    if not playerHasTrackedBombUi(ply) then return end

    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
    mv:SetUpSpeed(0)

    local buttons = mv:GetButtons()
    local blocked = bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_JUMP, IN_DUCK, IN_SPEED, IN_WALK, IN_USE)
    buttons = bit.band(buttons, bit.bnot(blocked))
    mv:SetButtons(buttons)

    if cmd then
        cmd:SetForwardMove(0)
        cmd:SetSideMove(0)
        cmd:SetUpMove(0)
        cmd:SetButtons(buttons)
    end
end)
