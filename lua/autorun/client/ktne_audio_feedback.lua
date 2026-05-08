if SERVER then return end

KTNE_ClientAudio = KTNE_ClientAudio or {}

local Audio = KTNE_ClientAudio
local THEME_LOOP_TIMER = "KTNE_ClientAudio_ThemeLoop"
local THEME_FADE_TIMER = "KTNE_ClientAudio_ThemeFade"
local DEFUSED_FADE_TIMER = "KTNE_ClientAudio_DefusedFade"
local DEFUSED_SOUND = "music/hl1_song25_remix3.mp3"
local MODULE_SOLVED_SOUND = "ifn_keypad/success.ogg"
local STRIKE_SOUND = "ifn_keypad/whirr.ogg"

Audio.Theme = Audio.Theme or {}

function Audio.GetThemeSound(makeName)
    return ""
end

local function stopPatch(patch)
    if patch then
        patch:Stop()
    end
end

local function killTimer(name)
    if timer.Exists(name) then
        timer.Remove(name)
    end
end

local function createPlayerPatch(soundPath, volume)
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    local patch = CreateSound(ply, soundPath)
    if patch then
        patch:PlayEx(volume or 1, 100)
    end
    return patch
end

function Audio.StopTheme()
    killTimer(THEME_LOOP_TIMER)
    killTimer(THEME_FADE_TIMER)
    stopPatch(Audio.Theme.patch)
    Audio.Theme = {}
end

function Audio.StopThemeForEnt(ent)
    if Audio.Theme.ent == ent then
        Audio.StopTheme()
    end
end

function Audio.StartTheme(ent, soundPath, opts)
    opts = opts or {}
    if not IsValid(ent) then return end
    if Audio.Theme.ent == ent and Audio.Theme.soundPath == soundPath then return end

    Audio.StopTheme()
    if not soundPath or soundPath == "" then return end

    local targetVolume = tonumber(opts.volume or 0.65) or 0.65
    local fadeIn = tonumber(opts.fadeIn or 0) or 0
    local initialVolume = fadeIn > 0 and 0 or targetVolume
    local patch = createPlayerPatch(soundPath, initialVolume)

    Audio.Theme = {
        ent = ent,
        patch = patch,
        soundPath = soundPath,
        volume = targetVolume,
        loop = opts.loop == true,
    }

    if patch and fadeIn > 0 then
        local startedAt = CurTime()
        local steps = math.max(1, math.ceil(fadeIn / 0.1))
        timer.Create(THEME_FADE_TIMER, 0.1, steps, function()
            if Audio.Theme.patch ~= patch then
                killTimer(THEME_FADE_TIMER)
                return
            end
            local frac = math.Clamp((CurTime() - startedAt) / fadeIn, 0, 1)
            patch:ChangeVolume(targetVolume * frac, 0)
        end)
    end

    if opts.loop == true then
        local duration = SoundDuration(soundPath) or 0
        if duration > 0 then
            timer.Create(THEME_LOOP_TIMER, math.max(0.25, duration - 0.05), 0, function()
                if Audio.Theme.ent ~= ent or Audio.Theme.soundPath ~= soundPath then
                    killTimer(THEME_LOOP_TIMER)
                    return
                end
                stopPatch(Audio.Theme.patch)
                Audio.Theme.patch = createPlayerPatch(soundPath, targetVolume)
            end)
        end
    end
end

function Audio.PlayUISound(soundPath, volume, pitch, channel)
    local ply = LocalPlayer()
    if not IsValid(ply) or not soundPath or soundPath == "" then return end
    ply:EmitSound(soundPath, 75, pitch or 100, volume or 1, channel or CHAN_AUTO)
end

function Audio.CountSolvedModules(state)
    local count = 0
    for _, solved in pairs((state and state.moduleStatus) or {}) do
        if solved == true then
            count = count + 1
        end
    end
    return count
end

function Audio.ShowDefusedBanner()
    Audio.DefusedStartedAt = CurTime()
    Audio.DefusedUntil = CurTime() + 5

    killTimer(DEFUSED_FADE_TIMER)
    stopPatch(Audio.DefusedPatch)

    local patch = createPlayerPatch(DEFUSED_SOUND, 1)
    Audio.DefusedPatch = patch
    if patch then
        timer.Create(DEFUSED_FADE_TIMER, 0.1, 50, function()
            if Audio.DefusedPatch ~= patch then
                killTimer(DEFUSED_FADE_TIMER)
                return
            end
            local elapsed = CurTime() - (Audio.DefusedStartedAt or CurTime())
            if elapsed < 4 then return end
            local frac = math.Clamp(5 - elapsed, 0, 1)
            patch:ChangeVolume(frac, 0)
            if elapsed >= 5 then
                stopPatch(patch)
                if Audio.DefusedPatch == patch then
                    Audio.DefusedPatch = nil
                end
            end
        end)
    else
        Audio.PlayUISound(DEFUSED_SOUND, 1, 100, CHAN_STATIC)
    end
end

function Audio.ProcessStateTransition(frame, prevState, nextState, isOpen)
    if not IsValid(frame) or isOpen then return end

    local prevStrikes = tonumber((prevState and prevState.strikes) or 0) or 0
    local nextStrikes = tonumber((nextState and nextState.strikes) or 0) or 0
    if nextStrikes > prevStrikes then
        Audio.PlayUISound(STRIKE_SOUND)
    end

    if Audio.CountSolvedModules(nextState) > Audio.CountSolvedModules(prevState) then
        Audio.PlayUISound(MODULE_SOLVED_SOUND)
    end

    local prevStamp = tonumber((prevState and prevState.roundResultStamp) or 0) or 0
    local nextStamp = tonumber((nextState and nextState.roundResultStamp) or 0) or 0
    local nextSuccess = nextState and nextState.roundSuccess == true
    local prevActive = prevState and prevState.active == true
    local nextActive = nextState and nextState.active == true
    local nextSolved = nextState and nextState.allSolved == true
    if (nextSuccess and nextStamp > 0 and nextStamp ~= prevStamp) or (prevActive and (not nextActive) and nextSolved) then
        if not frame._ktneDefusedShown then
            frame._ktneDefusedShown = true
            Audio.ShowDefusedBanner()
        end
    end
end

hook.Add("HUDPaint", "KTNE_DefusedBannerHUD", function()
    local untilTime = Audio.DefusedUntil or 0
    if untilTime <= CurTime() then return end

    local startedAt = Audio.DefusedStartedAt or CurTime()
    local elapsed = CurTime() - startedAt
    local remaining = untilTime - CurTime()
    local alpha = 255
    if elapsed < 0.4 then
        alpha = math.floor(255 * math.Clamp(elapsed / 0.4, 0, 1))
    elseif remaining < 1 then
        alpha = math.floor(255 * math.Clamp(remaining / 1, 0, 1))
    end

    draw.SimpleText(
        "BOMB DEFUSED",
        "KTNE_Title",
        ScrW() * 0.5,
        ScrH() * 0.16,
        Color(72, 255, 118, alpha),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )
end)
