if CLIENT then return end

KTNE_ExplosionSupport = KTNE_ExplosionSupport or {}

local Support = KTNE_ExplosionSupport
local METER_TO_UNITS = 52.4934

Support.METER_TO_UNITS = METER_TO_UNITS
Support.ActiveInevitable = Support.ActiveInevitable or {}
Support.BurnStates = Support.BurnStates or {}
Support.EmpStates = Support.EmpStates or {}

local MAP_ZONES = {
    ["rp_anaxes_ifn_v7"] = {
        {id = "onderan", name = "Onderan", corner1 = Vector(-14099.535156, -14715.342773, -5201.245117), corner2 = Vector(12494.081055, 14425.576172, -14622.777344)},
        {id = "tat", name = "Tat", corner1 = Vector(15627.894531, 15256.582031, 2192.282715), corner2 = Vector(-14927.565430, -15269.431641, -3934.759033)},
        {id = "kash", name = "Kash", corner1 = Vector(-1349.966919, 937.933105, 10452.807617), corner2 = Vector(-15449.141602, -15529.950195, 3203.356201)},
        {id = "senate", name = "Senate", corner1 = Vector(-2132.462402, 6272.985352, 9215.166016), corner2 = Vector(-13833.630859, 12170.401367, 4706.157227)},
    },
}

local PROFILES = {
    DETPACK = {
        mode = "immediate",
        sound = "BaseExplosionEffect.Sound",
    },
    EMP = {
        mode = "immediate",
        sound = "ambient/energy/newspark08.wav",
    },
    INCENDIARY = {
        mode = "immediate",
        sound = "ambient/fire/ignite.wav",
    },
    SEISMIC = {
        mode = "immediate",
        sound = "slave1/seismiccharge.wav",
    },
    ABBERANT = {
        mode = "inevitable",
        id = "abberant",
        radius = 500 * METER_TO_UNITS,
        duration = 90,
        startSound = "ambient/gas/steam2.wav",
        finalSound = "ambient/explosions/explode_8.wav",
        shakeDuration = 5,
        shakeAmplitude = 18,
        shakeFrequency = 120,
    },
    PKB = {
        mode = "inevitable",
        id = "pkb",
        radius = math.huge,
        duration = 120,
        startSound = "physics/concrete/boulder_impact_hard4.wav",
        startSoundRepeats = 10,
        startSoundInterval = 0.5,
        finalSound = "ambient/explosions/explode_9.wav",
        shakeDuration = 5,
        shakeAmplitude = 28,
        shakeFrequency = 150,
    },
}

local function metersToUnits(value)
    return value * METER_TO_UNITS
end

local function normalizeMapName(name)
    return string.lower(tostring(name or ""))
end

local function pointInZone(pos, zone)
    local minX = math.min(zone.corner1.x, zone.corner2.x)
    local maxX = math.max(zone.corner1.x, zone.corner2.x)
    local minY = math.min(zone.corner1.y, zone.corner2.y)
    local maxY = math.max(zone.corner1.y, zone.corner2.y)
    local minZ = math.min(zone.corner1.z, zone.corner2.z)
    local maxZ = math.max(zone.corner1.z, zone.corner2.z)
    return pos.x >= minX and pos.x <= maxX
        and pos.y >= minY and pos.y <= maxY
        and pos.z >= minZ and pos.z <= maxZ
end

local function getZonesForCurrentMap()
    return MAP_ZONES[normalizeMapName(game.GetMap())]
end

local function mapHasZoneRules()
    local zones = getZonesForCurrentMap()
    return istable(zones) and #zones > 0
end


local function getZoneIdForPos(pos)
    local zones = getZonesForCurrentMap()
    if not zones then return nil end
    for _, zone in ipairs(zones) do
        if pointInZone(pos, zone) then
            return zone.id
        end
    end
    return nil
end

local function isDebugExplosion(ent)
    return IsValid(ent) and (ent.KTNEDebugOnePlayer == true or (ent.GetNWBool and ent:GetNWBool("KTNE_DebugOnePlayer", false) == true))
end

local function getProfile(ent)
    if not IsValid(ent) then return nil end
    return PROFILES[string.upper(tostring(ent.MakeName or ""))]
end

local function buildDamage(attacker, inflictor, amount, damageType)
    local dmg = DamageInfo()
    dmg:SetDamage(amount)
    dmg:SetDamageType(damageType or DMG_BLAST)
    dmg:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
    dmg:SetInflictor(IsValid(inflictor) and inflictor or game.GetWorld())
    return dmg
end

local function damagePlayer(ply, ent, amount, damageType)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    ply:TakeDamageInfo(buildDamage(ent, ent, amount, damageType))
end

local function killPlayer(ply, ent, damageType)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    damagePlayer(ply, ent, 100000, damageType or DMG_BLAST)
end

local function isSkyOnlyBlastPathOpen(ent, targetPos, targetEnt)
    if not util.IsInWorld(targetPos) then return false end
    local trace = util.TraceLine({
        start = ent:WorldSpaceCenter(),
        endpos = targetPos,
        filter = ent,
        mask = MASK_SOLID_BRUSHONLY,
    })
    if trace.HitSky then return false end
    if trace.Hit and trace.HitWorld and IsValid(targetEnt) then
        local sharesPVS = true
        if ent.TestPVS then
            sharesPVS = ent:TestPVS(targetEnt)
        end
        if sharesPVS and targetEnt.TestPVS then
            sharesPVS = targetEnt:TestPVS(ent)
        end
        if not sharesPVS then
            return false
        end
    end
    return true
end

local function isInevitableBlastPathOpen(ent, targetPos, targetEnt)
    return isSkyOnlyBlastPathOpen(ent, targetPos, targetEnt)
end

local function isPlayerAffectedByZoneRule(ent, ply, profile)
    local zones = getZonesForCurrentMap()
    if not zones or not IsValid(ent) or not IsValid(ply) then return nil end

    local entZone = getZoneIdForPos(ent:GetPos())
    if not entZone then
        return nil
    end

    local plyZone = getZoneIdForPos(ply:GetPos())
    if not plyZone then
        return false
    end

    if profile.id == "pkb" then
        return entZone == plyZone
    end

    if profile.id == "abberant" then
        local radius = tonumber(profile.radius or 0) or 0
        if radius > 0 and ent:GetPos():DistToSqr(ply:WorldSpaceCenter()) > (radius * radius) then
            return false
        end
        return entZone == plyZone
    end

    return nil
end

local function isWorldBlockedBlastPathOpen(ent, targetPos)
    if not util.IsInWorld(targetPos) then return false end
    local trace = util.TraceLine({
        start = ent:WorldSpaceCenter(),
        endpos = targetPos,
        filter = ent,
        mask = MASK_SOLID_BRUSHONLY,
    })
    if trace.HitSky then return false end
    if trace.Hit and trace.HitWorld then return false end
    return true
end

local function sharesBlastPVS(ent, targetEnt)
    if not IsValid(ent) or not IsValid(targetEnt) then return false end
    local sharesPVS = true
    if ent.TestPVS then
        sharesPVS = ent:TestPVS(targetEnt)
    end
    if sharesPVS and targetEnt.TestPVS then
        sharesPVS = targetEnt:TestPVS(ent)
    end
    return sharesPVS
end

local function isPlayerInBlastRange(ent, ply, radius, pathCheck)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    local targetPos = ply:WorldSpaceCenter()
    if radius ~= math.huge and ent:GetPos():DistToSqr(targetPos) > (radius * radius) then
        return false
    end
    return (pathCheck or isSkyOnlyBlastPathOpen)(ent, targetPos, ply)
end

local function playersInRadius(ent, radius, pathCheck)
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if isPlayerInBlastRange(ent, ply, radius, pathCheck) then
            out[#out + 1] = ply
        end
    end
    return out
end

local function playersWithinMeters(ent, meters)
    local out = {}
    local radius = metersToUnits(meters)
    local radiusSqr = radius * radius
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() and ent:GetPos():DistToSqr(ply:WorldSpaceCenter()) <= radiusSqr then
            out[#out + 1] = ply
        end
    end
    return out
end

local function affectedByInfiniteBlast(ent)
    local out = {}
    local profile = getProfile(ent)
    for _, ply in ipairs(player.GetAll()) do
        local zoneDecision = profile and isPlayerAffectedByZoneRule(ent, ply, profile) or nil
        local affected = zoneDecision
        if affected == nil and not mapHasZoneRules() then
            affected = IsValid(ply) and ply:IsPlayer() and ply:Alive()
        end
        if affected then
            out[#out + 1] = ply
        end
    end
    return out
end

local function playersAffectedByInevitable(ent, profile)
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
            local zoneDecision = isPlayerAffectedByZoneRule(ent, ply, profile)
            local affected = zoneDecision
            if affected == nil and not mapHasZoneRules() then
                local radius = tonumber(profile.radius or 0) or 0
                affected = radius > 0 and ent:GetPos():DistToSqr(ply:WorldSpaceCenter()) <= (radius * radius)
            end
            if affected then
                out[#out + 1] = ply
            end
        end
    end
    return out
end

local function getAffectedPlayersForState(ent, state)
    if not IsValid(ent) or not state or not state.profile then return {} end
    if state.profile.radius == math.huge then
        return affectedByInfiniteBlast(ent)
    end
    return playersAffectedByInevitable(ent, state.profile)
end

local function playExplosionEffect(ent, soundName)
    local effect = EffectData()
    effect:SetOrigin(ent:GetPos())
    util.Effect("Explosion", effect, true, true)
    ent:EmitSound(soundName or "BaseExplosionEffect.Sound", 140, 100, 1, CHAN_STATIC)
end

local function playLargeAbberantExplosion(ent, soundName)
    local origin = ent:GetPos()

    local primary = EffectData()
    primary:SetOrigin(origin)
    primary:SetScale(12.2)
    primary:SetMagnitude(18)
    primary:SetRadius(1520)
    util.Effect("Explosion", primary, true, true)

    local secondary = EffectData()
    secondary:SetOrigin(origin + Vector(0, 0, 40))
    secondary:SetScale(11.8)
    secondary:SetMagnitude(18)
    util.Effect("HelicopterMegaBomb", secondary, true, true)

    local shock = EffectData()
    shock:SetOrigin(origin)
    shock:SetScale(6.6)
    util.Effect("cball_explode", shock, true, true)

    local shockwave = EffectData()
    shockwave:SetOrigin(origin + Vector(0, 0, 12))
    shockwave:SetScale(8.6)
    shockwave:SetMagnitude(14)
    util.Effect("ThumperDust", shockwave, true, true)

    local flare = EffectData()
    flare:SetOrigin(origin + Vector(0, 0, 24))
    flare:SetScale(7.4)
    flare:SetMagnitude(10)
    util.Effect("AR2Explosion", flare, true, true)

    local flareBurst = EffectData()
    flareBurst:SetOrigin(origin + Vector(0, 0, 30))
    flareBurst:SetScale(6.2)
    util.Effect("GlassImpact", flareBurst, true, true)

    local blast = ents.Create("env_explosion")
    if IsValid(blast) then
        blast:SetPos(origin)
        blast:SetOwner(ent)
        blast:SetKeyValue("iMagnitude", "680")
        blast:SetKeyValue("iRadiusOverride", "1180")
        blast:SetKeyValue("spawnflags", "64")
        blast:Spawn()
        blast:Fire("Explode", "", 0)
    end

    ent:EmitSound(soundName or "ambient/explosions/explode_8.wav", 160, 90, 1, CHAN_STATIC)
end

local function stopSoundPatch(patch)
    if patch then
        patch:Stop()
    end
end

local function stopPlayerSirenState(sirenState)
    if not sirenState then return end
    stopSoundPatch(sirenState.patch)
end

local function soundDurationOrZero(soundName)
    local duration = SoundDuration and SoundDuration(soundName) or 0
    return (duration and duration > 0) and duration or 0
end

local function playPlayerSirenSound(ply, soundName)
    local patch = CreateSound(ply, soundName)
    if patch then
        patch:PlayEx(1, 100)
    else
        ply:EmitSound(soundName, 100, 100, 1, CHAN_STATIC)
    end
    return patch, soundDurationOrZero(soundName)
end

local function stopEntityEffects(ent)
    if not IsValid(ent) then return end
    local state = Support.ActiveInevitable[ent]
    if state then
        stopSoundPatch(state.startPatch)
        if state.startTimerId then
            timer.Remove(state.startTimerId)
        end
        for ply, sirenState in pairs(state.playerSirenPatches or {}) do
            stopPlayerSirenState(sirenState)
            state.playerSirenPatches[ply] = nil
        end
    end
    if IsValid(ent._KTNESmokeStack) then
        ent._KTNESmokeStack:Remove()
    end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() and ply:GetNWEntity("KTNE_InevitableFocus") == ent then
            ply:SetNWEntity("KTNE_InevitableFocus", NULL)
        end
    end
    ent:SetNWBool("KTNE_Inevitable", false)
    ent:SetNWFloat("KTNE_InevitableDeadline", 0)
    ent:SetNWFloat("KTNE_InevitableRadius", 0)
    ent:SetNWString("KTNE_InevitableType", "")
end

local function spawnGroundFire(origin, duration)
    local fire = ents.Create("env_fire")
    if not IsValid(fire) then return end
    fire:SetPos(origin + Vector(0, 0, 4))
    fire:SetKeyValue("health", "30")
    fire:SetKeyValue("firesize", "128")
    fire:SetKeyValue("fireattack", "1")
    fire:SetKeyValue("damagescale", "0")
    fire:SetKeyValue("spawnflags", "132")
    fire:Spawn()
    fire:Activate()
    fire:Fire("StartFire", "", 0)
    timer.Simple(duration, function()
        if IsValid(fire) then
            fire:Remove()
        end
    end)
end

local function applyBurn(ply, ent, duration, interval, damage)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    Support.BurnStates[ply] = {
        attacker = ent,
        interval = interval,
        damage = damage,
        nextTick = CurTime() + interval,
        untilTime = CurTime() + duration,
    }
    ply:Ignite(duration, 0)
end

local function applyEmp(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply:SetArmor(0)
    ply:SetNWFloat("KTNE_EmpSlowUntil", CurTime() + 15)
    Support.EmpStates[ply] = {
        attacker = ent,
        interval = 1,
        damage = 15,
        nextTick = CurTime() + 1,
        untilTime = CurTime() + 15,
    }
    ply:EmitSound("ambient/energy/newspark08.wav", 75, 100, 1, CHAN_AUTO)
end

local function applyNoJump(ply, duration)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply:SetNWFloat("KTNE_NoJumpUntil", math.max(ply:GetNWFloat("KTNE_NoJumpUntil", 0), CurTime() + duration))
end

local function applyDetpackBlast(ent)
    playExplosionEffect(ent, PROFILES.DETPACK.sound)
    for _, ply in ipairs(playersInRadius(ent, metersToUnits(12), function() return true end)) do
        local meters = ent:GetPos():Distance(ply:GetPos()) / METER_TO_UNITS
        if meters <= 3 then
            damagePlayer(ply, ent, 2000, DMG_BLAST)
        elseif meters <= 12 then
            local frac = math.Clamp((meters - 4) / 8, 0, 1)
            damagePlayer(ply, ent, Lerp(frac, 125, 12.5), DMG_BLAST)
        end
    end
end

local function applyIncendiaryBlast(ent)
    playExplosionEffect(ent, PROFILES.INCENDIARY.sound)
    spawnGroundFire(ent:GetPos(), 7)
    local affected = {}
    for _, ply in ipairs(playersInRadius(ent, metersToUnits(20), isWorldBlockedBlastPathOpen)) do
        affected[ply] = true
    end
    for _, ply in ipairs(playersWithinMeters(ent, 7)) do
        affected[ply] = true
    end
    for ply in pairs(affected) do
        applyBurn(ply, ent, 7, 0.25, 25)
    end
end

local function applyEmpBlast(ent)
    playExplosionEffect(ent, PROFILES.EMP.sound)
    local affected = {}
    for _, ply in ipairs(playersInRadius(ent, metersToUnits(20), isWorldBlockedBlastPathOpen)) do
        affected[ply] = true
    end
    for _, ply in ipairs(playersWithinMeters(ent, 7)) do
        affected[ply] = true
    end
    for ply in pairs(affected) do
        applyEmp(ply, ent)
    end
end

local function applySeismicBlast(ent)
    local effect = EffectData()
    effect:SetOrigin(ent:GetPos())
    util.Effect("Explosion", effect, true, true)
    util.ScreenShake(ent:GetPos(), 25, 150, 3, metersToUnits(100))
    local affectedPlayers = playersInRadius(ent, metersToUnits(100), isSkyOnlyBlastPathOpen)
    for _, ply in ipairs(affectedPlayers) do
        ply:EmitSound(PROFILES.SEISMIC.sound, 100, 100, 1, CHAN_STATIC)
    end
    for _, ply in ipairs(affectedPlayers) do
        local meters = ent:GetPos():Distance(ply:GetPos()) / METER_TO_UNITS
        if meters <= 40 then
            killPlayer(ply, ent, DMG_SONIC)
        else
            damagePlayer(ply, ent, Lerp(math.Clamp((meters - 40) / 60, 0, 1), 2000, 500), DMG_SONIC)
            if IsValid(ply) and ply:Alive() then
                applyNoJump(ply, 120)
            end
        end
    end
end

local function closeUiForPlayers(ent)
    local recipients, seen = {}, {}
    for _, ply in ipairs({ent.PanelPlayer, ent.ManualPlayer}) do
        if IsValid(ply) and not seen[ply] then
            seen[ply] = true
            recipients[#recipients + 1] = ply
        end
    end
    if #recipients == 0 then return end

    local closeNet = string.find(ent:GetClass(), "_solo", 1, true) and "ktne_close_ui_solo" or "ktne_close_ui_mp"
    net.Start(closeNet)
        net.WriteEntity(ent)
    net.Send(recipients)
end

local function createSmokeStack(ent)
    if IsValid(ent._KTNESmokeStack) then return end
    local smoke = ents.Create("env_smokestack")
    if not IsValid(smoke) then return end
    smoke:SetPos(ent:GetPos() + Vector(0, 0, 16))
    smoke:SetParent(ent)
    smoke:SetKeyValue("InitialState", "1")
    smoke:SetKeyValue("BaseSpread", "14")
    smoke:SetKeyValue("SpreadSpeed", "18")
    smoke:SetKeyValue("Speed", "30")
    smoke:SetKeyValue("StartSize", "12")
    smoke:SetKeyValue("EndSize", "52")
    smoke:SetKeyValue("Rate", "26")
    smoke:SetKeyValue("JetLength", "84")
    smoke:SetKeyValue("twist", "4")
    smoke:SetKeyValue("rendercolor", "140 150 140")
    smoke:SetKeyValue("renderamt", "180")
    smoke:Spawn()
    smoke:Activate()
    ent._KTNESmokeStack = smoke
end

local function createDetonationCloud(origin, renderColor, renderAmt)
    local smoke = ents.Create("env_smokestack")
    if not IsValid(smoke) then return end
    smoke:SetPos(origin + Vector(0, 0, 24))
    smoke:SetKeyValue("InitialState", "1")
    smoke:SetKeyValue("BaseSpread", "2200")
    smoke:SetKeyValue("SpreadSpeed", "40")
    smoke:SetKeyValue("Speed", "10")
    smoke:SetKeyValue("StartSize", "2200")
    smoke:SetKeyValue("EndSize", "5250")
    smoke:SetKeyValue("Rate", "42")
    smoke:SetKeyValue("JetLength", "1840")
    smoke:SetKeyValue("twist", "10")
    smoke:SetKeyValue("rendercolor", renderColor or "36 36 36")
    smoke:SetKeyValue("renderamt", tostring(renderAmt or 110))
    smoke:Spawn()
    smoke:Activate()
    timer.Simple(30, function()
        if IsValid(smoke) then
            smoke:Remove()
        end
    end)
end

local function updatePlayerSirenPatches(ent, state)
    state.playerSirenPatches = state.playerSirenPatches or {}
    if not state.profile.sirenSound or state.profile.sirenSound == "" then
        for ply, sirenState in pairs(state.playerSirenPatches) do
            stopPlayerSirenState(sirenState)
            state.playerSirenPatches[ply] = nil
        end
        return
    end
    local now = CurTime()
    local targetPlayers = getAffectedPlayersForState(ent, state)
    local shouldHear = {}

    for _, ply in ipairs(targetPlayers) do
        shouldHear[ply] = true
        if not state.playerSirenPatches[ply] then
            local patch, duration = playPlayerSirenSound(ply, state.profile.sirenSound)
            state.playerSirenPatches[ply] = {
                patch = patch,
                currentSound = state.profile.sirenSound,
                secondaryStarted = false,
                nextChange = duration > 0 and (now + duration - 0.05) or nil,
            }
        else
            local sirenState = state.playerSirenPatches[ply]
            if sirenState.nextChange and now >= sirenState.nextChange then
                local nextSound = sirenState.currentSound
                if (not sirenState.secondaryStarted) and state.profile.secondarySirenSound then
                    nextSound = state.profile.secondarySirenSound
                    sirenState.secondaryStarted = true
                end
                stopSoundPatch(sirenState.patch)
                local patch, duration = playPlayerSirenSound(ply, nextSound)
                sirenState.patch = patch
                sirenState.currentSound = nextSound
                sirenState.nextChange = duration > 0 and (now + duration - 0.05) or nil
            end
        end
    end

    for ply, sirenState in pairs(state.playerSirenPatches) do
        if not shouldHear[ply] or not IsValid(ply) or not ply:Alive() then
            stopPlayerSirenState(sirenState)
            state.playerSirenPatches[ply] = nil
        end
    end
end

function Support.RunFailureEffects(ent, reason)
    local profile = getProfile(ent)
    if not profile or profile.mode ~= "immediate" or isDebugExplosion(ent) then
        return false
    end

    if profile == PROFILES.DETPACK then
        applyDetpackBlast(ent)
    elseif profile == PROFILES.INCENDIARY then
        applyIncendiaryBlast(ent)
    elseif profile == PROFILES.EMP then
        applyEmpBlast(ent)
    elseif profile == PROFILES.SEISMIC then
        applySeismicBlast(ent)
    else
        return false
    end

    return true
end

function Support.TryBeginInevitable(ent, reason)
    local profile = getProfile(ent)
    if not profile or profile.mode ~= "inevitable" or isDebugExplosion(ent) then
        return false
    end
    if Support.ActiveInevitable[ent] then
        return true
    end

    ent.RoundEnding = true
    if ent.SetGameActive then ent:SetGameActive(false) end
    if ent.SetTimeRemaining then ent:SetTimeRemaining(0) end
    closeUiForPlayers(ent)

    local deadline = CurTime() + profile.duration
    local state = {
        deadline = deadline,
        profile = profile,
        reason = reason or "Detonation inevitable!",
        playerSirenPatches = {},
    }
    Support.ActiveInevitable[ent] = state

    ent:SetNWBool("KTNE_Inevitable", true)
    ent:SetNWFloat("KTNE_InevitableDeadline", deadline)
    ent:SetNWFloat("KTNE_InevitableRadius", profile.radius == math.huge and -1 or profile.radius)
    ent:SetNWString("KTNE_InevitableType", profile.id)

    if profile.id == "abberant" then
        createSmokeStack(ent)
    end

    if profile.startSoundRepeats and profile.startSoundInterval then
        ent:EmitSound(profile.startSound, 90, 100, 1, CHAN_STATIC)
        local repeats = math.max(0, profile.startSoundRepeats - 1)
        if repeats > 0 then
            state.startTimerId = "KTNE_StartSound_" .. ent:EntIndex()
            timer.Create(state.startTimerId, profile.startSoundInterval, repeats, function()
                if IsValid(ent) then
                    ent:EmitSound(profile.startSound, 90, 100, 1, CHAN_STATIC)
                end
            end)
        end
    else
        state.startPatch = CreateSound(ent, profile.startSound)
        if state.startPatch then
            state.startPatch:PlayEx(1, 100)
        else
            ent:EmitSound(profile.startSound, 90, 100, 1, CHAN_STATIC)
        end
    end

    if ent.NotifyPlayers then
        ent:NotifyPlayers(reason or "Detonation inevitable!")
    end

    return true
end

local function finalizeInevitable(ent, state)
    if not IsValid(ent) then return end

    local origin = ent:GetPos()
    stopEntityEffects(ent)
    Support.ActiveInevitable[ent] = nil

    local targets = getAffectedPlayersForState(ent, state)
    if state.profile.shakeDuration and state.profile.shakeDuration > 0 then
        local shakeRadius = state.profile.radius == math.huge and 32768 or state.profile.radius
        util.ScreenShake(ent:GetPos(), state.profile.shakeAmplitude or 18, state.profile.shakeFrequency or 120, state.profile.shakeDuration, shakeRadius)
    end
    for _, ply in ipairs(targets) do
        killPlayer(ply, ent, DMG_BLAST)
    end

    if state.profile.id == "abberant" then
        playLargeAbberantExplosion(ent, state.profile.finalSound)
        createDetonationCloud(origin, "36 36 36", 110)
    elseif state.profile.id == "pkb" then
        playExplosionEffect(ent, state.profile.finalSound)
        createDetonationCloud(origin, "28 28 28", 125)
    else
        playExplosionEffect(ent, state.profile.finalSound)
    end

    timer.Simple(0.9, function()
        if IsValid(ent) then
            ent:Remove()
        end
    end)
end

hook.Add("Think", "KTNE_ExplosionSupport_Think", function()
    local now = CurTime()
    local desiredFocus = {}

    for ply, state in pairs(Support.BurnStates) do
        if not IsValid(ply) then
            Support.BurnStates[ply] = nil
        elseif now >= state.untilTime then
            if ply:IsOnFire() then ply:Extinguish() end
            Support.BurnStates[ply] = nil
        elseif now >= state.nextTick then
            state.nextTick = state.nextTick + state.interval
            damagePlayer(ply, state.attacker, state.damage, DMG_BURN)
        end
    end

    for ply, state in pairs(Support.EmpStates) do
        if not IsValid(ply) then
            Support.EmpStates[ply] = nil
        elseif now >= state.untilTime then
            ply:SetNWFloat("KTNE_EmpSlowUntil", 0)
            Support.EmpStates[ply] = nil
        elseif now >= state.nextTick then
            state.nextTick = state.nextTick + state.interval
            damagePlayer(ply, state.attacker, state.damage, DMG_SHOCK)
        end
    end

    for ent, state in pairs(Support.ActiveInevitable) do
        if not IsValid(ent) then
            Support.ActiveInevitable[ent] = nil
        elseif now >= state.deadline then
            finalizeInevitable(ent, state)
        else
            for _, ply in ipairs(getAffectedPlayersForState(ent, state)) do
                if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
                    local current = desiredFocus[ply]
                    if not current or state.deadline < current.deadline then
                        desiredFocus[ply] = {ent = ent, deadline = state.deadline}
                    end
                end
            end
            updatePlayerSirenPatches(ent, state)
        end
    end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() then
            local focus = desiredFocus[ply]
            ply:SetNWEntity("KTNE_InevitableFocus", focus and IsValid(focus.ent) and focus.ent or NULL)
        end
    end
end)

hook.Add("SetupMove", "KTNE_ExplosionSupport_SetupMove", function(ply, mv)
    if ply:GetNWFloat("KTNE_EmpSlowUntil", 0) > CurTime() then
        mv:SetMaxSpeed(mv:GetMaxSpeed() * 0.5)
        mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * 0.5)
    end
    if ply:GetNWFloat("KTNE_NoJumpUntil", 0) > CurTime() then
        mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
        if mv:GetVelocity().z > 0 then
            mv:SetVelocity(Vector(mv:GetVelocity().x, mv:GetVelocity().y, 0))
        end
    end
end)

hook.Add("PlayerDeath", "KTNE_ExplosionSupport_ClearDebuffs", function(ply)
    Support.BurnStates[ply] = nil
    Support.EmpStates[ply] = nil
    ply:SetNWFloat("KTNE_EmpSlowUntil", 0)
    ply:SetNWFloat("KTNE_NoJumpUntil", 0)
end)

hook.Add("EntityRemoved", "KTNE_ExplosionSupport_Cleanup", function(ent)
    if Support.ActiveInevitable[ent] then
        Support.ActiveInevitable[ent] = nil
    end
    stopEntityEffects(ent)
end)
