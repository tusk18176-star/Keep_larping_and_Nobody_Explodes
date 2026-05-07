local METER_TO_UNITS = 52.4934
local INEVITABLE_DURATIONS = {
    abberant = 90,
    pkb = 120,
}

local function findInevitableBomb()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    local ent = ply:GetNWEntity("KTNE_InevitableFocus")
    if not IsValid(ent) or not ent:GetNWBool("KTNE_Inevitable", false) then return nil end
    local deadline = ent:GetNWFloat("KTNE_InevitableDeadline", 0)
    if deadline <= 0 then return nil end
    return ent, deadline
end

local function formatCountdown(seconds)
    seconds = math.max(0, math.ceil(seconds))
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

hook.Add("HUDPaint", "KTNE_InevitableWarningHUD", function()
    local ent, deadline = findInevitableBomb()
    if not IsValid(ent) or not deadline then return end

    local mode = ent:GetNWString("KTNE_InevitableType", "")
    local timeLeft = deadline - CurTime()
    if timeLeft <= 0 then return end

    local w, h = ScrW(), ScrH()
    local boxW, boxH = math.min(620, w - 60), 118
    local x = (w - boxW) * 0.5
    local y = h - boxH - 42
    local duration = INEVITABLE_DURATIONS[mode] or 90
    local darkenFrac = math.Clamp((timeLeft - 15) / math.max(duration - 15, 1), 0, 1)
    local redValue = math.floor(Lerp(darkenFrac, 0, 140))
    local borderValue = math.floor(Lerp(darkenFrac, 0, 220))
    local flickerRate = timeLeft <= 10 and 18 or 8
    local flicker = math.sin(RealTime() * flickerRate) > 0
    local redFill = Color(redValue, 0, 0, 228)
    local redOutline = Color(borderValue, 18, 18, 245)
    local blackFill = Color(0, 0, 0, 228)
    local blackOutline = Color(math.max(24, math.floor(borderValue * 0.2)), 0, 0, 245)
    local fill = flicker and redFill or blackFill
    local outline = flicker and redOutline or blackOutline
    local textColor = mode == "pkb" and Color(10, 10, 10) or Color(math.max(40, math.floor(redValue * 0.7)), 0, 0)
    if timeLeft <= 15 then
        textColor = Color(255, 255, 255)
    end
    if timeLeft <= 10 then
        local whiteFill = Color(244, 244, 244, 228)
        local whiteOutline = Color(255, 255, 255, 245)
        fill = flicker and whiteFill or blackFill
        outline = flicker and whiteOutline or Color(20, 20, 20, 245)
        textColor = flicker and Color(0, 0, 0) or Color(255, 255, 255)
    end
    local title = mode == "pkb" and "WARNING: PKB DETONATION INEVITABLE" or "WARNING: ABBERANT DETONATION INEVITABLE"

    draw.RoundedBox(8, x, y, boxW, boxH, fill)
    surface.SetDrawColor(outline)
    surface.DrawOutlinedRect(x, y, boxW, boxH, 3)
    draw.SimpleText(title, "DermaLarge", w * 0.5, y + 24, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("YOU ARE WITHIN RANGE", "Trebuchet24", w * 0.5, y + 58, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(formatCountdown(timeLeft), "DermaLarge", w * 0.5, y + 92, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
