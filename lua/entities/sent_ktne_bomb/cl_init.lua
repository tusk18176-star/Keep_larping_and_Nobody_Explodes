
include("shared.lua")

local activeFrames = activeFrames or {}
local hiddenFrames = hiddenFrames or {}
local actionCooldowns = actionCooldowns or {}

local purgeInvalid
local ktneSetUiHooksEnabled

local function ktneRefreshScreenClicker()
    local anyActive = false
    for ent, fr in pairs(activeFrames) do
        if (not IsValid(ent)) or (not IsValid(fr)) or fr._closing or (fr.IsVisible and not fr:IsVisible()) then
            activeFrames[ent] = nil
        else
            anyActive = true
            break
        end
    end
    if ktneSetUiHooksEnabled then ktneSetUiHooksEnabled(anyActive) end
    gui.EnableScreenClicker(anyActive)
end

surface.CreateFont("KTNE_Title", {font = "Roboto", size = 30, weight = 700})
surface.CreateFont("KTNE_SubTitle", {font = "Roboto", size = 22, weight = 700})
surface.CreateFont("KTNE_Body", {font = "Roboto", size = 18, weight = 500})
surface.CreateFont("KTNE_Small", {font = "Roboto", size = 15, weight = 500})

surface.CreateFont("KTNE_Mono", {font = "Roboto", size = 18, weight = 700})
surface.CreateFont("KTNE_Timer", {font = "Consolas", size = 42, weight = 900, extended = true})

local THEME = {
    bg = Color(6, 16, 24, 246),
    panel = Color(10, 28, 40, 238),
    panelSoft = Color(12, 38, 54, 220),
    line = Color(85, 210, 255, 180),
    lineSoft = Color(70, 150, 190, 90),
    glow = Color(110, 235, 255, 22),
    title = Color(170, 245, 255),
    text = Color(208, 244, 255),
    amber = Color(255, 188, 92),
    danger = Color(255, 116, 116),
    success = Color(132, 255, 184),
    holo = Color(16, 48, 72, 246),
    book = Color(8, 30, 44, 246),
}

local function formatBombTimer(totalSeconds)
    local t = math.max(0, tonumber(totalSeconds) or 0)
    local mins = math.floor(t / 60)
    local secs = math.floor(t % 60)
    return string.format("%d:%02d.00", mins, secs)
end

local function stopAllTensionTracks()
    if KTNE_ClientAudio and KTNE_ClientAudio.StopTheme then
        KTNE_ClientAudio.StopTheme()
    end
end

local function updateTensionTrack(ent, state)
    if not IsValid(ent) then return end
    if not KTNE_ClientAudio then return end
    local make = string.upper(tostring((state and state.make) or ""))
    if (state and state.active == false) or ent:GetNWBool("KTNE_Inevitable", false) then
        KTNE_ClientAudio.StopThemeForEnt(ent)
        return
    end

    if make == "PKB" then
        KTNE_ClientAudio.StartTheme(ent, KTNE_ClientAudio.GetThemeSound("PKB"), {volume = 0.65, loop = true})
    elseif make == "ABBERANT" then
        KTNE_ClientAudio.StartTheme(ent, KTNE_ClientAudio.GetThemeSound("ABBERANT"), {volume = 0.65, loop = true, fadeIn = 30})
    else
        KTNE_ClientAudio.StopThemeForEnt(ent)
    end
end

local function panelChrome(w, h, alpha)
    draw.RoundedBox(10, 0, 0, w, h, Color(THEME.panel.r, THEME.panel.g, THEME.panel.b, alpha or THEME.panel.a))
    surface.SetDrawColor(THEME.lineSoft)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
    surface.SetDrawColor(THEME.line.r, THEME.line.g, THEME.line.b, 22)
    surface.DrawRect(1, 1, w - 2, 6)
end

local function paintHoloButton(self, w, h, txt, accent)
    local hovered = self:IsHovered()
    local bg = hovered and Color(20, 66, 94, 245) or Color(12, 42, 60, 232)
    draw.RoundedBox(8, 0, 0, w, h, bg)
    surface.SetDrawColor(accent or THEME.line)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
    draw.SimpleText(txt or "", "KTNE_Body", w / 2, h / 2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function drawTechPlate(x, y, w, h, tint)
    draw.RoundedBox(8, x, y, w, h, Color(6, 24, 36, 248))
    surface.SetDrawColor(tint or THEME.line)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    surface.SetDrawColor(THEME.lineSoft)
    surface.DrawRect(x + 1, y + 1, w - 2, 5)
    for gx = x + 24, x + w - 24, 36 do surface.DrawLine(gx, y + 10, gx, y + h - 10) end
    for gy = y + 38, y + h - 18, 32 do surface.DrawLine(x + 10, gy, x + w - 10, gy) end
end

local function drawScrew(x, y, r)
    draw.RoundedBox(r, x - r, y - r, r * 2, r * 2, Color(36, 50, 58, 245))
    surface.SetDrawColor(Color(136, 170, 184, 190))
    surface.DrawOutlinedRect(x - r, y - r, r * 2, r * 2, 1)
    surface.DrawLine(x - r + 3, y, x + r - 3, y)
end

local function drawLed(x, y, col, lit)
    draw.RoundedBox(6, x - 6, y - 6, 12, 12, lit and col or Color(28, 36, 42, 245))
    surface.SetDrawColor(lit and Color(255, 255, 255, 120) or THEME.lineSoft)
    surface.DrawOutlinedRect(x - 6, y - 6, 12, 12, 1)
end

local function drawWireRun(x1, y1, x2, y2, col)
    surface.SetDrawColor(Color(8, 12, 16, 190))
    surface.DrawLine(x1, y1 + 1, x2, y2 + 1)
    surface.DrawLine(x1, y1 - 1, x2, y2 - 1)
    surface.SetDrawColor(col)
    surface.DrawLine(x1, y1, x2, y2)
end

local function drawLabelTag(x, y, w, text, col)
    draw.RoundedBox(4, x, y, w, 22, Color(4, 18, 28, 235))
    surface.SetDrawColor(col or THEME.lineSoft)
    surface.DrawOutlinedRect(x, y, w, 22, 1)
    draw.SimpleText(text, "KTNE_Small", x + w / 2, y + 11, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function drawMeter(x, y, w, h, pct, col, label)
    draw.RoundedBox(4, x, y, w, h, Color(9, 22, 30, 240))
    surface.SetDrawColor(THEME.lineSoft)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.RoundedBox(3, x + 4, y + h - 6 - math.floor((h - 12) * pct), w - 8, math.floor((h - 12) * pct), col)
    draw.SimpleText(label or "", "KTNE_Small", x + w / 2, y + h + 12, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function drawDetpackPlate(w, h)
    drawTechPlate(0, 0, w, h, THEME.line)
    draw.SimpleText("DETPACK // FIELD CHARGE", "KTNE_SubTitle", 16, 14, THEME.title)
    draw.SimpleText("CANVAS DEMOLITION SATCHEL", "KTNE_Small", w - 16, 18, THEME.amber, TEXT_ALIGN_RIGHT)
    local x, y, bw, bh = 26, 46, w - 52, h - 72
    draw.RoundedBox(10, x, y, bw, bh, Color(34, 82, 78, 238))
    surface.SetDrawColor(Color(150, 226, 220, 145))
    surface.DrawOutlinedRect(x, y, bw, bh, 2)
    draw.RoundedBox(6, x + 18, y + 14, bw - 36, 22, Color(18, 54, 56, 235))
    draw.SimpleText("DETPACK", "KTNE_Body", x + bw / 2, y + 25, THEME.title, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    local chargeW = math.max(28, math.floor((bw - 72) / 4))
    for i = 0, 3 do
        local cx = x + 28 + i * (chargeW + 8)
        draw.RoundedBox(5, cx, y + 54, chargeW, bh - 92, Color(44, 118, 126, 232))
        surface.SetDrawColor(Color(178, 244, 248, 120))
        surface.DrawOutlinedRect(cx, y + 54, chargeW, bh - 92, 1)
        draw.RoundedBox(3, cx + 6, y + 62, chargeW - 12, 10, Color(9, 26, 32, 220))
    end
    local coreX, coreY = x + bw / 2 - 48, y + bh - 54
    draw.RoundedBox(6, coreX, coreY, 96, 36, Color(8, 18, 24, 250))
    surface.SetDrawColor(THEME.amber)
    surface.DrawOutlinedRect(coreX, coreY, 96, 36, 1)
    draw.SimpleText("ARM", "KTNE_Body", coreX + 48, coreY + 18, THEME.amber, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    local cols = {Color(205, 82, 82), Color(226, 202, 70), Color(78, 136, 218), Color(92, 190, 116)}
    for i, col in ipairs(cols) do
        local wx = x + 28 + (i - 1) * ((bw - 56) / 3)
        drawWireRun(wx, y + 42, coreX + 14 + i * 14, coreY, col)
    end
    drawScrew(x + 12, y + 12, 5)
    drawScrew(x + bw - 12, y + bh - 12, 5)
end

local function drawIncendiaryPlate(w, h)
    drawTechPlate(0, 0, w, h, Color(255, 132, 92, 210))
    draw.SimpleText("INCENDIARY // THERMO CORE", "KTNE_SubTitle", 16, 14, THEME.title)
    draw.SimpleText("PRESSURIZED HEAT CANISTER", "KTNE_Small", w - 16, 18, THEME.amber, TEXT_ALIGN_RIGHT)
    local cx = w / 2
    local x, y, bw, bh = cx - 72, 44, 144, h - 68
    draw.RoundedBox(18, x, y, bw, bh, Color(150, 46, 32, 240))
    draw.RoundedBox(12, x + 16, y + 18, bw - 32, bh - 36, Color(70, 16, 12, 225))
    draw.RoundedBox(8, x + 30, y + 42, bw - 60, bh - 84, Color(212, 84, 42, 210))
    surface.SetDrawColor(Color(255, 178, 126, 175))
    surface.DrawOutlinedRect(x, y, bw, bh, 2)
    surface.DrawRect(x + 18, y + 10, bw - 36, 10)
    surface.DrawRect(x + 18, y + bh - 20, bw - 36, 10)
    drawLabelTag(cx - 42, y + bh / 2 - 16, 84, "THERMO", Color(255, 176, 116, 210))
    drawMeter(x - 44, y + 40, 28, bh - 80, 0.62, Color(90, 212, 255, 210), "COOL")
    drawMeter(x + bw + 16, y + 40, 28, bh - 80, 0.82, Color(255, 118, 64, 220), "VENT")
end

local function drawAberrantPlate(w, h)
    drawTechPlate(0, 0, w, h, Color(150, 152, 164, 190))
    draw.SimpleText("ABERRANT // CONTAINMENT CORE", "KTNE_SubTitle", 16, 14, THEME.title)
    draw.SimpleText("ASYMMETRIC FAILSAFE FRAME", "KTNE_Small", w - 16, 18, THEME.amber, TEXT_ALIGN_RIGHT)
    local x, y, bw, bh = 30, 48, w - 60, h - 76
    draw.NoTexture()
    surface.SetDrawColor(Color(44, 46, 54, 242))
    surface.DrawPoly({{x=x+24,y=y},{x=x+bw-12,y=y+10},{x=x+bw,y=y+42},{x=x+bw-28,y=y+bh},{x=x+16,y=y+bh-8},{x=x,y=y+24}})
    surface.SetDrawColor(Color(172, 176, 188, 150))
    surface.DrawOutlinedRect(x + 12, y + 14, bw - 24, bh - 26, 2)
    draw.RoundedBox(6, x + 38, y + 34, bw - 76, bh - 68, Color(20, 24, 30, 245))
    draw.RoundedBox(8, x + bw / 2 - 42, y + bh / 2 - 34, 84, 68, Color(74, 22, 34, 235))
    surface.SetDrawColor(Color(255, 84, 112, 130))
    surface.DrawOutlinedRect(x + bw / 2 - 42, y + bh / 2 - 34, 84, 68, 2)
    draw.SimpleText("CORE", "KTNE_Body", x + bw / 2, y + bh / 2, Color(255, 150, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    for i = 0, 2 do
        draw.RoundedBox(4, x + 18 + i * 34, y + 20 + i * 18, 18, 52, Color(94, 96, 104, 230))
        draw.RoundedBox(4, x + bw - 44 - i * 24, y + 38 + i * 22, 20, 48, Color(94, 96, 104, 230))
    end
    drawLabelTag(x + 24, y + bh - 34, 86, "TWIN", Color(255, 96, 120, 160))
    drawLabelTag(x + bw - 112, y + bh - 34, 88, "OVERRIDE", Color(255, 96, 120, 160))
end

local function drawEMPPlate(w, h)
    drawTechPlate(0, 0, w, h, Color(236, 218, 92, 210))
    draw.SimpleText("EMP CHARGE // FLOW CORE", "KTNE_SubTitle", 16, 14, THEME.title)
    draw.SimpleText("FARADAY CONDUCTOR CRATE", "KTNE_Small", w - 16, 18, THEME.amber, TEXT_ALIGN_RIGHT)
    local cx = w / 2
    local x, y, bw, bh = 32, 46, w - 64, h - 72
    draw.RoundedBox(6, x, y, bw, bh, Color(30, 34, 38, 242))
    surface.SetDrawColor(Color(236, 218, 92, 190))
    surface.DrawOutlinedRect(x, y, bw, bh, 2)
    for i = 0, 4 do surface.DrawLine(x + 14 + i * 24, y + 12, x + 40 + i * 24, y + bh - 12) end
    draw.RoundedBox(12, cx - 44, y + 18, 88, bh - 36, Color(210, 194, 46, 232))
    surface.SetDrawColor(Color(80, 70, 16, 210))
    for i = 1, 7 do
        local ly = y + 24 + i * ((bh - 48) / 8)
        surface.DrawLine(cx - 36, ly, cx + 36, ly)
    end
    drawLabelTag(cx - 34, y + bh / 2 - 12, 68, "EMP", Color(255, 230, 96, 220))
    drawLed(x + 28, y + 28, Color(255, 220, 80), true)
    drawLed(x + bw - 28, y + bh - 28, Color(255, 220, 80), false)
    drawWireRun(cx - 44, y + bh / 2, x + 18, y + 34, Color(255, 220, 80))
    drawWireRun(cx + 44, y + bh / 2, x + bw - 18, y + bh - 34, Color(255, 220, 80))
end

local function drawManualDiagram(title, w, h)
    drawTechPlate(0, 0, w, h, THEME.lineSoft)
    draw.SimpleText("MODULE REFERENCE", "KTNE_SubTitle", 16, 14, THEME.title)
    local key = string.lower(title or "")
    local noteCol = Color(170, 226, 240)
    local bottomY = h - 28

    if key:find("wire") then
        local cols = {Color(205,82,82), Color(226,202,70), Color(78,136,218), Color(235,235,235), Color(34,34,34)}
        for i, col in ipairs(cols) do
            local y = 54 + i * 22
            drawWireRun(28, y, w - 70, y + ((i % 2 == 0) and 8 or -8), col)
            drawScrew(24, y, 4)
            drawLabelTag(w - 62, y - 10, 38, tostring(i), col)
        end
        draw.SimpleText("Cut one physical lead after applying the first true rule.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("keypad") then
        local symbols = {"CROWN", "BOLT", "RUNE", "OMEGA", "STAR", "HOOK"}
        for i = 1, 6 do
            local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
            local bx, by = 36 + col * 82, 58 + row * 54
            draw.RoundedBox(6, bx, by, 66, 40, Color(12, 44, 62, 236))
            surface.SetDrawColor(i <= 4 and THEME.line or THEME.lineSoft)
            surface.DrawOutlinedRect(bx, by, 66, 40, 1)
            draw.SimpleText(symbols[i], "KTNE_Small", bx + 33, by + 20, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        draw.SimpleText("Press the four visible glyphs in their manual row order.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("spiral") or key:find("buffer") then
        for i = 1, 8 do
            local bx = 18 + (i - 1) * math.floor((w - 36) / 8)
            draw.RoundedBox(5, bx, 84, 26, 34, Color(12, 44, 62, 236))
            surface.SetDrawColor(THEME.line)
            surface.DrawOutlinedRect(bx, 84, 26, 34, 1)
            draw.SimpleText(tostring((i * 3) % 10), "KTNE_Body", bx + 13, 101, THEME.amber, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("+", "KTNE_Small", bx + 13, 72, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("-", "KTNE_Small", bx + 13, 130, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        surface.SetDrawColor(THEME.lineSoft)
        for i = 0, 5 do surface.DrawLine(26 + i * 42, 158 + math.sin(i) * 8, 56 + i * 42, 158 - math.sin(i) * 8) end
        draw.SimpleText("Eight serial-derived dials feed the spiral buffer.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("tamper") then
        local left = {{"R",Color(205,82,82)}, {"Y",Color(226,202,70)}, {"B",Color(78,136,218)}, {"G",Color(92,190,116)}}
        local right = {{"O",Color(215,132,48)}, {"GR",Color(138,138,146)}, {"P",Color(145,88,190)}, {"BK",Color(28,28,28)}}
        for i = 1, 4 do
            local y = 52 + i * 30
            drawLabelTag(22, y - 11, 46, left[i][1], left[i][2])
            drawLabelTag(w - 68, y - 11, 46, right[i][1], right[i][2])
            drawWireRun(68, y, w - 68, y + (i - 2.5) * 7, left[i][2])
        end
        draw.SimpleText("Shifted serial math decides each receiver socket.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("memory") or key:find("network stabilization") then
        local idx = 1
        for row = 0, 2 do
            for col = 0, 2 do
                local bx, by = 50 + col * 68, 54 + row * 44
                local lit = idx == 2 or idx == 5 or idx == 9
                draw.RoundedBox(7, bx, by, 52, 34, lit and Color(220, 230, 238, 240) or Color(54, 64, 76, 230))
                surface.SetDrawColor(lit and Color(255,255,255,180) or THEME.lineSoft)
                surface.DrawOutlinedRect(bx, by, 52, 34, 1)
                draw.SimpleText(tostring(idx), "KTNE_Body", bx + 26, by + 17, lit and Color(18,24,30) or THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                idx = idx + 1
            end
        end
        draw.SimpleText("Start key opens a growing four-round light sequence.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("minesweeper") or key:find("payload location") then
        for row = 1, 5 do
            for col = 1, 5 do
                local bx, by = 48 + (col - 1) * 36, 48 + (row - 1) * 28
                draw.RoundedBox(3, bx, by, 28, 22, Color(14, 44, 54, 236))
                surface.SetDrawColor((row == 3 and col == 4) and THEME.amber or THEME.lineSoft)
                surface.DrawOutlinedRect(bx, by, 28, 22, 1)
            end
        end
        draw.SimpleText("A hidden payload coordinate is derived from serial sums.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("thermo") then
        drawMeter(42, 58, 34, 104, 0.55, Color(90, 212, 255, 220), "COOLANT")
        drawMeter(w - 76, 58, 34, 104, 0.78, Color(255, 118, 64, 220), "EXHAUST")
        draw.RoundedBox(12, w / 2 - 44, 60, 88, 98, Color(150, 46, 32, 238))
        drawLabelTag(w / 2 - 34, 96, 68, "CORE", Color(255, 176, 116, 220))
        draw.SimpleText("Lock coolant first, then set heat exhaust.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("electric") then
        local midX = w / 2
        drawLabelTag(28, 112, 76, "YELLOW", Color(232,210,80))
        local outs = {{"RED",Color(205,82,82),62}, {"BLUE",Color(78,136,218),110}, {"GREEN",Color(92,190,116),158}}
        for _, info in ipairs(outs) do
            drawLabelTag(w - 104, info[3] - 11, 76, info[1], info[2])
            drawWireRun(104, 123, midX, info[3], Color(232,210,80))
            drawWireRun(midX, info[3], w - 104, info[3], info[2])
        end
        draw.SimpleText("Route the yellow source to one serial-selected output.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("override") then
        for i = 1, 3 do
            local bx = 50 + (i - 1) * 78
            draw.RoundedBox(8, bx, 62, 54, 92, Color(12, 44, 62, 236))
            surface.SetDrawColor(THEME.line)
            surface.DrawOutlinedRect(bx, 62, 54, 92, 1)
            draw.SimpleText("SW" .. i, "KTNE_Small", bx + 27, 78, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.RoundedBox(3, bx + 22, 94, 10, 42, Color(20, 26, 34, 245))
            draw.RoundedBox(3, bx + 18, 96 + (i % 2) * 22, 18, 14, Color(132, 224, 255, 240))
        end
        drawLabelTag(w / 2 - 58, 164, 116, "CHECK", THEME.line)
        draw.SimpleText("Apply all exception flips before checking.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("calibration") then
        local lights = {{"RED", Color(220,70,70)}, {"BLUE", Color(70,120,230)}, {"GREEN", Color(90,210,120)}}
        for i, info in ipairs(lights) do
            local x = 58 + (i - 1) * 78
            drawLed(x, 72, info[2], i == 2)
            draw.SimpleText(info[1], "KTNE_Small", x, 94, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.RoundedBox(6, x - 24, 132, 48, 28, Color(12, 44, 62, 236))
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(x - 24, 132, 48, 28, 1)
        end
        drawLabelTag(w / 2 - 46, 108, 92, "CENTER", THEME.line)
        draw.SimpleText("Start on the correct lower button, then hit center on target light.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("interrupt") then
        draw.RoundedBox(8, 38, 62, w - 76, 90, Color(12, 44, 62, 236))
        surface.SetDrawColor(THEME.line)
        surface.DrawOutlinedRect(38, 62, w - 76, 90, 1)
        draw.SimpleText("CLICK BURST", "KTNE_SubTitle", w / 2, 84, THEME.title, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("15 / 7 / 24 / 18", "KTNE_Body", w / 2, 114, THEME.amber, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        drawLabelTag(w / 2 - 38, 136, 76, "START", THEME.line)
        draw.SimpleText("Each round demands an exact count before the timer expires.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("reactor") then
        drawLabelTag(34, 54, 86, "CODE", THEME.line)
        local idx = 1
        for row = 0, 2 do
            for col = 0, 2 do
                local bx, by = 132 + col * 36, 58 + row * 34
                draw.RoundedBox(4, bx, by, 28, 26, Color(20, 38, 46, 236))
                surface.SetDrawColor((idx == 2 or idx == 7) and Color(255,100,100,200) or THEME.lineSoft)
                surface.DrawOutlinedRect(bx, by, 28, 26, 1)
                if idx == 2 or idx == 7 then draw.SimpleText("X", "KTNE_Body", bx + 14, by + 13, Color(255,140,140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
                idx = idx + 1
            end
        end
        draw.SimpleText("Enter access code, then clear faults before overflow.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("drill") then
        draw.RoundedBox(8, 46, 72, w - 92, 62, Color(68, 72, 78, 240))
        surface.SetDrawColor(Color(160, 164, 170, 180))
        surface.DrawOutlinedRect(46, 72, w - 92, 62, 2)
        draw.NoTexture()
        surface.SetDrawColor(Color(110, 116, 124, 240))
        surface.DrawPoly({{x=w-78,y=66},{x=w-34,y=103},{x=w-78,y=140}})
        local cols = {Color(205,82,82), Color(78,136,218), Color(25,25,25), Color(92,190,116), Color(226,202,70), Color(235,235,235)}
        for i, col in ipairs(cols) do drawWireRun(54, 146 + (i % 3) * 8, w - 72, 146 + (i % 3) * 8, col) end
        draw.SimpleText("Unlock the drill panel, then cut the three timer-selected wires.", "KTNE_Small", 22, bottomY, noteCol)
    elseif key:find("twin payload") then
        draw.RoundedBox(8, 40, 76, w - 80, 40, Color(50, 56, 62, 240))
        draw.RoundedBox(8, 40, 126, w - 80, 40, Color(50, 56, 62, 240))
        surface.SetDrawColor(Color(255, 100, 100, 160))
        surface.DrawOutlinedRect(40, 76, w - 80, 40, 1)
        surface.DrawOutlinedRect(40, 126, w - 80, 40, 1)
        local cols = {Color(138,138,146), Color(226,202,70), Color(205,82,82), Color(92,190,116), Color(78,136,218), Color(25,25,25)}
        for i, col in ipairs(cols) do drawWireRun(30 + i * 36, 66, 34 + i * 36, 176, col) end
        draw.SimpleText("One wrong cut detonates the paired payloads.", "KTNE_Small", 22, bottomY, Color(255,190,190))
    elseif key:find("red & blue") or key:find("redblue") then
        draw.RoundedBox(10, 34, 64, w - 68, 44, Color(130, 40, 46, 220))
        draw.RoundedBox(10, 34, 124, w - 68, 44, Color(36, 82, 156, 220))
        draw.SimpleText("RED", "KTNE_SubTitle", w / 2, 86, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("BLUE", "KTNE_SubTitle", w / 2, 146, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Solve last, then apply every color switch rule once.", "KTNE_Small", 22, bottomY, noteCol)
    else
        local cx, cy = w / 2, h / 2 + 6
        draw.RoundedBox(8, cx - 92, cy - 42, 184, 84, Color(12, 44, 62, 232))
        surface.SetDrawColor(THEME.line)
        surface.DrawOutlinedRect(cx - 92, cy - 42, 184, 84, 1)
        draw.SimpleText("BOMB FAMILY", "KTNE_Body", cx, cy - 10, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Use the upper reference image.", "KTNE_Small", cx, cy + 18, noteCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function sendAction(ent, action, data, minInterval, dedupeKey)
    if not IsValid(ent) then return end
    if minInterval and minInterval > 0 then
        local key = tostring(ent) .. "|" .. tostring(action) .. "|" .. tostring(dedupeKey or "")
        local now = CurTime()
        if (actionCooldowns[key] or 0) > now then return end
        actionCooldowns[key] = now + minInterval
    end
    net.Start("ktne_action_mp")
        net.WriteEntity(ent)
        net.WriteString(action)
        net.WriteTable(data or {})
    net.SendToServer()
end

local colorMap = {
    Red = Color(185, 70, 70),
    Blue = Color(70, 110, 190),
    Yellow = Color(215, 195, 80),
    White = Color(235, 235, 235),
    Black = Color(28, 28, 28),
    Orange = Color(215, 132, 48),
    Green = Color(65, 165, 95),
    Grey = Color(138, 138, 146),
    Purple = Color(145, 88, 190),
}
getColor = function(name) return colorMap[name] or Color(70, 140, 170) end
local function textColorFor(name) return color_white end

local function closeFrameForBomb(ent, suppress)
    if suppress then hiddenFrames[ent] = true end
    if not suppress then
        stopAllTensionTracks()
    end
    local fr = activeFrames[ent]
    if IsValid(fr) then
        fr._closing = true
        fr:Remove()
    end
    activeFrames[ent] = nil
    ktneRefreshScreenClicker()
end

local function purgeInvalid()
    for ent, fr in pairs(activeFrames) do
        if (not IsValid(ent)) or (not IsValid(fr)) then
            if not IsValid(ent) then
                stopAllTensionTracks()
            end
            if IsValid(fr) then fr._closing = true fr:Remove() end
            activeFrames[ent] = nil
            hiddenFrames[ent] = nil
        end
    end
    ktneRefreshScreenClicker()
end
local ktneUiHooksEnabled = false
local KTNE_INPUT_HOOK_ID = "KTNE_Bomb_InputLock_" .. string.gsub((debug.getinfo(1, "S").short_src or tostring({})), "%W", "_")
local KTNE_MOVE_BUTTONS = {
    IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_JUMP, IN_DUCK, IN_SPEED, IN_WALK,
}
local KTNE_MOVEMENT_BINDS = {
    ["+forward"] = true, ["-forward"] = true,
    ["+back"] = true, ["-back"] = true,
    ["+moveleft"] = true, ["-moveleft"] = true,
    ["+moveright"] = true, ["-moveright"] = true,
    ["+jump"] = true, ["-jump"] = true,
    ["+duck"] = true, ["-duck"] = true,
    ["+speed"] = true, ["-speed"] = true,
    ["+walk"] = true, ["-walk"] = true,
}

local function ktneHasActiveMinigameFrame()
    local anyActive = false
    for ent, fr in pairs(activeFrames) do
        if (not IsValid(ent)) or (not IsValid(fr)) or fr._closing or (fr.IsVisible and not fr:IsVisible()) then
            activeFrames[ent] = nil
        else
            anyActive = true
            break
        end
    end
    return anyActive
end

local function ktneSetUiHooksEnabled(enabled)
    if enabled == ktneUiHooksEnabled then return end
    ktneUiHooksEnabled = enabled

    if enabled then
        timer.Create("KTNE_Bomb_UIWatch_REWORK", 1, 0, function()
            if purgeInvalid then
                purgeInvalid()
            end
        end)

        hook.Add("PlayerBindPress", KTNE_INPUT_HOOK_ID .. "_Bind", function(_, bind)
            if not ktneHasActiveMinigameFrame() then return end
            local lower = string.lower(tostring(bind or ""))
            if lower:find("voice", 1, true) or lower:find("talk", 1, true) then return end
            return true
        end)

        hook.Add("StartChat", KTNE_INPUT_HOOK_ID .. "_ChatBlock", function()
            if ktneHasActiveMinigameFrame() then
                return true
            end
        end)

        hook.Add("OnContextMenuOpen", KTNE_INPUT_HOOK_ID .. "_ContextBlock", function()
            if ktneHasActiveMinigameFrame() then
                return false
            end
        end)

        hook.Add("OnSpawnMenuOpen", KTNE_INPUT_HOOK_ID .. "_SpawnBlock", function()
            if ktneHasActiveMinigameFrame() then
                return false
            end
        end)

        hook.Add("CreateMove", KTNE_INPUT_HOOK_ID .. "_Move", function(cmd)
            if not ktneHasActiveMinigameFrame() then return end
            cmd:SetForwardMove(0)
            cmd:SetSideMove(0)
            cmd:SetUpMove(0)
            local buttons = cmd:GetButtons()
            for _, button in ipairs(KTNE_MOVE_BUTTONS) do
                buttons = bit.band(buttons, bit.bnot(button))
            end
            cmd:SetButtons(buttons)
        end)
    else
        if timer.Exists("KTNE_Bomb_UIWatch_REWORK") then
            timer.Remove("KTNE_Bomb_UIWatch_REWORK")
        end
        hook.Remove("PlayerBindPress", KTNE_INPUT_HOOK_ID .. "_Bind")
        hook.Remove("StartChat", KTNE_INPUT_HOOK_ID .. "_ChatBlock")
        hook.Remove("OnContextMenuOpen", KTNE_INPUT_HOOK_ID .. "_ContextBlock")
        hook.Remove("OnSpawnMenuOpen", KTNE_INPUT_HOOK_ID .. "_SpawnBlock")
        hook.Remove("CreateMove", KTNE_INPUT_HOOK_ID .. "_Move")
    end
end

local function openDebugRolePicker(ent, state)
    if not IsValid(ent) then return end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Training Mode")
    frame:SetSize(340, 190)
    frame:Center()
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(6, 16, 24, 250))
        surface.SetDrawColor(THEME.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local label = vgui.Create("DLabel", frame)
    label:SetPos(18, 36)
    label:SetSize(304, 44)
    label:SetFont("KTNE_Body")
    label:SetTextColor(THEME.text)
    label:SetWrap(true)
    label:SetText((state and state.active) and "Select which one-player multiplayer state to view." or "Start the multiplayer bomb in a one-player debug state.")

    local function makeChoice(text, role, x)
        local btn = vgui.Create("DButton", frame)
        btn:SetText("")
        btn:SetPos(x, 98)
        btn:SetSize(144, 42)
        btn.Paint = function(self, w, h)
            local active = state and state.currentRole == role
            paintHoloButton(self, w, h, text, active and THEME.amber or THEME.line)
        end
        btn.DoClick = function()
            sendAction(ent, "debug_start_role", {role = role})
            frame:Close()
        end
    end

    makeChoice("Panel State", "panel", 18)
    makeChoice("Manual State", "manual", 178)
end

local function makeSection(parent, title)
    local p = vgui.Create("DPanel", parent)
    p._sectionTitle = title
    p.Paint = function(self, w, h)
        panelChrome(w, h)
        surface.SetDrawColor(THEME.lineSoft)
        surface.DrawLine(14, 40, w - 14, 40)
        draw.SimpleText(self._sectionTitle or "", "KTNE_SubTitle", 14, 12, THEME.title)
    end
    return p
end

local function addPlaceholder(parent, title)
    local p = makeSection(parent, title)
    local lbl = vgui.Create("DLabel", p)
    lbl:SetPos(14, 52)
    lbl:SetSize(999, 80)
    lbl:SetFont("KTNE_Body")
    lbl:SetWrap(true)
    lbl:SetAutoStretchVertical(true)
    lbl:SetTextColor(Color(170, 226, 240))
    lbl:SetText("This section is intentionally blank for future modules.")
    return p
end

local function openChatComposer(frame)
    if not IsValid(frame) or not IsValid(frame._ent) then return end
    if IsValid(frame._chatComposer) then
        frame._chatComposer:MakePopup()
        if IsValid(frame._chatComposer.Entry) then
            frame._chatComposer.Entry:RequestFocus()
        end
        return
    end

    local composer = vgui.Create("DFrame")
    composer:SetTitle("Send Message")
    composer:SetSize(420, 136)
    composer:Center()
    composer:MakePopup()
    composer:SetKeyboardInputEnabled(true)
    composer.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(6, 16, 24, 250))
        surface.SetDrawColor(THEME.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    composer.OnRemove = function()
        if IsValid(frame) then
            frame._chatComposer = nil
            frame:SetKeyboardInputEnabled(false)
        end
    end

    local entry = vgui.Create("DTextEntry", composer)
    entry:SetPos(16, 40)
    entry:SetSize(388, 32)
    entry:SetFont("KTNE_Body")
    entry:SetTextColor(Color(220, 240, 248))
    entry:SetCursorColor(THEME.line)
    entry:SetPlaceholderText("Type a message...")
    entry:SetText(tostring(frame._chatDraft or ""))
    entry.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(8, 24, 36, 252))
        surface.SetDrawColor(self:HasFocus() and THEME.line or THEME.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(Color(220, 240, 248), THEME.line, THEME.line)
    end

    local function submitMessage()
        if not IsValid(frame) or not IsValid(frame._ent) then
            if IsValid(composer) then composer:Close() end
            return
        end
        local txt = string.Trim(tostring(entry:GetValue() or ""))
        frame._chatDraft = txt
        if txt == "" then
            entry:RequestFocus()
            return
        end
        sendAction(frame._ent, "chat_message", {text = txt})
        frame._chatDraft = ""
        if IsValid(frame.ChatEntry) then
            frame.ChatEntry:SetText("")
        end
        composer:Close()
    end

    entry.OnEnter = submitMessage
    entry.OnValueChange = function(self, val)
        if IsValid(frame) then
            frame._chatDraft = tostring(val or "")
            if IsValid(frame.ChatEntry) then
                frame.ChatEntry:SetText(frame._chatDraft)
            end
        end
    end

    local sendBtn = vgui.Create("DButton", composer)
    sendBtn:SetText("")
    sendBtn:SetPos(292, 88)
    sendBtn:SetSize(112, 30)
    sendBtn.Paint = function(self, w, h)
        paintHoloButton(self, w, h, "SEND", self:IsHovered() and THEME.line or THEME.lineSoft)
    end
    sendBtn.DoClick = submitMessage

    composer.Entry = entry
    frame._chatComposer = composer
    entry:RequestFocus()
end

local function makeFrame(ent)
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.floor(ScrW() * 0.95), math.floor(ScrH() * 0.93))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetMouseInputEnabled(true)
    frame:SetKeyboardInputEnabled(false)
    frame._ent = ent
    frame._role = "panel"
    frame._state = {}
    frame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, THEME.bg)
        surface.SetDrawColor(THEME.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(THEME.glow)
        surface.DrawRect(2, 2, w - 4, 22)
    end
    frame.OnRemove = function(self)
        if self._closing then return end
        if IsValid(self._ent) then hiddenFrames[self._ent] = true end
        activeFrames[self._ent] = nil
        ktneRefreshScreenClicker()
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetText("")
    closeBtn:SetSize(36, 36)
    closeBtn:SetPos(frame:GetWide() - 48, 10)
    closeBtn.DoClick = function() closeFrameForBomb(ent, true) end
    closeBtn.Paint = function(self, w, h)
        paintHoloButton(self, w, h, "X", self:IsHovered() and THEME.danger or THEME.line)
    end

    local body = vgui.Create("EditablePanel", frame)
    body:Dock(FILL)
    body:DockMargin(14, 54, 14, 14)
    body.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(5, 16, 24, 252))
    end
    frame.Body = body

    local header = vgui.Create("DPanel", body)
    header:Dock(TOP)
    header:SetTall(108)
    header:DockMargin(0, 0, 0, 10)
    header.Paint = function(_, w, h)
        local manualish = frame._role == "manual"
        panelChrome(w, h, manualish and THEME.book.a or THEME.holo.a)
    end
    frame.Header = header

    frame.TitleLabel = vgui.Create("DLabel", header)
    frame.TitleLabel:SetPos(16, 10)
    frame.TitleLabel:SetFont("KTNE_Title")
    frame.TitleLabel:SetTextColor(THEME.title)
    frame.TitleLabel:SizeToContents()

    frame.SubtitleLabel = vgui.Create("DLabel", header)
    frame.SubtitleLabel:SetPos(16, 46)
    frame.SubtitleLabel:SetFont("KTNE_Body")
    frame.SubtitleLabel:SetTextColor(Color(175, 224, 240))
    frame.SubtitleLabel:SetSize(900, 24)

    frame.MakeLabel = vgui.Create("DLabel", header)
    frame.MakeLabel:SetPos(16, 76)
    frame.MakeLabel:SetFont("KTNE_Body")
    frame.MakeLabel:SetTextColor(Color(132, 224, 255))
    frame.MakeLabel:SetSize(420, 22)

    frame.SerialLabel = vgui.Create("DLabel", header)
    frame.SerialLabel:SetPos(240, 76)
    frame.SerialLabel:SetFont("KTNE_Body")
    frame.SerialLabel:SetTextColor(THEME.amber)
    frame.SerialLabel:SetSize(260, 22)

    frame.TimerBox = vgui.Create("DPanel", header)
    frame.TimerBox:SetSize(300, 58)
    frame.TimerBox.Paint = function(self, w, h)
        local state = frame._state or {}
        local t = tonumber(state.timeRemaining or 0) or 0
        local blink = t < 30 and (math.floor(CurTime() * 2) % 2 == 1)
        local bg = blink and Color(18, 4, 4, 242) or Color(8, 12, 18, 242)
        local edge = blink and Color(120, 18, 18, 200) or THEME.line
        draw.RoundedBox(8, 0, 0, w, h, bg)
        surface.SetDrawColor(edge)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.SimpleText(formatBombTimer(t), "KTNE_Timer", w / 2, h / 2 + 1, Color(255, 54, 54), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    frame.TimerLabel = vgui.Create("DLabel", frame.TimerBox)
    frame.TimerLabel:Dock(FILL)
    frame.TimerLabel:SetFont("KTNE_Timer")
    frame.TimerLabel:SetTextColor(Color(255, 54, 54))
    frame.TimerLabel:SetContentAlignment(5)
    frame.TimerLabel:SetText("")

    frame.StrikeLabel = vgui.Create("DLabel", header)
    frame.StrikeLabel:SetFont("KTNE_Body")
    frame.StrikeLabel:SetTextColor(THEME.danger)
    frame.StrikeLabel:SetSize(220, 24)
    frame.StrikeLabel:SetContentAlignment(6)

    frame.VersionLabel = vgui.Create("DLabel", header)
    frame.VersionLabel:SetFont("KTNE_Small")
    frame.VersionLabel:SetTextColor(Color(122, 156, 168, 150))
    frame.VersionLabel:SetText("TuskOS V1.1.6")
    frame.VersionLabel:SetSize(220, 18)
    frame.VersionLabel:SetContentAlignment(6)

    header.PerformLayout = function(self, w, h)
        if IsValid(frame.TimerBox) then frame.TimerBox:SetPos(math.floor((w - frame.TimerBox:GetWide()) * 0.5), 14) end
        if IsValid(frame.VersionLabel) then frame.VersionLabel:SetPos(w - 236, 18) end
        if IsValid(frame.StrikeLabel) then frame.StrikeLabel:SetPos(w - 236, 48) end
    end


    local mainRow = vgui.Create("EditablePanel", body)
    mainRow:Dock(FILL)
    mainRow.Paint = nil
    frame.MainRow = mainRow

    frame.ChatHolder = vgui.Create("DPanel", mainRow)
    frame.ChatHolder:Dock(LEFT)
    frame.ChatHolder:SetWide(math.floor(frame:GetWide() * 0.17))
    frame.ChatHolder:DockMargin(0, 0, 12, 0)
    frame.ChatHolder.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(4, 14, 22, 252))
        surface.SetDrawColor(THEME.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    frame.ChatTitle = vgui.Create("DLabel", frame.ChatHolder)
    frame.ChatTitle:SetFont("KTNE_SubTitle")
    frame.ChatTitle:SetTextColor(THEME.title)
    frame.ChatTitle:SetText("Datalog / Chat")

    frame.ChatLogShell = vgui.Create("DPanel", frame.ChatHolder)
    frame.ChatLogShell.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(6, 18, 28, 250))
        surface.SetDrawColor(THEME.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    frame.ChatLogBox = vgui.Create("RichText", frame.ChatLogShell)
    frame.ChatLogBox.PerformLayout = function(self)
        self:SetFontInternal("KTNE_Body")
        self:SetFGColor(Color(200, 232, 240))
        self:SetBGColor(Color(0, 0, 0, 0))
    end
    frame.ChatEntry = vgui.Create("DTextEntry", frame.ChatHolder)
    frame.ChatEntry:SetFont("KTNE_Body")
    frame.ChatEntry:SetPlaceholderText("Type a message...")
    frame.ChatEntry:SetUpdateOnType(true)
    frame.ChatEntry:SetEditable(false)
    frame.ChatEntry:SetCursor("hand")
    frame.ChatEntry:SetTextColor(Color(220, 240, 248))
    frame.ChatEntry:SetCursorColor(THEME.line)
    frame.ChatEntry.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(8, 24, 36, 252))
        surface.SetDrawColor(self:IsHovered() and THEME.line or THEME.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(Color(220, 240, 248), color_white, color_white)
    end
    frame.ChatEntry.OnMousePressed = function(self, mousecode)
        openChatComposer(frame)
    end
    frame.ChatEntry.OnEnter = function(self)
        openChatComposer(frame)
    end

    frame.ChatSend = vgui.Create("DButton", frame.ChatHolder)
    frame.ChatSend:SetText("")
    frame.ChatSend.DoClick = function()
        openChatComposer(frame)
    end
    frame.ChatSend.Paint = function(self, w, h)
        paintHoloButton(self, w, h, "SEND", self:IsHovered() and THEME.line or THEME.lineSoft)
    end

    frame.ChatHolder.PerformLayout = function(self, w, h)
        if IsValid(frame.ChatTitle) then frame.ChatTitle:SetPos(12, 10) frame.ChatTitle:SizeToContents() end
        if IsValid(frame.ChatLogShell) then frame.ChatLogShell:SetPos(12, 40) frame.ChatLogShell:SetSize(w - 24, h - 130) end
        if IsValid(frame.ChatLogBox) then frame.ChatLogBox:SetPos(6, 6) frame.ChatLogBox:SetSize(w - 36, h - 142) end
        if IsValid(frame.ChatEntry) then frame.ChatEntry:SetPos(12, h - 78) frame.ChatEntry:SetSize(w - 100, 30) end
        if IsValid(frame.ChatSend) then frame.ChatSend:SetPos(w - 80, h - 78) frame.ChatSend:SetSize(68, 30) end
        if IsValid(frame.ChatLogBox) then frame.ChatLogBox:SetZPos(1) end
        if IsValid(frame.ChatEntry) then frame.ChatEntry:SetZPos(50) frame.ChatEntry:MoveToFront() end
        if IsValid(frame.ChatSend) then frame.ChatSend:SetZPos(51) frame.ChatSend:MoveToFront() end
    end

    frame.ContentHolder = vgui.Create("EditablePanel", mainRow)
    frame.ContentHolder:Dock(FILL)
    frame.ContentHolder.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(4, 14, 22, 252))
    end

    activeFrames[ent] = frame
    ktneRefreshScreenClicker()
    return frame
end

local function buildBombGrid(parent)
    local grid = vgui.Create("EditablePanel", parent)
    grid:Dock(FILL)
    grid.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(4, 14, 22, 252))
    end
    grid.Sections = {}
    for i = 1, 6 do
        grid.Sections[i] = vgui.Create("DPanel", grid)
        grid.Sections[i].Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(6, 18, 28, 252))
        end
    end
    grid.PerformLayout = function(self, w, h)
        local gap = 10
        local cols, rows = 3, 2
        local cellW = math.floor((w - gap * (cols - 1)) / cols)
        local cellH = math.floor((h - gap * (rows - 1)) / rows)
        for i = 1, 6 do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            self.Sections[i]:SetPos(col * (cellW + gap), row * (cellH + gap))
            self.Sections[i]:SetSize(cellW, cellH)
        end
    end
    return grid
end

local PANEL_SLOT_META = {
    wires = {field = "WireSection"},
    keypad = {field = "KeypadSection"},
    spiral = {field = "SpiralSection"},
    tamper = {field = "TamperSection"},
    memory = {field = "MemorySection"},
    redblue = {field = "RedBlueSection"},
    mines = {field = "MinesSection"},
    electric = {field = "ElectricSection"},
    twin = {field = "TwinSection"},
    thermo = {field = "ThermoSection"},
    override = {field = "OverrideSection"},
    calibration = {field = "CalibrationSection"},
    interrupt = {field = "InterruptSection"},
    reactor = {field = "ReactorSection"},
    drill = {field = "DrillSection"},
}

local function applyModuleSlotLayout(frame)
    if not IsValid(frame.BombGrid) then return end
    frame.HiddenBin = frame.HiddenBin or vgui.Create("EditablePanel", frame.ContentHolder)
    frame.HiddenBin:SetVisible(false)

    for id, meta in pairs(PANEL_SLOT_META) do
        local pnl = frame[meta.field]
        if IsValid(pnl) then
            pnl:SetParent(frame.HiddenBin)
            pnl:Dock(NODOCK)
            pnl:SetVisible(false)
        end
    end

    local active = (frame._state and frame._state.activeSlots) or {"wires", "keypad", "spiral", "tamper", "reactor", "drill"}
    if IsValid(frame.Place5) then frame.Place5:SetVisible(false) end
    if IsValid(frame.Place6) then frame.Place6:SetVisible(false) end
    for slot = 1, 6 do
        local id = active[slot]
        local meta = id and PANEL_SLOT_META[id] or nil
        local pnl = meta and frame[meta.field] or nil
        if IsValid(pnl) and IsValid(frame.BombGrid.Sections[slot]) then
            pnl:SetParent(frame.BombGrid.Sections[slot])
            pnl:Dock(FILL)
            pnl:DockMargin(0, 0, 0, 0)
            pnl:SetVisible(true)
            pnl:InvalidateLayout(true)
        elseif slot == 5 and IsValid(frame.Place5) then
            frame.Place5:SetParent(frame.BombGrid.Sections[5])
            frame.Place5:Dock(FILL)
            frame.Place5:SetVisible(true)
        elseif slot == 6 and IsValid(frame.Place6) then
            frame.Place6:SetParent(frame.BombGrid.Sections[6])
            frame.Place6:Dock(FILL)
            frame.Place6:SetVisible(true)
        end
    end
end

local function ensurePanelLayout(frame)
    if IsValid(frame.BombGrid) then return end
    frame.ContentHolder:Clear()
    local grid = buildBombGrid(frame.ContentHolder)
    frame.BombGrid = grid
    frame.HiddenBin = vgui.Create("EditablePanel", frame.ContentHolder)
    frame.HiddenBin:SetVisible(false)

    frame.ThermoSection = makeSection(frame.HiddenBin, "Thermo Regulation Module")
    frame.WireSection = makeSection(frame.HiddenBin, "Wire Module")
    frame.KeypadSection = makeSection(frame.HiddenBin, "Keypad Module")
    frame.SpiralSection = makeSection(frame.HiddenBin, "Spiral Lock")
    frame.TamperSection = makeSection(frame.HiddenBin, "Anti-Tamper Device")
    frame.MemorySection = makeSection(frame.HiddenBin, "Memory (Network Stabilization)")
    frame.RedBlueSection = makeSection(frame.HiddenBin, "Red & Blue Button")
    frame.MinesSection = makeSection(frame.HiddenBin, "Minesweeper (Payload Location Identification)")
    frame.ElectricSection = makeSection(frame.HiddenBin, "Electric Flow Control")
    frame.TwinSection = makeSection(frame.HiddenBin, "Twin Payload Disconnection")
    frame.OverrideSection = makeSection(frame.HiddenBin, "Emergency Nuclear Override")
    frame.CalibrationSection = makeSection(frame.HiddenBin, "Seismic Calibration")
    frame.InterruptSection = makeSection(frame.HiddenBin, "Interrupt Vibration Pattern")
    frame.ReactorSection = makeSection(frame.HiddenBin, "PKB: Reactor Dismantle")
    frame.DrillSection = makeSection(frame.HiddenBin, "PKB: Disable the Tectonic Drill")
    frame.Place5 = addPlaceholder(grid.Sections[5], "Section 5")
    frame.Place5:Dock(FILL)
    frame.Place6 = addPlaceholder(grid.Sections[6], "Section 6")
    frame.Place6:Dock(FILL)

    frame.ModuleCovers = {}
    for slot = 1, 6 do
        local parent = grid.Sections[slot]
        local cover = vgui.Create("EditablePanel", parent)
        cover:Dock(FILL)
        cover:SetZPos(1000)
        cover:SetMouseInputEnabled(true)
        cover.Paint = function(self, w, h)
            if self._coverMode == "power_outage" then
                local blink = math.floor(CurTime() * 2.6) % 2 == 0
                local bg = blink and Color(92, 6, 10, 248) or Color(34, 3, 6, 248)
                local edge = blink and Color(255, 42, 42, 255) or Color(138, 18, 24, 235)
                draw.RoundedBox(10, 0, 0, w, h, bg)
                surface.SetDrawColor(edge)
                surface.DrawOutlinedRect(0, 0, w, h, 3)
                for y = 18, h - 18, 20 do
                    surface.SetDrawColor(Color(255, 42, 42, blink and 90 or 45))
                    surface.DrawLine(14, y, w - 14, y)
                end
                draw.SimpleText("POWER OUTAGE", "KTNE_Title", w / 2, h / 2 - 18, Color(255, 238, 238), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Fix datapad circuit to continue", "KTNE_Body", w / 2, h / 2 + 18, Color(255, 176, 176), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                return
            end
            draw.RoundedBox(10, 0, 0, w, h, Color(78, 82, 90, 245))
            surface.SetDrawColor(Color(140, 146, 154, 255))
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            for y = 18, h - 18, 20 do
                surface.SetDrawColor(Color(98, 104, 112, 90))
                surface.DrawLine(14, y, w - 14, y)
            end
            draw.SimpleText("MODULE LOCKED", "KTNE_Title", w / 2, h / 2 - 12, Color(230, 235, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Identify bomb make in manual", "KTNE_Body", w / 2, h / 2 + 18, Color(200, 208, 214), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        cover.OnMousePressed = function() end
        frame.ModuleCovers[slot] = cover
    end


    -- Thermo Regulation
    frame.ThermoStatus = vgui.Create("DLabel", frame.ThermoSection)
    frame.ThermoStatus:SetPos(14, 42)
    frame.ThermoStatus:SetFont("KTNE_Body")
    frame.ThermoStatus:SetTextColor(THEME.text)
    frame.ThermoStatus:SetSize(420, 22)

    frame.ThermoCoolant = vgui.Create("DNumSlider", frame.ThermoSection)
    frame.ThermoCoolant:SetText("Coolant Flow")
    frame.ThermoCoolant:SetMin(0)
    frame.ThermoCoolant:SetMax(99)
    frame.ThermoCoolant:SetDecimals(0)
    frame.ThermoCoolant.Label:SetTextColor(THEME.text)
    frame.ThermoCoolant.OnValueChanged = function(_, val)
        if not frame._thermoSyncing then
            frame._thermoLocalCoolant = math.Round(tonumber(val) or 0)
        end
    end

    frame.ThermoExhaust = vgui.Create("DNumSlider", frame.ThermoSection)
    frame.ThermoExhaust:SetText("Heat Exhaust")
    frame.ThermoExhaust:SetMin(0)
    frame.ThermoExhaust:SetMax(99)
    frame.ThermoExhaust:SetDecimals(0)
    frame.ThermoExhaust.Label:SetTextColor(THEME.text)
    frame.ThermoExhaust.OnValueChanged = function(_, val)
        if not frame._thermoSyncing then
            frame._thermoLocalExhaust = math.Round(tonumber(val) or 0)
        end
    end

    frame.ThermoApplyCoolant = vgui.Create("DButton", frame.ThermoSection)
    frame.ThermoApplyCoolant:SetText("")
    frame.ThermoApplyCoolant._displayText = "Set Coolant"
    frame.ThermoApplyCoolant.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText) end
    frame.ThermoApplyCoolant.DoClick = function()
        if not (frame._state and frame._state.active) then return end
        sendAction(frame._ent, "thermo_set", {channel = "coolant", value = math.Round(frame.ThermoCoolant:GetValue())})
    end

    frame.ThermoApplyExhaust = vgui.Create("DButton", frame.ThermoSection)
    frame.ThermoApplyExhaust:SetText("")
    frame.ThermoApplyExhaust._displayText = "Set Exhaust"
    frame.ThermoApplyExhaust.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText) end
    frame.ThermoApplyExhaust.DoClick = function()
        if not (frame._state and frame._state.active) then return end
        sendAction(frame._ent, "thermo_set", {channel = "exhaust", value = math.Round(frame.ThermoExhaust:GetValue())})
    end

    frame.ThermoSection.PerformLayout = function(self, w, h)
        if IsValid(frame.ThermoStatus) then frame.ThermoStatus:SetPos(14, 42) frame.ThermoStatus:SetSize(w - 28, 22) end
        if IsValid(frame.ThermoCoolant) then frame.ThermoCoolant:SetPos(14, 78) frame.ThermoCoolant:SetSize(w - 28, 28) end
        if IsValid(frame.ThermoApplyCoolant) then frame.ThermoApplyCoolant:SetPos(14, 110) frame.ThermoApplyCoolant:SetSize(w - 28, 32) end
        if IsValid(frame.ThermoExhaust) then frame.ThermoExhaust:SetPos(14, 150) frame.ThermoExhaust:SetSize(w - 28, 28) end
        if IsValid(frame.ThermoApplyExhaust) then frame.ThermoApplyExhaust:SetPos(14, 182) frame.ThermoApplyExhaust:SetSize(w - 28, 32) end
    end

    -- Wires
    frame.WireStatus = vgui.Create("DLabel", frame.WireSection)
    frame.WireStatus:SetPos(14, 42)
    frame.WireStatus:SetFont("KTNE_Body")
    frame.WireStatus:SetTextColor(THEME.text)
    frame.WireStatus:SetSize(300, 22)
    frame.WireButtons = {}
    for i = 1, 5 do
        local btn = vgui.Create("DButton", frame.WireSection)
        btn:SetText("")
        btn:SetVisible(false)
        btn._wireIndex = i
        btn.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(10, 35, 52, 235))
            surface.SetDrawColor(self._wireCol or Color(85,85,95))
            surface.DrawRect(0, 0, 14, h)
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(self._wireText or "", "KTNE_Body", 24, h / 2, self._txtCol or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function(self)
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "cut_wire", {index = self._wireIndex})
        end
        frame.WireButtons[i] = btn
    end
    frame.WireSection.PerformLayout = function(self, w, h)
        if IsValid(frame.WireStatus) then frame.WireStatus:SetPos(14, 42) end
        for i, btn in ipairs(frame.WireButtons or {}) do
            btn:SetPos(14, 72 + (i - 1) * 34)
            btn:SetSize(w - 28, 28)
        end
    end

    -- Keypad
    frame.KeypadStatus = vgui.Create("DLabel", frame.KeypadSection)
    frame.KeypadStatus:SetPos(14, 42)
    frame.KeypadStatus:SetFont("KTNE_Body")
    frame.KeypadStatus:SetTextColor(THEME.text)
    frame.KeypadStatus:SetSize(320, 22)
    frame.KeypadButtons = {}
    for i = 1, 4 do
        local btn = vgui.Create("DButton", frame.KeypadSection)
        btn:SetFont("KTNE_SubTitle")
        btn.Paint = function(self, w, h)
            paintHoloButton(self, w, h, self._displayText or self:GetText())
        end
        btn.DoClick = function(self)
            if not (frame._state and frame._state.active) then return end
            if not self._symbol then return end
            sendAction(frame._ent, "press_symbol", {symbol = self._symbol})
        end
        frame.KeypadButtons[i] = btn
    end
    frame.KeypadSection.PerformLayout = function(self, w, h)
        if IsValid(frame.KeypadStatus) then frame.KeypadStatus:SetPos(14, 42) end
        local gap = 10
        local bw = math.floor((w - 14 * 2 - gap) / 2)
        local bh = 56
        for i, btn in ipairs(frame.KeypadButtons or {}) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            btn:SetPos(14 + col * (bw + gap), 78 + row * (bh + gap))
            btn:SetSize(bw, bh)
        end
    end

    -- Spiral
    frame.SpiralStatus = vgui.Create("DLabel", frame.SpiralSection)
    frame.SpiralStatus:SetPos(14, 42)
    frame.SpiralStatus:SetFont("KTNE_Body")
    frame.SpiralStatus:SetTextColor(THEME.text)
    frame.SpiralStatus:SetSize(300, 22)
    frame.SpiralDigits = {}
    for i = 1, 8 do
        local wrap = vgui.Create("DPanel", frame.SpiralSection)
        wrap.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(8, 28, 42, 240))
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local up = vgui.Create("DButton", wrap)
        up:SetText("")
        up._displayText = "?"
        up:SetFont("KTNE_Body")
        up.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText or "?") end
        local num = vgui.Create("DLabel", wrap)
        num:SetFont("KTNE_SubTitle")
        num:SetTextColor(THEME.amber)
        num:SetContentAlignment(5)
        local down = vgui.Create("DButton", wrap)
        down:SetText("")
        down._displayText = "?"
        down:SetFont("KTNE_Body")
        down.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText or "?") end
        up.DoClick = function()
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "spiral_adjust", {index = i, delta = 1})
        end
        down.DoClick = function()
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "spiral_adjust", {index = i, delta = -1})
        end
        wrap.Up, wrap.Num, wrap.Down = up, num, down
        wrap.PerformLayout = function(self, w, h)
            up:SetPos(0, 0) up:SetSize(w, 28)
            num:SetPos(0, 32) num:SetSize(w, 24)
            down:SetPos(0, 60) down:SetSize(w, 28)
        end
        frame.SpiralDigits[i] = wrap
    end
    frame.SpiralSection.PerformLayout = function(self, w, h)
        if IsValid(frame.SpiralStatus) then frame.SpiralStatus:SetPos(14, 42) end
        local gap = 6
        local cw = math.floor((w - 14 * 2 - gap * 7) / 8)
        for i, wrap in ipairs(frame.SpiralDigits or {}) do
            wrap:SetPos(14 + (i - 1) * (cw + gap), 86)
            wrap:SetSize(cw, 90)
        end
    end

    -- Memory
    frame.MemoryStatus = vgui.Create("DLabel", frame.MemorySection)
    frame.MemoryStatus:SetPos(14, 42)
    frame.MemoryStatus:SetFont("KTNE_Body")
    frame.MemoryStatus:SetTextColor(THEME.text)
    frame.MemoryStatus:SetSize(360, 22)
    frame.MemoryButtons = {}
    for i = 1, 9 do
        local btn = vgui.Create("DButton", frame.MemorySection)
        btn:SetText("")
        btn._memoryKey = i
        btn.Paint = function(self, w, h)
            local lit = false
            local preview = frame._memoryPreview
            if preview and preview.seq and preview.start then
                local elapsed = CurTime() - preview.start
                local step = math.floor(elapsed / 0.45) + 1
                local maxStep = #preview.seq * 2 - 1
                if step >= 1 and step <= maxStep and step % 2 == 1 then
                    local seqIndex = math.floor((step + 1) / 2)
                    lit = preview.seq[seqIndex] == self._memoryKey
                end
            end
            local bg = lit and Color(248, 248, 255, 235) or Color(92, 96, 104, 220)
            if frame._state and frame._state.modules and frame._state.modules.memory and frame._state.modules.memory.solved then
                bg = THEME.success
            end
            draw.RoundedBox(8, 0, 0, w, h, bg)
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(tostring(self._memoryKey), "KTNE_SubTitle", w / 2, h / 2, lit and Color(12, 18, 24) or THEME.bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function(self)
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "memory_press", {key = self._memoryKey})
        end
        frame.MemoryButtons[i] = btn
    end
    frame.MemorySection.PerformLayout = function(self, w, h)
        if IsValid(frame.MemoryStatus) then frame.MemoryStatus:SetPos(14, 42) end
        local gap = 10
        local bw = math.floor((w - 14 * 2 - gap * 2) / 3)
        local bh = 42
        for i, btn in ipairs(frame.MemoryButtons or {}) do
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            btn:SetPos(14 + col * (bw + gap), 78 + row * (bh + gap))
            btn:SetSize(bw, bh)
        end
    end


    -- Red & Blue Button
    frame.RedBlueStatus = vgui.Create("DLabel", frame.RedBlueSection)
    frame.RedBlueStatus:SetPos(14, 42)
    frame.RedBlueStatus:SetFont("KTNE_Body")
    frame.RedBlueStatus:SetTextColor(THEME.text)
    frame.RedBlueStatus:SetSize(420, 22)
    frame.RedBlueButtons = {}
    for _, colorName in ipairs({"Red", "Blue"}) do
        local btn = vgui.Create("DButton", frame.RedBlueSection)
        btn:SetText("")
        btn._rbColor = colorName
        btn.Paint = function(self, w, h)
            local bg = self._rbColor == "Red" and Color(130, 40, 46, 235) or Color(36, 82, 156, 235)
            draw.RoundedBox(10, 0, 0, w, h, bg)
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(self._rbColor, "KTNE_SubTitle", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function(self)
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "press_redblue", {color = self._rbColor})
        end
        frame.RedBlueButtons[colorName] = btn
    end
    frame.RedBlueSection.PerformLayout = function(self, w, h)
        if IsValid(frame.RedBlueStatus) then frame.RedBlueStatus:SetPos(14, 42) end
        local bw = w - 28
        if IsValid(frame.RedBlueButtons.Red) then
            frame.RedBlueButtons.Red:SetPos(14, 82)
            frame.RedBlueButtons.Red:SetSize(bw, 46)
        end
        if IsValid(frame.RedBlueButtons.Blue) then
            frame.RedBlueButtons.Blue:SetPos(14, 138)
            frame.RedBlueButtons.Blue:SetSize(bw, 46)
        end
    end

    -- Tamper
    frame.TamperStatus = vgui.Create("DLabel", frame.TamperSection)
    frame.TamperStatus:SetPos(14, 42)
    frame.TamperStatus:SetFont("KTNE_Body")
    frame.TamperStatus:SetTextColor(THEME.text)
    frame.TamperStatus:SetSize(340, 22)

    frame.TamperSources = {}
    frame.TamperReceivers = {}
    for i = 1, 4 do
        local src = vgui.Create("DButton", frame.TamperSection)
        src:SetText("")
        src._sourceIndex = i
        src:Droppable("ktne_tamperwire")
        src.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(10, 35, 52, 235))
            surface.SetDrawColor(self._col or Color(90,90,100))
            surface.DrawRect(0, 0, 18, h)
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(self._txt or "", "KTNE_Body", w / 2 + 8, h / 2, self._txtCol or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        frame.TamperSources[i] = src

        local rcv = vgui.Create("DPanel", frame.TamperSection)
        rcv._receiverIndex = i
        rcv.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(10, 35, 52, 235))
            surface.SetDrawColor(self._col or Color(90,90,100))
            surface.DrawRect(w - 18, 0, 18, h)
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            local text = self._txt or ""
            if self._sourceLabel then text = text .. "  <=  " .. self._sourceLabel end
            draw.SimpleText(text, "KTNE_Body", w / 2, h / 2, self._txtCol or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        rcv:Receiver("ktne_tamperwire", function(self, panels, dropped, menuIndex, x, y)
            if not dropped or not IsValid(panels[1]) then return end
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "tamper_connect", {
                source = panels[1]._sourceIndex,
                receiver = self._receiverIndex
            })
        end)
        frame.TamperReceivers[i] = rcv
    end
    frame.TamperSection.PerformLayout = function(self, w, h)
        if IsValid(frame.TamperStatus) then frame.TamperStatus:SetPos(14, 42) end
        local gap = 8
        local boxW = math.floor((w - 14 * 2 - 60) / 2)
        local boxH = 34
        for i = 1, 4 do
            frame.TamperSources[i]:SetPos(14, 78 + (i - 1) * (boxH + gap))
            frame.TamperSources[i]:SetSize(boxW, boxH)
            frame.TamperReceivers[i]:SetPos(w - 14 - boxW, 78 + (i - 1) * (boxH + gap))
            frame.TamperReceivers[i]:SetSize(boxW, boxH)
        end
    end


    -- Minesweeper
    frame.MinesStatus = vgui.Create("DLabel", frame.MinesSection)
    frame.MinesStatus:SetPos(14, 42)
    frame.MinesStatus:SetFont("KTNE_Body")
    frame.MinesStatus:SetTextColor(THEME.text)
    frame.MinesStatus:SetSize(420, 22)
    frame.MinesButtons = {}
    for y = 1, 5 do
        for x = 1, 5 do
            local idx = (y - 1) * 5 + x
            local btn = vgui.Create("DButton", frame.MinesSection)
            btn:SetText("")
            btn._mineX = x
            btn._mineY = y
            btn.Paint = function(self, w, h)
                local bg = Color(92, 96, 104, 220)
                if frame._state and frame._state.modules and frame._state.modules.mines and frame._state.modules.mines.solved then
                    bg = THEME.success
                end
                draw.RoundedBox(6, 0, 0, w, h, bg)
                surface.SetDrawColor(THEME.lineSoft)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            btn.DoClick = function(self)
                if not (frame._state and frame._state.active) then return end
                sendAction(frame._ent, "mines_click", {x = self._mineX, y = self._mineY})
            end
            frame.MinesButtons[idx] = btn
        end
    end
    frame.MinesSection.PerformLayout = function(self, w, h)
        if IsValid(frame.MinesStatus) then frame.MinesStatus:SetPos(14, 42) end
        local gap = 6
        local size = math.floor(math.min((w - 28 - gap * 4) / 5, (h - 90 - gap * 4) / 5))
        local totalW = size * 5 + gap * 4
        local startX = math.floor((w - totalW) / 2)
        local startY = 78
        for y = 1, 5 do
            for x = 1, 5 do
                local idx = (y - 1) * 5 + x
                local btn = frame.MinesButtons[idx]
                if IsValid(btn) then
                    btn:SetPos(startX + (x - 1) * (size + gap), startY + (y - 1) * (size + gap))
                    btn:SetSize(size, size)
                end
            end
        end
    end

-- Electric Flow Control
frame.ElectricStatus = vgui.Create("DLabel", frame.ElectricSection)
frame.ElectricStatus:SetPos(14, 42)
frame.ElectricStatus:SetFont("KTNE_Body")
frame.ElectricStatus:SetTextColor(THEME.text)
frame.ElectricStatus:SetSize(420, 22)

frame.ElectricSource = vgui.Create("DPanel", frame.ElectricSection)
frame.ElectricSource.Paint = function(_, w, h)
    draw.RoundedBox(6, 0, 0, w, h, Color(12, 44, 62, 232))
    surface.SetDrawColor(Color(232, 210, 80))
    surface.DrawRect(0, 0, 14, h)
    surface.SetDrawColor(THEME.lineSoft)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
    draw.SimpleText("Yellow input", "KTNE_Body", 24, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

frame.ElectricButtons = {}
for _, colorName in ipairs({"Red", "Blue", "Green"}) do
    local btn = vgui.Create("DButton", frame.ElectricSection)
    btn:SetText("")
    btn._wireColor = colorName
    btn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(12, 44, 62, 232))
        surface.SetDrawColor(getColor(self._wireColor))
        surface.DrawRect(0, 0, 14, h)
        surface.SetDrawColor(THEME.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(self._wireColor, "KTNE_Body", 24, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function(self)
        if not (frame._state and frame._state.active) then return end
        sendAction(frame._ent, "electric_connect", {color = self._wireColor})
    end
    frame.ElectricButtons[colorName] = btn
end

frame.ElectricSection.PerformLayout = function(self, w, h)
    if IsValid(frame.ElectricStatus) then frame.ElectricStatus:SetPos(14, 42) end
    if IsValid(frame.ElectricSource) then frame.ElectricSource:SetPos(14, 82) frame.ElectricSource:SetSize(w - 28, 32) end
    local gap = 10
    local bw = w - 28
    local order = {"Red", "Blue", "Green"}
    for i, name in ipairs(order) do
        local btn = frame.ElectricButtons[name]
        if IsValid(btn) then
            btn:SetPos(14, 126 + (i - 1) * (34 + gap))
            btn:SetSize(bw, 34)
        end
    end
end

    -- Twin Payload Disconnection
    frame.TwinSection.Paint = function(self, w, h)
        panelChrome(w, h)
        surface.SetDrawColor(Color(170, 58, 58, 230))
        surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 2)
        surface.SetDrawColor(Color(255, 64, 64, 12))
        surface.DrawRect(4, 42, w - 8, h - 46)
        surface.SetDrawColor(THEME.lineSoft)
        surface.DrawLine(14, 40, w - 14, 40)
        draw.SimpleText("Twin Payload Disconnection", "KTNE_SubTitle", 14, 12, Color(255, 170, 170))
        local twinBoxY = math.floor((h - 76) * 0.5) + 8
        draw.RoundedBox(8, 34, twinBoxY, math.floor((w - 102) / 2), 76, Color(68, 68, 76, 235))
        draw.RoundedBox(8, w - 34 - math.floor((w - 102) / 2), twinBoxY, math.floor((w - 102) / 2), 76, Color(68, 68, 76, 235))
    end

    frame.TwinStatus = vgui.Create("DLabel", frame.TwinSection)
    frame.TwinStatus:SetPos(14, 42)
    frame.TwinStatus:SetFont("KTNE_Body")
    frame.TwinStatus:SetTextColor(Color(255, 216, 216))
    frame.TwinStatus:SetSize(420, 22)

    frame.TwinButtons = {}
    local twinOrder = {"Grey", "Yellow", "Red", "Green", "Blue", "Black"}
    for i, colorName in ipairs(twinOrder) do
        local btn = vgui.Create("DButton", frame.TwinSection)
        btn:SetText("")
        btn._twinIndex = i
        btn._wireColor = colorName
        btn.Paint = function(self, w, h)
            local cut = self._cut
            local lineCol = getColor(self._wireColor)
            if self._wireColor == "White" then lineCol = color_white end
            surface.SetDrawColor(lineCol)
            surface.DrawRect(w / 2 - 4, 0, 8, 28)
            draw.RoundedBox(6, 0, 28, w, h - 28, cut and Color(50, 70, 80, 190) or Color(16, 42, 58, 230))
            surface.SetDrawColor(cut and Color(110, 130, 145) or lineCol)
            surface.DrawRect(0, 28, 14, h - 28)
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(0, 28, w, h - 28, 1)
            draw.SimpleText(cut and "CUT" or "WIRE", "KTNE_Small", w / 2, 28 + (h - 28) / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function(self)
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "twin_cut", {index = self._twinIndex})
        end
        frame.TwinButtons[i] = btn
    end
    frame.TwinSection.PerformLayout = function(self, w, h)
        if IsValid(frame.TwinStatus) then frame.TwinStatus:SetPos(14, 44) end
        local boxW = math.floor((w - 102) / 2)
        local leftX = 34
        local rightX = w - 34 - boxW
        local btnW, btnH = 64, 88
        local boxTop = math.floor((h - 76) * 0.5) + 8
        local btnY = boxTop - 28
        local gap = math.floor((boxW - 24 - (btnW * 3)) / 2)
        local gapSafe = math.max(6, gap)
        for i = 1, 3 do
            local btn = frame.TwinButtons[i]
            if IsValid(btn) then
                btn:SetPos(leftX + 12 + (i - 1) * (btnW + gapSafe), btnY)
                btn:SetSize(btnW, btnH)
            end
        end
        for i = 4, 6 do
            local btn = frame.TwinButtons[i]
            if IsValid(btn) then
                local localIndex = i - 3
                btn:SetPos(rightX + 12 + (localIndex - 1) * (btnW + gapSafe), btnY)
                btn:SetSize(btnW, btnH)
            end
        end
    end


    -- Emergency Nuclear Override
    frame.OverrideStatus = vgui.Create("DLabel", frame.OverrideSection)
    frame.OverrideStatus:SetPos(14, 42)
    frame.OverrideStatus:SetFont("KTNE_Body")
    frame.OverrideStatus:SetTextColor(THEME.text)
    frame.OverrideStatus:SetSize(420, 22)

    frame.OverrideSwitches = {}
    for i = 1, 3 do
        local btn = vgui.Create("DButton", frame.OverrideSection)
        btn:SetText("")
        btn._switchIndex = i
        btn._state = 0
        btn.Paint = function(self, w, h)
            local on = (self._state or 0) == 1
            draw.RoundedBox(10, 0, 0, w, h, on and Color(36, 108, 164, 230) or Color(18, 40, 56, 230))
            surface.SetDrawColor(on and THEME.line or THEME.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            draw.SimpleText("SW" .. tostring(self._switchIndex), "KTNE_Body", w / 2, 22, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(on and "ON" or "OFF", "KTNE_SubTitle", w / 2, h / 2 + 10, on and THEME.success or THEME.amber, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function(self)
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "override_toggle", {index = self._switchIndex})
        end
        frame.OverrideSwitches[i] = btn
    end

    frame.OverrideCheck = vgui.Create("DButton", frame.OverrideSection)
    frame.OverrideCheck:SetText("")
    frame.OverrideCheck._displayText = "CHECK OVERRIDE"
    frame.OverrideCheck.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText) end
    frame.OverrideCheck.DoClick = function()
        if not (frame._state and frame._state.active) then return end
        sendAction(frame._ent, "override_check", {})
    end

    frame.OverrideSection.PerformLayout = function(self, w, h)
        if IsValid(frame.OverrideStatus) then frame.OverrideStatus:SetPos(14, 44) frame.OverrideStatus:SetSize(w - 28, 22) end
        local gap = 12
        local boxW = math.floor((w - 28 - gap * 2) / 3)
        local boxH = 96
        local startX = 14
        local y = math.floor(h * 0.42) - math.floor(boxH * 0.5)
        for i, btn in ipairs(frame.OverrideSwitches or {}) do
            if IsValid(btn) then
                btn:SetPos(startX + (i - 1) * (boxW + gap), y)
                btn:SetSize(boxW, boxH)
            end
        end
        if IsValid(frame.OverrideCheck) then
            frame.OverrideCheck:SetPos(14, y + boxH + 18)
            frame.OverrideCheck:SetSize(w - 28, 38)
        end
    end



    -- Reactor Dismantle
    frame.ReactorSection.Paint = function(self, w, h)
        local mod = frame._state and frame._state.modules and frame._state.modules.reactor or nil
        local bg = (mod and mod.danger and not mod.solved) and Color(24, 8, 8, 252) or Color(6, 18, 28, 252)
        draw.RoundedBox(8, 0, 0, w, h, bg)
    end

    frame.ReactorStatus = vgui.Create("DLabel", frame.ReactorSection)
    frame.ReactorStatus:SetFont("KTNE_Body")
    frame.ReactorStatus:SetTextColor(THEME.text)
    frame.ReactorStatus:SetSize(420, 22)

    frame.ReactorEntry = vgui.Create("DTextEntry", frame.ReactorSection)
    frame.ReactorEntry:SetFont("KTNE_SubTitle")
    frame.ReactorEntry:SetUpdateOnType(false)
    frame.ReactorEntry:SetText("")
    frame.ReactorEntry:SetPlaceholderText("ENTER 4-LETTER CODE")

    frame.ReactorSubmit = vgui.Create("DButton", frame.ReactorSection)
    frame.ReactorSubmit:SetText("")
    frame.ReactorSubmit._displayText = "ACCESS"
    frame.ReactorSubmit.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText) end
    frame.ReactorSubmit.DoClick = function()
        if not IsValid(frame._ent) then return end
        local code = IsValid(frame.ReactorEntry) and frame.ReactorEntry:GetValue() or ""
        sendAction(frame._ent, "reactor_code", {code = code})
    end

    frame.ReactorGridPanels = {}
    for y = 1, 3 do
        frame.ReactorGridPanels[y] = {}
        for x = 1, 3 do
            local btn = vgui.Create("DButton", frame.ReactorSection)
            btn:SetText("")
            btn._rx = x
            btn._ry = y
            btn.Paint = function(self, w, h)
                local mod = frame._state and frame._state.modules and frame._state.modules.reactor or nil
                local filled = mod and mod.grid and mod.grid[self._ry] and mod.grid[self._ry][self._rx] == true
                local bg = filled and Color(110, 22, 22, 255) or Color(26, 34, 42, 240)
                local edge = (mod and mod.danger) and Color(255, 90, 90) or THEME.lineSoft
                draw.RoundedBox(6, 0, 0, w, h, bg)
                surface.SetDrawColor(edge)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
                if filled then
                    draw.SimpleText("X", "KTNE_Title", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
            btn.DoClick = function(self)
                if not IsValid(frame._ent) then return end
                sendAction(frame._ent, "reactor_clear", {x = self._rx, y = self._ry})
            end
            frame.ReactorGridPanels[y][x] = btn
        end
    end

    frame.ReactorSection.PerformLayout = function(self, w, h)
        if IsValid(frame.ReactorStatus) then frame.ReactorStatus:SetPos(14, 42) frame.ReactorStatus:SetSize(w - 28, 22) end
        local mod = frame._state and frame._state.modules and frame._state.modules.reactor or nil
        local unlocked = mod and mod.unlocked
        if IsValid(frame.ReactorEntry) then
            frame.ReactorEntry:SetVisible(not unlocked)
            frame.ReactorEntry:SetPos(math.floor(w * 0.5) - 110, 86)
            frame.ReactorEntry:SetSize(220, 34)
        end
        if IsValid(frame.ReactorSubmit) then
            frame.ReactorSubmit:SetVisible(not unlocked)
            frame.ReactorSubmit:SetPos(math.floor(w * 0.5) - 70, 130)
            frame.ReactorSubmit:SetSize(140, 38)
        end
        local cell, gap = 54, 10
        local gridW = cell * 3 + gap * 2
        local startX = math.floor((w - gridW) * 0.5)
        local startY = 86
        for yy = 1, 3 do
            for xx = 1, 3 do
                local btn = frame.ReactorGridPanels[yy][xx]
                if IsValid(btn) then
                    btn:SetVisible(unlocked == true)
                    btn:SetPos(startX + (xx - 1) * (cell + gap), startY + (yy - 1) * (cell + gap))
                    btn:SetSize(cell, cell)
                end
            end
        end
    end


-- Drill Disable
frame.DrillSection.Paint = function(self, w, h)
    draw.RoundedBox(10, 0, 0, w, h, Color(60, 14, 14, 210))
    surface.SetDrawColor(Color(190, 60, 60, 255))
    surface.DrawOutlinedRect(0, 0, w, h, 2)
    draw.SimpleText("PKB: DISABLE THE TECTONIC DRILL", "KTNE_SubTitle", 14, 12, Color(255, 170, 170))
    local boxX, boxY, boxW, boxH = math.floor(w * 0.5) - 76, 94, 152, 84
    draw.RoundedBox(8, boxX, boxY, boxW, boxH, Color(188, 188, 188, 255))
    surface.SetDrawColor(Color(110, 110, 110, 255))
    surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 2)
    local neckW, neckH = 30, 16
    local neckX = math.floor(w * 0.5) - math.floor(neckW / 2)
    local neckY = boxY + boxH
    draw.RoundedBox(3, neckX, neckY, neckW, neckH, Color(140, 140, 140, 255))
    local tipTopY = neckY + neckH
    local tipH = 28
    surface.SetDrawColor(128, 128, 128, 255)
    draw.NoTexture()
    surface.DrawPoly({
        {x = math.floor(w * 0.5), y = tipTopY + tipH},
        {x = math.floor(w * 0.5) - 18, y = tipTopY},
        {x = math.floor(w * 0.5) + 18, y = tipTopY},
    })
    surface.SetDrawColor(85, 85, 85, 255)
    surface.DrawLine(math.floor(w * 0.5) - 18, tipTopY, math.floor(w * 0.5), tipTopY + tipH)
    surface.DrawLine(math.floor(w * 0.5) + 18, tipTopY, math.floor(w * 0.5), tipTopY + tipH)
    local sideYs = {boxY + 18, boxY + 40, boxY + 62}
    local leftXs = {boxX + 18, boxX + 34, boxX + 50}
    local rightXs = {boxX + boxW - 18, boxX + boxW - 34, boxX + boxW - 50}
    surface.SetDrawColor(Color(35, 35, 35, 255))
    for i = 1, 3 do
        surface.DrawLine(leftXs[i], boxY + boxH, leftXs[i], boxY + boxH + 24)
        surface.DrawLine(rightXs[i], boxY + boxH, rightXs[i], boxY + boxH + 24)
    end
end

frame.DrillStatus = vgui.Create("DLabel", frame.DrillSection)
frame.DrillStatus:SetFont("KTNE_Body")
frame.DrillStatus:SetTextColor(Color(255, 210, 210))
frame.DrillStatus:SetSize(420, 22)

frame.DrillEntry = vgui.Create("DTextEntry", frame.DrillSection)
frame.DrillEntry:SetFont("KTNE_SubTitle")
frame.DrillEntry:SetUpdateOnType(false)
frame.DrillEntry:SetText("")
frame.DrillEntry:SetPlaceholderText("ENTER 6-DIGIT CODE")

frame.DrillSubmit = vgui.Create("DButton", frame.DrillSection)
frame.DrillSubmit:SetText("")
frame.DrillSubmit._displayText = "UNLOCK"
frame.DrillSubmit.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText) end
frame.DrillSubmit.DoClick = function()
    if not IsValid(frame._ent) then return end
    local code = IsValid(frame.DrillEntry) and frame.DrillEntry:GetValue() or ""
    sendAction(frame._ent, "drill_code", {code = code})
end

frame.DrillWireButtons = {}
local drillWireOrder = {"Red", "Blue", "Green", "Black", "White", "Yellow"}
local drillWireColors = {
    Red = Color(190, 54, 54),
    Blue = Color(66, 110, 220),
    Green = Color(78, 190, 110),
    Black = Color(35, 35, 35),
    White = Color(220, 220, 220),
    Yellow = Color(225, 200, 80),
}
for i, colorName in ipairs(drillWireOrder) do
    local btn = vgui.Create("DButton", frame.DrillSection)
    btn:SetText("")
    btn._wireColor = colorName
    btn._cut = false
    btn.Paint = function(self, w, h)
        local col = drillWireColors[self._wireColor] or color_white
        draw.RoundedBox(6, 0, 0, w, h, self._cut and Color(48, 22, 22, 255) or Color(26, 16, 16, 245))
        surface.SetDrawColor(Color(200, 70, 70, 255))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBox(4, 8, 8, 18, h - 16, col)
        draw.SimpleText(self._wireColor .. (self._cut and " - CUT" or ""), "KTNE_Body", w / 2 + 8, h / 2, self._cut and Color(255, 150, 150) or Color(255, 230, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function(self)
        if not IsValid(frame._ent) then return end
        sendAction(frame._ent, "drill_cut", {color = self._wireColor})
    end
    frame.DrillWireButtons[i] = btn
end

frame.DrillSection.PerformLayout = function(self, w, h)
    if IsValid(frame.DrillStatus) then frame.DrillStatus:SetPos(14, 42) frame.DrillStatus:SetSize(w - 28, 22) end
    local mod = frame._state and frame._state.modules and frame._state.modules.drill or nil
    local unlocked = mod and mod.unlocked == true
    if IsValid(frame.DrillEntry) then
        frame.DrillEntry:SetVisible(not unlocked)
        frame.DrillEntry:SetPos(math.floor(w * 0.5) - 120, 218)
        frame.DrillEntry:SetSize(240, 34)
    end
    if IsValid(frame.DrillSubmit) then
        frame.DrillSubmit:SetVisible(not unlocked)
        frame.DrillSubmit:SetPos(math.floor(w * 0.5) - 72, 260)
        frame.DrillSubmit:SetSize(144, 38)
    end
    local leftX = math.floor(w * 0.5) - 210
    local rightX = math.floor(w * 0.5) + 62
    local drillBoxY, drillBoxH = 94, 84
    local wireButtonW, wireButtonH = 148, 36
    local wireGroupH = wireButtonH * 3 + 10 * 2
    local y = drillBoxY + math.floor((drillBoxH - wireGroupH) * 0.5)
    for i, btn in ipairs(frame.DrillWireButtons or {}) do
        if IsValid(btn) then
            local isRight = i > 3
            local row = (i - 1) % 3
            btn:SetPos((isRight and rightX or leftX), y + row * (wireButtonH + 10))
            btn:SetSize(wireButtonW, wireButtonH)
        end
    end
end

    -- Seismic Calibration
    frame.CalibrationStatus = vgui.Create("DLabel", frame.CalibrationSection)
    frame.CalibrationStatus:SetPos(14, 42)
    frame.CalibrationStatus:SetFont("KTNE_Body")
    frame.CalibrationStatus:SetTextColor(THEME.text)
    frame.CalibrationStatus:SetSize(420, 22)

    frame.CalibrationLights = {}
    local calibCols = {
        Color(240, 214, 66),
        Color(74, 146, 255),
        Color(82, 224, 138),
    }
    for i = 1, 3 do
        local pnl = vgui.Create("DPanel", frame.CalibrationSection)
        pnl._calibIndex = i
        pnl.Paint = function(self, w, h)
            local mod = frame._state and frame._state.modules and frame._state.modules.calibration or nil
            local lit = mod and mod.lightVisible and mod.currentLight == self._calibIndex
            local col = lit and calibCols[self._calibIndex] or Color(46, 52, 60, 230)
            draw.RoundedBox(8, 0, 0, w, h, Color(10, 26, 38, 230))
            surface.SetDrawColor(THEME.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.RoundedBox(12, 8, 8, w - 16, h - 16, col)
        end
        frame.CalibrationLights[i] = pnl
    end

    frame.CalibrationPress = vgui.Create("DButton", frame.CalibrationSection)
    frame.CalibrationPress:SetText("")
    frame.CalibrationPress._displayText = "PRESS"
    frame.CalibrationPress.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText) end
    frame.CalibrationPress.DoClick = function()
        if not (frame._state and frame._state.active) then return end
        sendAction(frame._ent, "calibration_press", {})
    end

    frame.CalibrationStarts = {}
    for i = 1, 3 do
        local btn = vgui.Create("DButton", frame.CalibrationSection)
        btn:SetText("")
        btn._startIndex = i
        btn.Paint = function(self, w, h)
            paintHoloButton(self, w, h, "INIT " .. tostring(self._startIndex))
        end
        btn.DoClick = function(self)
            if not (frame._state and frame._state.active) then return end
            sendAction(frame._ent, "calibration_start", {index = self._startIndex})
        end
        frame.CalibrationStarts[i] = btn
    end

    frame.CalibrationSection.PerformLayout = function(self, w, h)
        if IsValid(frame.CalibrationStatus) then frame.CalibrationStatus:SetPos(14, 44) frame.CalibrationStatus:SetSize(w - 28, 22) end
        local gap = 12
        local lightW = math.floor((w - 28 - gap * 2) / 3)
        local topY = 78
        for i, pnl in ipairs(frame.CalibrationLights or {}) do
            if IsValid(pnl) then pnl:SetPos(14 + (i - 1) * (lightW + gap), topY) pnl:SetSize(lightW, 34) end
        end
        if IsValid(frame.CalibrationPress) then
            frame.CalibrationPress:SetPos(math.floor(w * 0.5) - 70, topY + 54)
            frame.CalibrationPress:SetSize(140, 44)
        end
        local startY = topY + 118
        local smallW = math.floor((w - 28 - gap * 2) / 3)
        for i, btn in ipairs(frame.CalibrationStarts or {}) do
            if IsValid(btn) then btn:SetPos(14 + (i - 1) * (smallW + gap), startY) btn:SetSize(smallW, 34) end
        end
    end


    -- Interrupt Vibration Pattern
    frame.InterruptStatus = vgui.Create("DLabel", frame.InterruptSection)
    frame.InterruptStatus:SetPos(14, 42)
    frame.InterruptStatus:SetFont("KTNE_Body")
    frame.InterruptStatus:SetTextColor(THEME.text)
    frame.InterruptStatus:SetSize(420, 22)

    frame.InterruptTimer = vgui.Create("DLabel", frame.InterruptSection)
    frame.InterruptTimer:SetPos(14, 70)
    frame.InterruptTimer:SetFont("KTNE_SubTitle")
    frame.InterruptTimer:SetTextColor(Color(255, 150, 150))
    frame.InterruptTimer:SetText("-")
    frame.InterruptTimer:SetSize(120, 22)

    frame.InterruptMain = vgui.Create("DButton", frame.InterruptSection)
    frame.InterruptMain:SetText("")
    frame.InterruptMain._displayText = "CLICK"
    frame.InterruptMain.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText) end
    frame.InterruptMain.DoClick = function()
        if not (frame._state and frame._state.active) then return end
        sendAction(frame._ent, "interrupt_click", {})
    end

    frame.InterruptStart = vgui.Create("DButton", frame.InterruptSection)
    frame.InterruptStart:SetText("")
    frame.InterruptStart._displayText = "START"
    frame.InterruptStart.Paint = function(self, w, h) paintHoloButton(self, w, h, self._displayText) end
    frame.InterruptStart.DoClick = function()
        if not (frame._state and frame._state.active) then return end
        sendAction(frame._ent, "interrupt_start", {})
    end

    frame.InterruptSection.PerformLayout = function(self, w, h)
        if IsValid(frame.InterruptStatus) then frame.InterruptStatus:SetPos(14, 42) frame.InterruptStatus:SetSize(w - 28, 22) end
        if IsValid(frame.InterruptTimer) then frame.InterruptTimer:SetPos(14, 68) frame.InterruptTimer:SetSize(w - 28, 24) end
        if IsValid(frame.InterruptMain) then frame.InterruptMain:SetPos(math.floor(w * 0.5) - 80, 100) frame.InterruptMain:SetSize(160, 62) end
        if IsValid(frame.InterruptStart) then frame.InterruptStart:SetPos(math.floor(w * 0.5) - 80, 174) frame.InterruptStart:SetSize(160, 36) end
    end
end

local IDENTIFY_MAKES = {"DETPACK", "EMP", "INCENDIARY", "ABBERANT", "SEISMIC", "PKB"}

local IDENTIFY_PAGE_TEXT = {
    DETPACK = {
        "A detonation pack (also called det pack or a detpack) was a small explosive with a remote activator that could be triggered by the user.",
        "The pack was set in place or thrown, and then detonated whenever the user desired.",
    },
    EMP = {
        "A bomb used to fry and disable electronics in an area around the device.",
    },
    INCENDIARY = {
        "A bomb used to set fire to the surrounding area. The payload consists of combustible compounds.",
        "When triggered, it's what sets fire to everything around it.",
        "A regular explosive, make sure you NEVER use a plasma cutter or a Fusion Cutter on this bomb.",
    },
    ABBERANT = {
        "They utilize a non-typical explosive payload. Like nukes, seismic charges and thermal-imploders.",
        "It's impossible to advise you on every type of Aberrant Explosive, the best we can tell you to do is remember your training.",
        "Take into account the consequences if the bomb does go off so you can prepare appropriately.",
        "If the bomb will destroy the whole city, evacuate the whole city.",
    },
    SEISMIC = {
        "A starship-deployed sonic mine built around a resonance core and driven by a compact power cell that doubles as its manual trigger.",
        "Most field variants are spiked with baradium or collapsium gas to amplify the effect and nearly all carry a remote receiver.",
    },
    PKB = {
        "The PKB is an extremely destructive bomb that is an acronym for \"Planet Killing Bomb\".",
        "The thing that makes it a PKB is that it drills deep down into the tectonic plates and causes a big massive explosion that kills all life and or the ability for that celestial body to form life.",
        "Instead of featuring a regular payload the PKB features a reactor that you need to dismantle.",
        "The best way of defusing the PKB is to utilize all the equipment you are given after being trained in Advanced EOD as well as your datapad.",
    },
}

local function buildBombIdentifyPages(currentMake)
    currentMake = string.upper(tostring(currentMake or "DETPACK"))
    local pages = {
        {
            title = "Field Manual Review",
            lines = {
                "Review the dedicated bomb make pages before attempting module work.",
                "Until the correct make is identified, the serial and active modules remain sealed.",
                "For testing, the current bomb make is locked to " .. currentMake .. ".",
            }
        }
    }
    for _, make in ipairs(IDENTIFY_MAKES) do
        pages[#pages + 1] = {
            title = make .. " Identification",
            bombMake = make,
            identifyPage = true,
            lines = IDENTIFY_PAGE_TEXT[make] or {"Bomb identification reference."},
        }
    end
    return pages
end

local function drawSeismicPlate(w, h)
    drawTechPlate(0, 0, w, h, Color(120, 180, 255, 185))
    draw.SimpleText("SEISMIC // GROUND-LOCK ARRAY", "KTNE_SubTitle", 16, 14, THEME.title)
    draw.SimpleText("ANCHOR PISTON CASING", "KTNE_Small", w - 16, 18, THEME.amber, TEXT_ALIGN_RIGHT)

    local x, y, bw, bh = 26, 48, w - 52, h - 76
    draw.RoundedBox(10, x, y, bw, bh, Color(26, 38, 48, 242))
    surface.SetDrawColor(Color(136, 166, 196, 210))
    surface.DrawOutlinedRect(x, y, bw, bh, 2)
    draw.RoundedBox(6, x + 18, y + 18, bw - 36, bh - 54, Color(44, 62, 74, 232))

    local pillarW = math.max(18, math.floor((bw - 86) / 5))
    for i = 0, 4 do
        local px = x + 28 + i * (pillarW + 9)
        draw.RoundedBox(5, px, y + 38, pillarW, bh - 84, Color(116, 130, 140, 235))
        draw.RoundedBox(3, px + 4, y + 48, pillarW - 8, bh - 112, Color(210, 228, 245, 220))
        draw.RoundedBox(4, px - 3, y + bh - 42, pillarW + 6, 18, Color(20, 30, 40, 240))
        surface.SetDrawColor(Color(206, 226, 255, 80 + i * 20))
        surface.DrawOutlinedRect(px, y + 38, pillarW, bh - 84, 1)
    end

    for i = 0, 3 do
        local ay = y + 26 + i * math.max(20, math.floor((bh - 52) / 3))
        drawWireRun(x - 18, ay, x + 18, ay + 6, Color(126, 146, 164, 220))
        drawWireRun(x + bw - 18, ay + 8, x + bw + 18, ay, Color(126, 146, 164, 220))
    end
    drawLabelTag(x + bw / 2 - 54, y + bh - 26, 108, "SEISMIC BUS", Color(140, 190, 255, 180))
end

local function drawPKBPlate(w, h)
    drawTechPlate(0, 0, w, h, Color(170, 170, 200, 185))
    draw.SimpleText("PKB // PLANET KILLING BOMB", "KTNE_SubTitle", 16, 14, THEME.title)
    draw.SimpleText("REACTOR VAULT LOCKBOX", "KTNE_Small", w - 16, 18, THEME.amber, TEXT_ALIGN_RIGHT)

    local x, y, bw, bh = 28, 48, w - 56, h - 76
    draw.RoundedBox(8, x, y, bw, bh, Color(36, 42, 50, 244))
    surface.SetDrawColor(Color(146, 154, 172, 220))
    surface.DrawOutlinedRect(x, y, bw, bh, 2)
    draw.RoundedBox(6, x + 18, y + 16, bw - 36, 22, Color(82, 92, 102, 225))
    draw.RoundedBox(8, x + 26, y + 54, bw - 52, bh - 92, Color(18, 26, 34, 245))
    surface.SetDrawColor(Color(120, 132, 150, 120))
    surface.DrawOutlinedRect(x + 26, y + 54, bw - 52, bh - 92, 1)

    local coreX, coreY = x + bw / 2 - 34, y + bh / 2 - 28
    draw.RoundedBox(8, coreX, coreY, 68, 56, Color(72, 90, 104, 245))
    surface.SetDrawColor(Color(210, 230, 245, 160))
    surface.DrawOutlinedRect(coreX, coreY, 68, 56, 2)
    draw.SimpleText("RX", "KTNE_SubTitle", coreX + 34, coreY + 28, THEME.title, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local cellW = math.max(18, math.floor((bw - 112) / 4))
    for row = 0, 2 do
        for col = 0, 3 do
            local cx = x + 36 + col * (cellW + 8)
            local cy = y + 64 + row * 28
            if not (cx > coreX - 8 and cx < coreX + 76 and cy > coreY - 8 and cy < coreY + 64) then
                draw.RoundedBox(4, cx, cy, cellW, 20, Color(54, 64, 74, 235))
                surface.SetDrawColor(Color(128 + col * 8, 138 + row * 8, 154, 100))
                surface.DrawOutlinedRect(cx, cy, cellW, 20, 1)
            end
        end
    end
    drawLabelTag(x + bw / 2 - 48, y + bh - 28, 96, "PKB LOCK", Color(170, 190, 220, 180))
end

local function drawBombIdentifyDiagram(make, w, h)
    local key = string.upper(tostring(make or "DETPACK"))
    if key == "EMP" then
        drawEMPPlate(w, h)
    elseif key == "INCENDIARY" then
        drawIncendiaryPlate(w, h)
    elseif key == "ABBERANT" then
        drawAberrantPlate(w, h)
    elseif key == "SEISMIC" then
        drawSeismicPlate(w, h)
    elseif key == "PKB" then
        drawPKBPlate(w, h)
    else
        drawDetpackPlate(w, h)
    end
    surface.SetDrawColor(Color(72, 78, 84, 255))
    surface.DrawOutlinedRect(0, 0, w, h, 2)
end

local function buildManualPages(state)
    local manual = state.manual or {}
    local status = state.moduleStatus or {}
    local identified = state.bombIdentified == true
    local pages = buildBombIdentifyPages(state.make)

    local function gatedPage(title, lines)
        if identified then
            return {title = title, lines = lines}
        end
        return {
            title = title,
            lines = {
                "Bomb make not yet identified.",
                "Use the six bomb identification pages first.",
                "Serial-linked module instructions remain locked until the correct make is identified.",
            }
        }
    end

    pages[#pages + 1] = identified and {title = (manual.overview and manual.overview.title or "Technical Overview"), lines = manual.overview and manual.overview.lines or {"No overview available."}} or {
        title = (manual.overview and manual.overview.title or "Technical Overview"),
        lines = {
            "Bomb Make: UNIDENTIFIED",
            "Serial Number: ????",
            "The Field Manual Review page remains first for quick identification briefing.",
            "Covered modules on the panel will open once the correct bomb make is identified.",
        }
    }
    pages[#pages + 1] = gatedPage((manual.wires and manual.wires.title or "Wires") .. (status.wiresSolved and " - SOLVED" or ""), manual.wires and manual.wires.lines or {"No wire instructions."})
    pages[#pages + 1] = gatedPage((manual.keypad and manual.keypad.title or "Keypad") .. (status.keypadSolved and " - SOLVED" or ""), manual.keypad and manual.keypad.lines or {"No keypad instructions."})
    pages[#pages + 1] = gatedPage((manual.spiral and manual.spiral.title or "Spiral Lock") .. (status.spiralSolved and " - SOLVED" or ""), manual.spiral and manual.spiral.lines or {"No spiral instructions."})
    pages[#pages + 1] = gatedPage((manual.tamper and manual.tamper.title or "Anti-Tamper") .. (status.tamperSolved and " - SOLVED" or ""), manual.tamper and manual.tamper.lines or {"No anti-tamper instructions."})
    pages[#pages + 1] = gatedPage((manual.memory and manual.memory.title or "Memory") .. (status.memorySolved and " - SOLVED" or ""), manual.memory and manual.memory.lines or {"No memory instructions."})
    pages[#pages + 1] = gatedPage((manual.redblue and manual.redblue.title or "Red & Blue Button") .. (status.redblueSolved and " - SOLVED" or ""), manual.redblue and manual.redblue.lines or {"No Red & Blue Button instructions."})
    pages[#pages + 1] = gatedPage((manual.mines and manual.mines.title or "Minesweeper") .. (status.minesSolved and " - SOLVED" or ""), manual.mines and manual.mines.lines or {"No Minesweeper instructions."})
    pages[#pages + 1] = gatedPage((manual.electric and manual.electric.title or "Electric Flow Control") .. (status.electricSolved and " - SOLVED" or ""), manual.electric and manual.electric.lines or {"No Electric Flow Control instructions."})
    pages[#pages + 1] = gatedPage((manual.twin and manual.twin.title or "Twin Payload Disconnection") .. (status.twinSolved and " - SOLVED" or ""), manual.twin and manual.twin.lines or {"No Twin Payload Disconnection instructions."})
    pages[#pages + 1] = gatedPage((manual.override and manual.override.title or "Emergency Nuclear Override") .. (status.overrideSolved and " - SOLVED" or ""), manual.override and manual.override.lines or {"No Emergency Nuclear Override instructions."})
    pages[#pages + 1] = gatedPage((manual.calibration and manual.calibration.title or "Seismic Calibration") .. (status.calibrationSolved and " - SOLVED" or ""), manual.calibration and manual.calibration.lines or {"No Seismic Calibration instructions."})
    pages[#pages + 1] = gatedPage((manual.interrupt and manual.interrupt.title or "Interrupt Vibration Pattern") .. (status.interruptSolved and " - SOLVED" or ""), manual.interrupt and manual.interrupt.lines or {"No Interrupt Vibration Pattern instructions."})
    pages[#pages + 1] = gatedPage((manual.reactor and manual.reactor.title or "PKB: Reactor Dismantle") .. (status.reactorSolved and " - SOLVED" or ""), manual.reactor and manual.reactor.lines or {"No reactor dismantle instructions."})
    pages[#pages + 1] = gatedPage((manual.drill and manual.drill.title or "PKB: Disable the Tectonic Drill") .. (status.drillSolved and " - SOLVED" or ""), manual.drill and manual.drill.lines or {"No tectonic drill instructions."})
    pages[#pages + 1] = gatedPage((manual.thermo and manual.thermo.title or "Thermo Regulation") .. (status.thermoSolved and " - SOLVED" or ""), manual.thermo and manual.thermo.lines or {"No thermo instructions."})
    return pages
end

local function getManualStateSignature(state)
    local status = state.moduleStatus or {}
    return table.concat({
        tostring(state.make or ""),
        state.bombIdentified and "1" or "0",
        status.wiresSolved and "1" or "0",
        status.keypadSolved and "1" or "0",
        status.spiralSolved and "1" or "0",
        status.tamperSolved and "1" or "0",
        status.memorySolved and "1" or "0",
        status.redblueSolved and "1" or "0",
        status.minesSolved and "1" or "0",
        status.electricSolved and "1" or "0",
        status.twinSolved and "1" or "0",
        status.overrideSolved and "1" or "0",
        status.calibrationSolved and "1" or "0",
        status.interruptSolved and "1" or "0",
        status.reactorSolved and "1" or "0",
        status.drillSolved and "1" or "0",
        status.thermoSolved and "1" or "0",
    }, "|")
end

local function ensureDatapadLayout(frame)
    if not IsValid(frame._datapadPage) then return end
    frame._datapadPage:Clear()

    local canvas = vgui.Create("DPanel", frame._datapadPage)
    canvas:Dock(FILL)
    canvas:DockMargin(12, 12, 12, 12)
    canvas.Paint = function(_, w, h)
        local heatSeal = (frame._state and frame._state.radioactiveSeal) or {active = false, progress = 0}
        local heatProgress = math.Clamp(tonumber(heatSeal.progress or 0) or 0, 0, 100)
        local heatBlink = math.floor(CurTime() * 5) % 2 == 0
        local heatWarningEdge = nil
        if heatSeal.active == true and heatProgress >= 85 then
            heatWarningEdge = heatBlink and Color(255, 96, 96, 245) or Color(94, 24, 24, 210)
        elseif heatSeal.active == true and heatProgress > 50 then
            heatWarningEdge = heatBlink and Color(255, 214, 88, 235) or Color(106, 76, 18, 205)
        end

        draw.RoundedBox(10, 0, 0, w, h, Color(3, 16, 28, 248))
        surface.SetDrawColor(heatWarningEdge or THEME.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local chipW, chipH = math.floor(w * 0.76), math.floor(h * 0.78)
        local chipX, chipY = math.floor((w - chipW) * 0.5), math.floor((h - chipH) * 0.50)

        local function traceLine(points, col)
            surface.SetDrawColor(col)
            for i = 1, #points - 1 do
                local a = points[i]
                local b = points[i + 1]
                surface.DrawLine(a[1], a[2], b[1], b[2])
            end
        end

        local glow = Color(86, 216, 255, 70)
        local line = Color(92, 210, 255, 165)
        local node = Color(170, 238, 255, 200)
        if heatWarningEdge then
            if heatProgress >= 85 then
                glow = heatBlink and Color(255, 96, 96, 80) or Color(94, 24, 24, 65)
            else
                glow = heatBlink and Color(255, 214, 88, 78) or Color(106, 76, 18, 62)
            end
            line = heatWarningEdge
            node = heatWarningEdge
        end

        draw.RoundedBox(10, chipX - 8, chipY - 8, chipW + 16, chipH + 16, Color(8, 28, 44, 255))
        surface.SetDrawColor(heatWarningEdge or glow)
        surface.DrawOutlinedRect(chipX - 8, chipY - 8, chipW + 16, chipH + 16, 2)
        draw.RoundedBox(8, chipX, chipY, chipW, chipH, Color(2, 10, 18, 255))
        surface.SetDrawColor(heatWarningEdge or THEME.line)
        surface.DrawOutlinedRect(chipX, chipY, chipW, chipH, 2)
        draw.SimpleText("DATAPAD ACCESS TERMINAL", "KTNE_SubTitle", chipX + chipW / 2, chipY - 22, THEME.accentWarm, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local traces = {
            {{0, h * 0.14}, {chipX - 86, h * 0.14}, {chipX - 86, chipY + chipH * 0.14}, {chipX, chipY + chipH * 0.14}},
            {{0, h * 0.29}, {chipX - 116, h * 0.29}, {chipX - 116, chipY + chipH * 0.34}, {chipX, chipY + chipH * 0.34}},
            {{0, h * 0.50}, {chipX - 136, h * 0.50}, {chipX - 136, chipY + chipH * 0.50}, {chipX, chipY + chipH * 0.50}},
            {{0, h * 0.72}, {chipX - 96, h * 0.72}, {chipX - 96, chipY + chipH * 0.72}, {chipX, chipY + chipH * 0.72}},
            {{0, h * 0.87}, {chipX - 72, h * 0.87}, {chipX - 72, chipY + chipH * 0.88}, {chipX, chipY + chipH * 0.88}},
            {{w, h * 0.16}, {chipX + chipW + 84, h * 0.16}, {chipX + chipW + 84, chipY + chipH * 0.18}, {chipX + chipW, chipY + chipH * 0.18}},
            {{w, h * 0.32}, {chipX + chipW + 120, h * 0.32}, {chipX + chipW + 120, chipY + chipH * 0.36}, {chipX + chipW, chipY + chipH * 0.36}},
            {{w, h * 0.52}, {chipX + chipW + 134, h * 0.52}, {chipX + chipW + 134, chipY + chipH * 0.54}, {chipX + chipW, chipY + chipH * 0.54}},
            {{w, h * 0.74}, {chipX + chipW + 96, h * 0.74}, {chipX + chipW + 96, chipY + chipH * 0.72}, {chipX + chipW, chipY + chipH * 0.72}},
            {{w, h * 0.88}, {chipX + chipW + 76, h * 0.88}, {chipX + chipW + 76, chipY + chipH * 0.86}, {chipX + chipW, chipY + chipH * 0.86}},
            {{w * 0.18, 0}, {w * 0.18, chipY - 88}, {chipX + chipW * 0.26, chipY - 88}, {chipX + chipW * 0.26, chipY}},
            {{w * 0.50, 0}, {w * 0.50, chipY - 108}, {chipX + chipW * 0.50, chipY - 108}, {chipX + chipW * 0.50, chipY}},
            {{w * 0.82, 0}, {w * 0.82, chipY - 76}, {chipX + chipW * 0.74, chipY - 76}, {chipX + chipW * 0.74, chipY}},
            {{w * 0.20, h}, {w * 0.20, chipY + chipH + 80}, {chipX + chipW * 0.28, chipY + chipH + 80}, {chipX + chipW * 0.28, chipY + chipH}},
            {{w * 0.50, h}, {w * 0.50, chipY + chipH + 110}, {chipX + chipW * 0.50, chipY + chipH + 110}, {chipX + chipW * 0.50, chipY + chipH}},
            {{w * 0.80, h}, {w * 0.80, chipY + chipH + 84}, {chipX + chipW * 0.72, chipY + chipH + 84}, {chipX + chipW * 0.72, chipY + chipH}},
        }

        for _, pts in ipairs(traces) do
            traceLine(pts, glow)
            traceLine(pts, line)
            for _, pt in ipairs(pts) do
                surface.SetDrawColor(node)
                surface.DrawRect(pt[1] - 2, pt[2] - 2, 4, 4)
            end
        end

        local seismic = (frame._state and frame._state.seismicControl) or {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}}
        local pkb = (frame._state and frame._state.pkbControl) or {active = false, phase = "idle", timer = 0, colors = {}, connections = {}, blocked = {}, completed = {}}
        local seal = (frame._state and frame._state.radioactiveSeal) or {active = false, progress = 0, holding = false}
        local blinkOn = math.floor(CurTime() * 4) % 2 == 0

        local boxX = chipX + chipW * 0.13
        local boxY = chipY + chipH * 0.08
        local boxW = chipW * 0.76
        local boxH = chipH * 0.82
        draw.RoundedBox(8, boxX, boxY, boxW, boxH, Color(4, 18, 28, 220))
        surface.SetDrawColor(THEME.line)
        surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 2)

        local centerX = boxX + boxW / 2
        if pkb.active == true then
            local titleCol = (pkb.phase == "outage") and (blinkOn and Color(255, 120, 120) or Color(110, 18, 18)) or THEME.text
            draw.SimpleText("PLANET KILLING BOMB / POWER RESTORATION", "KTNE_SubTitle", centerX, boxY + 20, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            local subtitle = pkb.phase == "outage" and "POWER OUTAGE IN PROGRESS - CONNECT ALL CIRCUITS" or "Power stable. Stand by for the next outage cycle."
            draw.SimpleText(subtitle, "KTNE_Body", centerX, boxY + 42, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.format("Phase Timer: %ds", math.max(0, tonumber(pkb.timer or 0) or 0)), "KTNE_Body", centerX, boxY + 64, THEME.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif seismic.active == true then
            local titleCol = THEME.text
            if seismic.phase == "alarm" then
                titleCol = blinkOn and Color(255, 140, 140) or Color(110, 28, 28)
            elseif seismic.phase == "preview" then
                titleCol = blinkOn and Color(240, 248, 255) or Color(120, 144, 160)
            end
            draw.SimpleText("SEISMIC BOMB / STABILIZE SEISMIC ACTIVITY", "KTNE_SubTitle", centerX, boxY + 30, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            local subtitle = "Await the next seismic cycle."
            if seismic.phase == "preview" then
                subtitle = "Memorize the lit pillars now."
            elseif seismic.phase == "alarm" then
                subtitle = "SEISMIC ACTIVITY IN PROGRESS, STABILIZATION REQUIRED IMMEDIATELY"
            end
            draw.SimpleText(subtitle, "KTNE_Body", centerX, boxY + 48, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.format("Phase Timer: %ds", math.max(0, tonumber(seismic.timer or 0) or 0)), "KTNE_Body", centerX, boxY + 92, THEME.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif seal.active == true then
            local progress = math.Clamp(tonumber(seal.progress or 0) or 0, 0, 100)
            local warnBlink = math.floor(CurTime() * 5) % 2 == 0
            local warningEdge = nil
            if progress >= 85 then
                draw.RoundedBox(8, boxX, boxY, boxW, boxH, Color(38, 8, 8, 218))
                warningEdge = warnBlink and Color(255, 96, 96, 245) or Color(94, 24, 24, 210)
            elseif progress > 50 then
                draw.RoundedBox(8, boxX, boxY, boxW, boxH, Color(42, 30, 6, 214))
                warningEdge = warnBlink and Color(255, 214, 88, 235) or Color(106, 76, 18, 205)
            end
            if warningEdge then
                surface.SetDrawColor(warningEdge)
                surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 2)
            end
            local titleCol = warningEdge and color_white or (seal.holding and THEME.good or THEME.text)
            draw.SimpleText("DATAPAD MODULE / HEAT VENTING", "KTNE_SubTitle", centerX, boxY + 30, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Hold the datapad control to vent excess heat before the bomb overheats.", "KTNE_Body", centerX, boxY + 54, THEME.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            local barW, barH = math.floor(boxW * 0.64), 24
            local barX, barY = centerX - barW / 2, boxY + 90
            draw.RoundedBox(6, barX, barY, barW, barH, Color(2, 10, 18, 245))
            surface.SetDrawColor(THEME.line)
            surface.DrawOutlinedRect(barX, barY, barW, barH, 1)
            draw.RoundedBox(5, barX + 3, barY + 3, math.max(0, (barW - 6) * (progress / 100)), barH - 6, progress >= 80 and Color(220, 70, 70, 220) or Color(64, 190, 230, 220))
            draw.SimpleText(string.format("Excess Heat: %d%%", progress), "KTNE_Body", centerX, barY + barH + 22, progress >= 80 and THEME.bad or THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("DATAPAD MODULE BAY", "KTNE_SubTitle", centerX, boxY + 34, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("No active datapad process loaded on this bomb.", "KTNE_Body", centerX, boxY + 78, THEME.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    frame.DatapadCanvas = canvas

    frame.DatapadButtons = {}
    local pillars = vgui.Create("EditablePanel", canvas)
    pillars:SetSize(720, 250)
    pillars.Think = function(self)
        local pw, ph = canvas:GetWide(), canvas:GetTall()
        self:SetPos(math.floor((pw - self:GetWide()) * 0.5), math.floor(ph * 0.36))
    end
    pillars.Paint = nil
    frame.DatapadPillars = pillars

    frame.PKBCells = {}
    local pkbGrid = vgui.Create("EditablePanel", canvas)
    pkbGrid:SetSize(816, 340)
    pkbGrid.Think = function(self)
        local pw, ph = canvas:GetWide(), canvas:GetTall()
        self:SetPos(math.floor((pw - self:GetWide()) * 0.5), math.floor(ph * 0.30))
        local pkb = (frame._state and frame._state.pkbControl) or {active = false}
        self:SetVisible(pkb.active == true)
        local seismic = (frame._state and frame._state.seismicControl) or {active = false}
        local seal = (frame._state and frame._state.radioactiveSeal) or {active = false}
        if IsValid(frame.DatapadPillars) then frame.DatapadPillars:SetVisible(seismic.active == true and pkb.active ~= true and seal.active ~= true) end
        if frame._pkbDraggingColor and not input.IsMouseDown(MOUSE_LEFT) then
            local cell = frame._pkbHoveredCell
            sendAction(frame._ent, "pkb_release", {color = frame._pkbDraggingColor, x = cell and cell.x or -1, y = cell and cell.y or -1})
            frame._pkbDraggingColor = nil
            frame._pkbHoveredCell = nil
            frame._pkbLocalVisited = nil
        end
    end
    pkbGrid.Paint = function(self, w, h)
        local pkb = (frame._state and frame._state.pkbControl) or {active = false, phase = "idle", blocked = {}, connections = {}, completed = {}}
        if pkb.active ~= true then return end
        local outage = pkb.phase == "outage"
        draw.RoundedBox(8, 0, 0, w, h, outage and Color(8,8,8,240) or Color(8, 22, 34, 220))
        surface.SetDrawColor(outage and Color(150,40,40,200) or THEME.line)
        surface.DrawOutlinedRect(0,0,w,h,2)
    end
    frame.PKBGrid = pkbGrid

    for i = 1, 5 do
        local btn = vgui.Create("DButton", pillars)
        btn:SetText("")
        btn:SetSize(120, 196)
        btn:SetPos((i - 1) * 144 + 8, 0)
        btn.DoClick = function()
            sendAction(frame._ent, "seismic_press", {index = i})
        end
        btn.Paint = function(self, w, h)
            local seismic = (frame._state and frame._state.seismicControl) or {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}}
            local activeModule = seismic.active == true
            local lit = false
            if activeModule then
                if seismic.phase == "preview" then
                    for _, v in ipairs(seismic.pattern or {}) do if v == i then lit = true break end end
                elseif seismic.phase == "alarm" and seismic.pressed and seismic.pressed[i] then
                    lit = true
                end
            end
            self:SetEnabled(activeModule and seismic.phase == "alarm")
            local base = lit and Color(240, 245, 255, 245) or Color(76, 86, 96, 220)
            local edge = lit and Color(255, 255, 255, 220) or THEME.lineSoft
            local btnCol = (seismic.phase == "alarm") and Color(110, 28, 28, 230) or Color(14, 42, 56, 230)
            if seismic.phase == "alarm" and lit then
                btnCol = Color(28, 92, 120, 230)
            end
            draw.RoundedBox(6, 18, 0, w - 36, 124, base)
            surface.SetDrawColor(edge)
            surface.DrawOutlinedRect(18, 0, w - 36, 124, 2)
            draw.RoundedBox(6, 8, 148, w - 16, 40, btnCol)
            surface.SetDrawColor(THEME.line)
            surface.DrawOutlinedRect(8, 148, w - 16, 40, 1)
            draw.SimpleText(string.format("PILLAR %d", i), "KTNE_Small", w / 2, 168, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        frame.DatapadButtons[i] = btn
    end

    
    for gy = 1, 5 do
        for gx = 1, 12 do
            local cell = vgui.Create("DButton", pkbGrid)
            cell:SetText("")
            cell:SetSize(62, 62)
            cell:SetPos((gx - 1) * 68 + 4, (gy - 1) * 68 + 4)
            cell._x = gx
            cell._y = gy
            cell.OnMousePressed = function(self)
                local pkb = (frame._state and frame._state.pkbControl) or {active = false, phase = "idle", connections = {}}
                if pkb.active ~= true or pkb.phase ~= "outage" then return end
                for color, conn in pairs(pkb.connections or {}) do
                    if conn.output and conn.output.x == self._x and conn.output.y == self._y and not (pkb.completed and pkb.completed[color]) then
                        frame._pkbDraggingColor = color
                        frame._pkbHoveredCell = {x = self._x, y = self._y}
                        frame._pkbLocalVisited = {[tostring(self._x) .. ":" .. tostring(self._y)] = true}
                        sendAction(frame._ent, "pkb_begin", {color = color, x = self._x, y = self._y})
                        break
                    end
                end
            end
            cell.OnCursorEntered = function(self)
                frame._pkbHoveredCell = {x = self._x, y = self._y}
                if frame._pkbDraggingColor and input.IsMouseDown(MOUSE_LEFT) then
                    frame._pkbLocalVisited = frame._pkbLocalVisited or {}
                    frame._pkbLocalVisited[tostring(self._x) .. ":" .. tostring(self._y)] = true
                    sendAction(frame._ent, "pkb_hover", {color = frame._pkbDraggingColor, x = self._x, y = self._y}, 0.02, tostring(self._x) .. ":" .. tostring(self._y))
                end
            end
            cell.Paint = function(self, w, h)
                local pkb = (frame._state and frame._state.pkbControl) or {active = false, phase = "idle", blocked = {}, connections = {}, completed = {}}
                if pkb.active ~= true then return end
                local outage = pkb.phase == "outage"
                local bg = outage and Color(20,20,20,240) or Color(34,40,48,200)
                local edge = outage and Color(60,60,60,180) or THEME.lineSoft
                local key = tostring(self._x) .. ":" .. tostring(self._y)
                local label = ""
                if pkb.blocked and pkb.blocked[key] then
                    bg = Color(34, 12, 12, 245)
                    edge = Color(160, 54, 54, 220)
                    label = "X"
                end
                local colorFill = {
                    Red = {live = Color(144,40,40,180), dark = Color(120,30,30,245), recv = Color(80,18,18,245)},
                    Green = {live = Color(40,132,74,180), dark = Color(24,96,54,245), recv = Color(18,72,40,245)},
                    Blue = {live = Color(44,84,170,180), dark = Color(26,52,120,245), recv = Color(18,40,90,245)},
                }
                for _, color in ipairs({"Red","Green","Blue"}) do
                    local conn = pkb.connections and pkb.connections[color] or nil
                    local theme = colorFill[color]
                    if conn then
                        if conn.output and conn.output.x == self._x and conn.output.y == self._y then
                            bg = theme.dark
                            label = "OUT"
                        elseif conn.receiver and conn.receiver.x == self._x and conn.receiver.y == self._y then
                            bg = theme.recv
                            label = "IN"
                            if pkb.completed and pkb.completed[color] then
                                bg = Color(180,180,180,245)
                                label = "OK"
                            end
                        elseif pkb.completedPaths and pkb.completedPaths[color] and pkb.completedPaths[color][key] then
                            bg = theme.live
                        elseif frame._pkbDraggingColor == color and frame._pkbLocalVisited and frame._pkbLocalVisited[key] then
                            bg = theme.live
                        end
                    end
                end
                draw.RoundedBox(4, 0, 0, w, h, bg)
                surface.SetDrawColor(edge)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                if label ~= "" then
                    draw.SimpleText(label, "KTNE_Body", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
            frame.PKBCells[#frame.PKBCells + 1] = cell
        end
    end
    local hold = vgui.Create("DButton", canvas)
    hold:SetText("")
    hold:SetSize(280, 54)
    hold._holding = false
    hold._nextHoldPing = 0
    hold.Think = function(self)
        local seal = (frame._state and frame._state.radioactiveSeal) or {active = false}
        local seismic = (frame._state and frame._state.seismicControl) or {active = false}
        local pkb = (frame._state and frame._state.pkbControl) or {active = false}
        local visible = seal.active == true and seismic.active ~= true and pkb.active ~= true
        self:SetVisible(visible)
        self:SetEnabled(visible)
        self:SetPos(math.floor((canvas:GetWide() - self:GetWide()) * 0.5), math.floor(canvas:GetTall() * 0.68))
        if not visible and self._holding then
            self._holding = false
            sendAction(frame._ent, "radio_hold", {holding = false}, 0.05, "release")
        end
        if visible and self._holding and CurTime() >= (self._nextHoldPing or 0) then
            self._nextHoldPing = CurTime() + 0.25
            sendAction(frame._ent, "radio_hold", {holding = true}, 0.2, "hold")
        end
    end
    hold.OnMousePressed = function(self)
        if not self:IsEnabled() then return end
        self._holding = true
        self._nextHoldPing = CurTime() + 0.25
        sendAction(frame._ent, "radio_hold", {holding = true}, 0.05, "press")
    end
    hold.OnMouseReleased = function(self)
        if not self._holding then return end
        self._holding = false
        sendAction(frame._ent, "radio_hold", {holding = false}, 0.05, "release")
    end
    hold.Paint = function(self, w, h)
        local seal = (frame._state and frame._state.radioactiveSeal) or {holding = false}
        local hot = self:IsDown() or self._holding or seal.holding == true
        draw.RoundedBox(7, 0, 0, w, h, hot and Color(46, 154, 118, 235) or Color(16, 58, 74, 235))
        surface.SetDrawColor(hot and Color(160, 255, 210, 220) or THEME.line)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.SimpleText(hot and "VENTING HEAT" or "HOLD TO VENT", "KTNE_SubTitle", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    frame.DatapadHoldButton = hold
end


local function ensureManualLayout(frame)
    if IsValid(frame.BookRoot) then return end
    frame.ContentHolder:Clear()
    local root = vgui.Create("EditablePanel", frame.ContentHolder)
    root:Dock(FILL)
    root.Paint = nil
    frame.ManualRoot = root

    local topBar = vgui.Create("EditablePanel", root)
    topBar:Dock(TOP)
    topBar:SetTall(32)
    topBar:DockMargin(0, 0, 0, 6)
    topBar.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.lineSoft)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local stack = vgui.Create("DPanel", root)
    stack:Dock(FILL)
    stack.Paint = nil

    local outer = vgui.Create("DPanel", stack)
    outer:Dock(FILL)
    outer.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, THEME.book)
        surface.SetDrawColor(THEME.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBox(8, 14, 14, w - 28, h - 28, Color(6, 40, 58, 252))
        surface.SetDrawColor(THEME.lineSoft)
        surface.DrawLine(w / 2, 22, w / 2, h - 22)
        surface.DrawRect(24, 22, w - 48, 6)
    end
    frame.BookRoot = outer

    frame.PageTitle = vgui.Create("DLabel", outer)
    frame.PageTitle:SetPos(36, 28)
    frame.PageTitle:SetFont("KTNE_Title")
    frame.PageTitle:SetTextColor(THEME.title)
    frame.PageTitle:SetSize(900, 32)

    frame.PageNum = vgui.Create("DLabel", outer)

    frame._manualView = frame._manualView or "manual"

    frame._datapadPage = vgui.Create("EditablePanel", stack)
    frame._datapadPage:Dock(FILL)
    frame._datapadPage:SetVisible(false)
    frame._datapadPage.Paint = function(_, w, h)
        local state = frame._state or {}
        local outage = state.powerOutage == true
        draw.RoundedBox(10, 0, 0, w, h, outage and Color(6, 6, 10, 252) or Color(5, 20, 32, 252))
        surface.SetDrawColor(outage and Color(150, 40, 40, 180) or THEME.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    frame.PageNum:SetFont("KTNE_Body")
    frame.PageNum:SetTextColor(Color(132, 224, 255))
    frame.PageNum:SetSize(180, 24)
    frame.PageNum:SetContentAlignment(6)

    local function setManualView(view)
        frame._manualView = view
        local manual = view ~= "datapad"
        if IsValid(frame.BookRoot) then frame.BookRoot:SetVisible(manual) end
        if IsValid(frame.PageTitle) then frame.PageTitle:SetVisible(manual) end
        if IsValid(frame.PageNum) then frame.PageNum:SetVisible(manual) end
        if IsValid(frame.PrevBtn) then frame.PrevBtn:SetVisible(manual) end
        if IsValid(frame.NextBtn) then frame.NextBtn:SetVisible(manual) end
        if IsValid(frame._datapadPage) then frame._datapadPage:SetVisible(not manual) end
        if IsValid(frame._manualTab) then frame._manualTab:InvalidateLayout(true) end
        if IsValid(frame._datapadTab) then frame._datapadTab:InvalidateLayout(true) end
        if manual and frame._refreshManual then frame:_refreshManual() end
    end
    frame._setManualView = setManualView

    local function makeManualTab(label, viewName)
        local btn = vgui.Create("DButton", topBar)
        btn:Dock(LEFT)
        btn:DockMargin(0, 0, 8, 0)
        btn:SetText("")
        surface.SetFont("KTNE_Body")
        local tw = surface.GetTextSize(label or "")
        btn:SetWide(math.max(viewName == "datapad" and 220 or 90, tw + 30))
        btn._displayText = label
        btn._viewName = viewName
        btn:SetFont("KTNE_Body")
        btn.Paint = function(self, w, h)
            local active = frame._manualView == self._viewName
            local bg = active and Color(20, 66, 88, 245) or Color(6, 28, 40, 220)
            local edge = active and THEME.line or THEME.lineSoft
            local textCol = active and THEME.title or THEME.textDim
            if self._viewName == "datapad" then
                local seismic = (frame._state and frame._state.seismicControl) or {active = false, phase = "idle"}
                local pkb = (frame._state and frame._state.pkbControl) or {active = false, phase = "idle"}
                local seal = (frame._state and frame._state.radioactiveSeal) or {active = false, progress = 0}
                if pkb.active == true and pkb.phase == "outage" then
                    local blinkOn = math.floor(CurTime() * 4) % 2 == 0
                    bg = blinkOn and Color(118, 18, 18, 235) or Color(24, 8, 8, 228)
                    edge = Color(230, 90, 90)
                    textCol = Color(255, 212, 212)
                elseif seal.active == true and (tonumber(seal.progress or 0) or 0) >= 85 then
                    local blinkOn = math.floor(CurTime() * 5) % 2 == 0
                    bg = blinkOn and Color(152, 22, 22, 235) or Color(34, 8, 8, 228)
                    edge = Color(255, 92, 92)
                    textCol = Color(255, 222, 222)
                elseif seal.active == true and (tonumber(seal.progress or 0) or 0) > 50 then
                    local blinkOn = math.floor(CurTime() * 5) % 2 == 0
                    bg = blinkOn and Color(174, 132, 18, 235) or Color(42, 30, 6, 228)
                    edge = Color(255, 214, 88)
                    textCol = Color(255, 246, 210)
                elseif seismic.active == true and seismic.phase == "preview" then
                    local blinkOn = math.floor(CurTime() * 4) % 2 == 0
                    bg = blinkOn and Color(210, 218, 226, 235) or Color(76, 88, 98, 220)
                    edge = Color(230, 236, 242)
                    textCol = Color(245, 250, 255)
                end
            end
            draw.RoundedBoxEx(8, 0, 0, w, h, bg, true, true, false, false)
            surface.SetDrawColor(edge)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(self._displayText or "", "KTNE_Body", w / 2, h / 2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function() setManualView(viewName) end
        return btn
    end

    frame._manualTab = makeManualTab("Manual", "manual")
    frame._datapadTab = makeManualTab("Datapad Access Terminal", "datapad")

    local text = vgui.Create("RichText", outer)
    text:SetVerticalScrollbarEnabled(false)
    function text:PerformLayout()
        self:SetFontInternal("KTNE_Body")
        self:SetFGColor(THEME.text)
    end
    frame.PageText = text

    frame.PageNotes = vgui.Create("DTextEntry", outer)
    frame.PageNotes:SetMultiline(true)
    frame.PageNotes:SetVisible(false)
    frame.PageNotes:SetEditable(false)
    frame.PageNotes:SetCursorColor(Color(0, 0, 0, 0))
    frame.PageNotes:SetKeyboardInputEnabled(false)
    frame.PageNotes:SetFont("KTNE_Body")
    frame.PageNotes:SetDrawBackground(true)
    frame.PageNotes:SetTextColor(THEME.text)
    frame.PageNotes:SetPaintBackground(false)
    frame.PageNotes.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(4, 28, 40, 220))
        surface.SetDrawColor(THEME.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(THEME.text, THEME.title, THEME.text)
        if self:GetValue() == "" and not self:HasFocus() then
            draw.SimpleText("Add future identification notes here...", "KTNE_Body", 10, 10, Color(110, 170, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
    frame.PageIdentify = vgui.Create("DButton", outer)
    frame.PageIdentify:SetText("")
    frame.PageIdentify:SetVisible(false)
    frame.PageIdentify.Paint = function(self, w, h)
        paintHoloButton(self, w, h, self._displayText or "Identify Bomb")
    end
    frame.PageIdentify.DoClick = function(self)
        local page = frame._currentManualPage or {}
        if not page.bombMake then return end
        self:SetEnabled(false)
        timer.Simple(0.15, function() if IsValid(self) then self:SetEnabled(true) end end)
        sendAction(frame._ent, "identify_bomb", {make = page.bombMake})
    end

    frame.PageFullDiagram = vgui.Create("DPanel", outer)
    frame.PageFullDiagram:SetVisible(false)
    frame.PageFullDiagram.Paint = function(_, w, h)
        local make = (frame._currentManualPage and frame._currentManualPage.bombMake) or "DETPACK"
        drawBombIdentifyDiagram(make, w, h)
    end

    frame.PageVisualTop = vgui.Create("DPanel", outer)
    frame.PageVisualTop.Paint = function(_, w, h)
        local title = string.lower((frame._currentManualPage and frame._currentManualPage.title) or "")
        if title:find("reactor") or title:find("drill") or title:find("pkb") then
            drawPKBPlate(w, h)
        elseif title:find("calibration") or title:find("interrupt") or title:find("seismic") then
            drawSeismicPlate(w, h)
        elseif title:find("thermo") or title:find("incendiary") then
            drawIncendiaryPlate(w, h)
        elseif title:find("electric") or title:find("emp") then
            drawEMPPlate(w, h)
        elseif title:find("twin payload") or title:find("emergency nuclear override") or title:find("aberrant") or title:find("abberant") then
            drawAberrantPlate(w, h)
        else
            drawDetpackPlate(w, h)
        end
    end

    frame.PageVisualBottom = vgui.Create("DPanel", outer)
    frame.PageVisualBottom.Paint = function(_, w, h)
        drawManualDiagram((frame._currentManualPage and frame._currentManualPage.title) or "", w, h)
    end

    frame.PrevBtn = vgui.Create("DButton", outer)
    frame.PrevBtn:SetText("Prev Page")
    frame.PrevBtn:SetFont("KTNE_Body")
    frame.PrevBtn.Paint = function(self, w, h) paintHoloButton(self, w, h, self:GetText()) end
    frame.PrevBtn.DoClick = function()
        frame._pageIndex = math.max(1, (frame._pageIndex or 1) - 1)
        if frame._refreshManual then frame:_refreshManual() end
    end

    frame.NextBtn = vgui.Create("DButton", outer)
    frame.NextBtn:SetText("Next Page")
    frame.NextBtn:SetFont("KTNE_Body")
    frame.NextBtn.Paint = function(self, w, h) paintHoloButton(self, w, h, self:GetText()) end
    frame.NextBtn.DoClick = function()
        local total = #(frame._manualPages or {})
        frame._pageIndex = math.min(total, (frame._pageIndex or 1) + 1)
        if frame._refreshManual then frame:_refreshManual() end
    end

    outer.PerformLayout = function(self, w, h)
        if IsValid(frame.PageNum) then frame.PageNum:SetPos(w - 220, 32) end
        local gutter = 18
        local leftX, topY = 36, 74
        local leftW = math.floor((w - 72 - gutter) * 0.56)
        local rightX = leftX + leftW + gutter
        local rightW = w - rightX - 36
        local contentH = h - 146
        if IsValid(frame.PageText) then frame.PageText:SetPos(leftX, topY) frame.PageText:SetSize(leftW, contentH) end
        if IsValid(frame.PageNotes) then frame.PageNotes:SetPos(leftX, topY) frame.PageNotes:SetSize(leftW, contentH - 52) end
        if IsValid(frame.PageIdentify) then frame.PageIdentify:SetPos(leftX + math.floor((leftW - 220) / 2), h - 106) frame.PageIdentify:SetSize(220, 34) end
        if IsValid(frame.PageVisualTop) then frame.PageVisualTop:SetPos(rightX, topY) frame.PageVisualTop:SetSize(rightW, math.floor(contentH * 0.5) - 8) end
        if IsValid(frame.PageVisualBottom) then frame.PageVisualBottom:SetPos(rightX, topY + math.floor(contentH * 0.5) + 8) frame.PageVisualBottom:SetSize(rightW, math.floor(contentH * 0.5) - 16) end
        if IsValid(frame.PageFullDiagram) then frame.PageFullDiagram:SetPos(rightX, topY) frame.PageFullDiagram:SetSize(rightW, contentH - 12) end
        if IsValid(frame.PrevBtn) then frame.PrevBtn:SetPos(36, h - 58) frame.PrevBtn:SetSize(160, 34) end
        if IsValid(frame.NextBtn) then frame.NextBtn:SetPos(w - 196, h - 58) frame.NextBtn:SetSize(160, 34) end
    end

    function frame:_refreshManual()
        if not IsValid(frame.PageText) then return end
        local pages = frame._manualPages or {}
        if #pages == 0 then pages = {{title = "Manual", lines = {"No manual pages available."}}} end
        frame._pageIndex = math.Clamp(frame._pageIndex or 1, 1, #pages)
        local page = pages[frame._pageIndex]
        frame._currentManualPage = page
        frame.PageTitle:SetText(page.title or "Manual")
        frame.PageNum:SetText("Page " .. frame._pageIndex .. " / " .. #pages)
        local identifyPage = page.identifyPage == true
        frame.PageText:SetVisible(not identifyPage)
        frame.PageText:SetText("")
        frame.PageText:InsertColorChange(THEME.text.r, THEME.text.g, THEME.text.b, 255)
        for _, line in ipairs(page.lines or {}) do
            frame.PageText:AppendText(line .. "\n\n")
        end
        if IsValid(frame.PageNotes) then
            frame.PageNotes:SetVisible(identifyPage)
            local noteLines = page.lines or {"Bomb identification reference."}
            frame.PageNotes:SetText(table.concat(noteLines, "\n\n"))
            frame.PageNotes:SetCaretPos(0)
        end
        if IsValid(frame.PageIdentify) then
            frame.PageIdentify:SetVisible(identifyPage)
            frame.PageIdentify._displayText = identifyPage and ("Identify Bomb as " .. tostring(page.bombMake or "UNKNOWN")) or ""
            frame.PageIdentify:SetZPos(50)
            frame.PageIdentify:MoveToFront()
        end
        if IsValid(frame.PageVisualTop) then frame.PageVisualTop:SetVisible(not identifyPage) end
        if IsValid(frame.PageVisualBottom) then frame.PageVisualBottom:SetVisible(not identifyPage) end
        if IsValid(frame.PageFullDiagram) then frame.PageFullDiagram:SetVisible(identifyPage) end
        frame.PrevBtn:SetEnabled(frame._pageIndex > 1)
        frame.NextBtn:SetEnabled(frame._pageIndex < #pages)
    end
    ensureDatapadLayout(frame)
    setManualView(frame._manualView or "manual")
end


local function updateIdentificationVisuals(frame)
    local state = frame._state or {}
    local identified = state.bombIdentified == true
    if IsValid(frame.MakeLabel) then
        frame.MakeLabel:SetText("Make: " .. (identified and tostring(state.make or "DETPACK") or "UNIDENTIFIED"))
    end
    if IsValid(frame.SerialLabel) then
        frame.SerialLabel:SetText("Serial: " .. (identified and tostring(state.serial or "----") or "????"))
    end
    if frame.ModuleCovers then
        for slot, cover in pairs(frame.ModuleCovers) do
            local activeId = state.activeSlots and state.activeSlots[slot] or nil
            local outage = state.powerOutage == true
            local covered = (((not identified) or outage) and activeId ~= nil and slot >= 1 and slot <= 6)
            if IsValid(cover) then
                cover._coverMode = outage and "power_outage" or "identify"
                cover:SetVisible(covered)
            end
        end
    end
end


local function updateChat(frame)
    if not IsValid(frame.ChatLogBox) then return end
    local log = (frame._state and frame._state.chatLog) or {}
    local sig = tostring(#log)
    if #log > 0 then
        local last = log[#log]
        sig = sig .. ":" .. tostring(last.seq or #log) .. ":" .. tostring(last.clock or "") .. ":" .. tostring(last.text or "")
    end
    if frame._chatSig == sig then return end
    frame._chatSig = sig
    frame.ChatLogBox:SetText("")
    for _, entry in ipairs(log) do
        local text = tostring(entry.text or "")
        local isWarning = string.sub(text, 1, 10) == "Time left:" or string.find(text, "Strike ", 1, true) ~= nil
        local col = (entry.kind == "dev") and Color(255, 224, 92) or ((entry.kind == "chat") and Color(245, 245, 245) or (isWarning and Color(255, 60, 60) or Color(80, 176, 255)))
        local prefix = "[" .. tostring(entry.clock or "--:--") .. "] [" .. tostring(entry.speaker or "SYSTEM") .. "] "
        frame.ChatLogBox:InsertColorChange(col.r, col.g, col.b, 255)
        frame.ChatLogBox:AppendText(prefix .. text .. "\n")
    end
    frame.ChatLogBox:GotoTextEnd()
end

local function updateHeader(frame)
    local state = frame._state or {}
    local title, subtitle = "Bomb Panel", "Interact with the visible modules."
    if frame._role == "manual" then
        title = "Holo Manual"
        subtitle = "Swipe through pages to locate the matching solution tree."
    elseif frame._role == "solo" then
        title = "Solo Test Rig"
        subtitle = "Switch between the live panel and the holo manual."
    end
    frame.TitleLabel:SetText(title)
    frame.TitleLabel:SizeToContents()
    frame.SubtitleLabel:SetText(subtitle)
    updateIdentificationVisuals(frame)
    if IsValid(frame.TimerLabel) then frame.TimerLabel:SetText(formatBombTimer(state.timeRemaining or 0)) end
    frame.StrikeLabel:SetText("Strikes: " .. tostring(state.strikes or 0) .. "/" .. tostring(state.maxStrikes or 3))
end

local function updatePanel(frame)
    ensurePanelLayout(frame)
    applyModuleSlotLayout(frame)
    local state = frame._state or {}


    local thermo = state.modules and state.modules.thermo or nil
    if thermo and IsValid(frame.ThermoStatus) then
        local statusText
        if thermo.solved then
            statusText = "SOLVED"
        elseif not thermo.coolantLocked then
            statusText = "Set coolant flow first."
        else
            statusText = "Coolant locked. Set heat exhaust."
        end
        frame.ThermoStatus:SetText(statusText)
        frame.ThermoStatus:SetTextColor(thermo.solved and THEME.success or THEME.text)

        local serverCoolant = thermo.currentCoolant or 0
        local serverExhaust = thermo.currentExhaust or 0
        local shownCoolant = frame._thermoLocalCoolant ~= nil and frame._thermoLocalCoolant or serverCoolant
        local shownExhaust = frame._thermoLocalExhaust ~= nil and frame._thermoLocalExhaust or serverExhaust

        frame._thermoSyncing = true
        frame.ThermoCoolant:SetValue(shownCoolant)
        frame.ThermoExhaust:SetValue(shownExhaust)
        frame._thermoSyncing = false

        if shownCoolant == serverCoolant then frame._thermoLocalCoolant = nil end
        if shownExhaust == serverExhaust then frame._thermoLocalExhaust = nil end

        frame.ThermoCoolant:SetEnabled(state.active and not thermo.solved and not thermo.coolantLocked)
        frame.ThermoApplyCoolant:SetEnabled(state.active and not thermo.solved and not thermo.coolantLocked)
        frame.ThermoExhaust:SetEnabled(state.active and not thermo.solved and thermo.coolantLocked)
        frame.ThermoApplyExhaust:SetEnabled(state.active and not thermo.solved and thermo.coolantLocked)
    end

    local wires = state.modules and state.modules.wires or nil
    if wires and IsValid(frame.WireStatus) then
        frame.WireStatus:SetText(wires.solved and "SOLVED" or "Cut exactly one wire.")
        frame.WireStatus:SetTextColor(wires.solved and THEME.success or THEME.text)
        for i, btn in ipairs(frame.WireButtons or {}) do
            local wire = wires.wires and wires.wires[i]
            btn:SetVisible(wire ~= nil)
            if wire then
                btn._wireCol = getColor(wire.color)
                btn._txtCol = color_white
                btn._wireText = wire.color .. " wire" .. (wire.cut and " (cut)" or "")
                btn:SetEnabled(state.active and not wire.cut and not wires.solved)
            end
        end
    end

    local keypad = state.modules and state.modules.keypad or nil
    if keypad and IsValid(frame.KeypadStatus) then
        frame.KeypadStatus:SetText(keypad.solved and "SOLVED" or ("Progress: " .. tostring((keypad.progress or 1) - 1) .. "/4"))
        frame.KeypadStatus:SetTextColor(keypad.solved and THEME.success or THEME.text)
        for i, btn in ipairs(frame.KeypadButtons or {}) do
            local sym = keypad.symbols and keypad.symbols[i]
            btn:SetVisible(sym ~= nil)
            if sym then
                btn._symbol = sym
                btn:SetText("")
                btn._displayText = sym
                btn:SetEnabled(state.active and not keypad.solved)
            end
        end
    end

    local spiral = state.modules and state.modules.spiral or nil
    if spiral and IsValid(frame.SpiralStatus) then
        frame.SpiralStatus:SetText(spiral.solved and "SOLVED" or "Match all 8 digits.")
        frame.SpiralStatus:SetTextColor(spiral.solved and THEME.success or THEME.text)
        for i, wrap in ipairs(frame.SpiralDigits or {}) do
            local digit = spiral.current and spiral.current[i]
            if IsValid(wrap) and IsValid(wrap.Num) then
                wrap.Num:SetText(tostring(digit or 0))
                wrap.Num:SetTextColor(spiral.solved and THEME.success or THEME.amber)
                wrap.Up:SetEnabled(state.active and not spiral.solved)
                wrap.Down:SetEnabled(state.active and not spiral.solved)
            end
        end
    end

    local tamper = state.modules and state.modules.tamper or nil
    if tamper and IsValid(frame.TamperStatus) then
        frame.TamperStatus:SetText(tamper.solved and "SOLVED" or "Drag each left wire into a receiver.")
        frame.TamperStatus:SetTextColor(tamper.solved and THEME.success or THEME.text)

        local receiverSources = {}
        for srcIndex, receiver in pairs(tamper.connections or {}) do
            receiverSources[receiver] = srcIndex
        end

        for i, src in ipairs(frame.TamperSources or {}) do
            local col = tamper.leftColors and tamper.leftColors[i] or "Wire"
            src._col = getColor(col)
            src._txtCol = color_white
            src._txt = col
            src:SetEnabled(state.active and not tamper.solved)
            src:SetVisible(true)
        end
        for i, rcv in ipairs(frame.TamperReceivers or {}) do
            local col = tamper.rightColors and tamper.rightColors[i] or "Receiver"
            rcv._col = getColor(col)
            rcv._txtCol = color_white
            rcv._txt = col
            local srcIndex = receiverSources[i]
            rcv._sourceLabel = srcIndex and tamper.leftColors and tamper.leftColors[srcIndex] or nil
        end
    end

    local memory = state.modules and state.modules.memory or nil
    if memory and IsValid(frame.MemoryStatus) then
        local statusText
        if memory.solved then
            statusText = "SOLVED"
        elseif not memory.started then
            statusText = "Press the serial-derived start key to begin."
        else
            statusText = string.format("Round %d/4  |  Step %d/%d", memory.currentRound or 1, memory.inputIndex or 1, memory.currentRound or 1)
        end
        frame.MemoryStatus:SetText(statusText)
        frame.MemoryStatus:SetTextColor(memory.solved and THEME.success or THEME.text)

        if memory.previewNonce and memory.previewNonce ~= frame._memoryPreviewNonce then
            frame._memoryPreviewNonce = memory.previewNonce
            frame._memoryPreview = {
                seq = table.Copy(memory.previewSequence or {}),
                start = CurTime(),
            }
        elseif memory.solved then
            frame._memoryPreview = nil
        end

        for i, btn in ipairs(frame.MemoryButtons or {}) do
            btn:SetVisible(true)
            btn:SetEnabled(state.active and not memory.solved)
        end
    else
        frame._memoryPreview = nil
    end

    local redblue = state.modules and state.modules.redblue or nil
    if redblue and IsValid(frame.RedBlueStatus) then
        local statusText
        if redblue.solved then
            statusText = "SOLVED"
        else
            statusText = "Must be pressed last."
        end
        frame.RedBlueStatus:SetText(statusText)
        frame.RedBlueStatus:SetTextColor(redblue.solved and THEME.success or THEME.text)
        if IsValid(frame.RedBlueButtons.Red) then
            frame.RedBlueButtons.Red:SetVisible(true)
            frame.RedBlueButtons.Red:SetEnabled(state.active and not redblue.solved)
        end
        if IsValid(frame.RedBlueButtons.Blue) then
            frame.RedBlueButtons.Blue:SetVisible(true)
            frame.RedBlueButtons.Blue:SetEnabled(state.active and not redblue.solved)
        end
    end

    local mines = state.modules and state.modules.mines or nil
    if mines and IsValid(frame.MinesStatus) then
        frame.MinesStatus:SetText(mines.solved and "SOLVED" or "Find the payload tile using the serial rules.")
        frame.MinesStatus:SetTextColor(mines.solved and THEME.success or THEME.text)
        for _, btn in ipairs(frame.MinesButtons or {}) do
            btn:SetVisible(true)
            btn:SetEnabled(state.active and not mines.solved)
        end
    end

    local twin = state.modules and state.modules.twin or nil
    if twin and IsValid(frame.TwinStatus) then
        local cutCount = twin.progress or 1
        local remaining = math.max(0, 6 - (cutCount - 1))
        local statusText = twin.solved and "SOLVED" or ("Manual-guided sequence required. Remaining cuts: " .. tostring(remaining))
        frame.TwinStatus:SetText(statusText)
        frame.TwinStatus:SetTextColor(twin.solved and THEME.success or Color(255, 216, 216))
        for i, btn in ipairs(frame.TwinButtons or {}) do
            local colorName = twin.displayOrder and twin.displayOrder[i] or "Wire"
            btn._wireColor = colorName
            btn._cut = twin.cut and twin.cut[i] or false
            btn:SetVisible(true)
            btn:SetEnabled(state.active and not twin.solved and not btn._cut)
        end
    end

    local override = state.modules and state.modules.override or nil
    if override and IsValid(frame.OverrideStatus) then
        frame.OverrideStatus:SetText(override.solved and "SOLVED" or "Match the three-switch combo, then press CHECK.")
        frame.OverrideStatus:SetTextColor(override.solved and THEME.success or THEME.text)
        for i, btn in ipairs(frame.OverrideSwitches or {}) do
            btn._state = override.switches and override.switches[i] or 0
            btn:SetVisible(true)
            btn:SetEnabled(state.active and not override.solved)
        end
        if IsValid(frame.OverrideCheck) then
            frame.OverrideCheck:SetVisible(true)
            frame.OverrideCheck:SetEnabled(state.active and not override.solved)
        end
    end


    local reactor = state.modules and state.modules.reactor or nil
    if reactor and IsValid(frame.ReactorStatus) then
        if reactor.solved then
            frame.ReactorStatus:SetText(string.format("Reactor dismantled. Cleared faults: %d/20", tonumber(reactor.cleared or 20)))
        elseif reactor.unlocked then
            frame.ReactorStatus:SetText(string.format("Clear reactor faults. Progress: %d/20", tonumber(reactor.cleared or 0)))
        else
            frame.ReactorStatus:SetText("Enter the 4-letter reactor code to remove the face plate.")
        end
        frame.ReactorStatus:SetTextColor((reactor.danger and not reactor.solved) and Color(255, 110, 110) or (reactor.solved and THEME.success or THEME.text))
        if IsValid(frame.ReactorEntry) then
            frame.ReactorEntry:SetEnabled(state.active and not reactor.solved and not reactor.unlocked)
            if reactor.unlocked and frame.ReactorEntry:GetValue() ~= "" then
                frame.ReactorEntry:SetText("")
            end
        end
        if IsValid(frame.ReactorSubmit) then
            frame.ReactorSubmit:SetVisible(not reactor.unlocked)
            frame.ReactorSubmit:SetEnabled(state.active and not reactor.solved and not reactor.unlocked)
        end
        for yy = 1, 3 do
            for xx = 1, 3 do
                local btn = frame.ReactorGridPanels and frame.ReactorGridPanels[yy] and frame.ReactorGridPanels[yy][xx]
                if IsValid(btn) then
                    btn:SetVisible(reactor.unlocked == true)
                    btn:SetEnabled(state.active and not reactor.solved and reactor.unlocked == true and reactor.grid and reactor.grid[yy] and reactor.grid[yy][xx] == true)
                end
            end
        end
        if IsValid(frame.ReactorSection) then frame.ReactorSection:InvalidateLayout() end
    end

local drill = state.modules and state.modules.drill or nil
if drill and IsValid(frame.DrillStatus) then
    if drill.solved then
        frame.DrillStatus:SetText("Tectonic drill disabled.")
    elseif drill.unlocked then
        frame.DrillStatus:SetText("Cut the correct three wires. Wrong cuts are fatal.")
    else
        frame.DrillStatus:SetText("Enter the 6-digit drill override to expose the cutting panel.")
    end
    frame.DrillStatus:SetTextColor(drill.solved and THEME.success or Color(255, 210, 210))
    if IsValid(frame.DrillEntry) then
        frame.DrillEntry:SetEnabled(state.active and not drill.solved and not drill.unlocked)
        if drill.unlocked and frame.DrillEntry:GetValue() ~= "" then frame.DrillEntry:SetText("") end
    end
    if IsValid(frame.DrillSubmit) then
        frame.DrillSubmit:SetVisible(not drill.unlocked)
        frame.DrillSubmit:SetEnabled(state.active and not drill.solved and not drill.unlocked)
    end
    for _, btn in ipairs(frame.DrillWireButtons or {}) do
        if IsValid(btn) then
            local cut = drill.cut and drill.cut[btn._wireColor] or false
            btn._cut = cut
            btn:SetVisible(drill.unlocked == true)
            btn:SetEnabled(state.active and not drill.solved and drill.unlocked == true and not cut)
        end
    end
    if IsValid(frame.DrillSection) then frame.DrillSection:InvalidateLayout() end
end

    local calibration = state.modules and state.modules.calibration or nil
    if calibration and IsValid(frame.CalibrationStatus) then
        local phaseText = "Press the correct INIT button to begin."
        if calibration.solved then
            phaseText = "SOLVED"
        elseif calibration.phase == "grace" then
            phaseText = "Stand by. First light in 2 seconds."
        elseif calibration.phase == "running" then
            phaseText = string.format("Press on %s. Progress: %d/7", tostring(calibration.targetColor or "target"), tonumber(calibration.hits or 0))
        end
        frame.CalibrationStatus:SetText(phaseText)
        frame.CalibrationStatus:SetTextColor(calibration.solved and THEME.success or THEME.text)
        if IsValid(frame.CalibrationPress) then
            frame.CalibrationPress:SetVisible(true)
            frame.CalibrationPress:SetEnabled(state.active and not calibration.solved and calibration.phase == "running")
        end
        for i, btn in ipairs(frame.CalibrationStarts or {}) do
            if IsValid(btn) then
                btn:SetVisible(true)
                btn:SetEnabled(state.active and not calibration.solved and calibration.phase == "idle")
            end
        end
        for _, pnl in ipairs(frame.CalibrationLights or {}) do
            if IsValid(pnl) then pnl:SetVisible(true) end
        end
    end

    local interrupt = state.modules and state.modules.interrupt or nil
    if interrupt and IsValid(frame.InterruptStatus) then
        local round = interrupt.rounds and interrupt.rounds[interrupt.currentRound or 1] or nil
        local statusText = "Press START to begin."
        if interrupt.solved then
            statusText = "SOLVED"
        elseif interrupt.phase == "running" and round then
            statusText = string.format("Round %d/4 - %d / %d clicks", tonumber(interrupt.currentRound or 1), tonumber(interrupt.clickCount or 0), tonumber(round.target or 0))
            frame.InterruptMain._displayText = tostring(math.max(0, (round.target or 0) - (interrupt.clickCount or 0)))
        end
        frame.InterruptStatus:SetText(statusText)
        frame.InterruptStatus:SetTextColor(interrupt.solved and THEME.success or THEME.text)
        if IsValid(frame.InterruptTimer) then
            local remain = 0
            if interrupt.phase == "running" then
                remain = math.max(0, (interrupt.deadline or 0) - CurTime())
            end
            frame.InterruptTimer:SetText(interrupt.phase == "running" and string.format("%.1fs", remain) or "-")
        end
        if IsValid(frame.InterruptMain) then
            frame.InterruptMain._displayText = interrupt.phase == "running" and (frame.InterruptMain._displayText or "CLICK") or "CLICK"
            frame.InterruptMain:SetVisible(true)
            frame.InterruptMain:SetEnabled(state.active and not interrupt.solved and interrupt.phase == "running")
        end
        if IsValid(frame.InterruptStart) then
            frame.InterruptStart:SetVisible(true)
            frame.InterruptStart:SetEnabled(state.active and not interrupt.solved and interrupt.phase == "idle")
        end
    end

    local electric = state.modules and state.modules.electric or nil
    if electric and IsValid(frame.ElectricStatus) then
        frame.ElectricStatus:SetText(electric.solved and "SOLVED" or "Connect yellow to the correct output wire.")
        frame.ElectricStatus:SetTextColor(electric.solved and THEME.success or THEME.text)
        if IsValid(frame.ElectricSource) then frame.ElectricSource:SetVisible(true) end
        for _, name in ipairs({"Red", "Blue", "Green"}) do
            local btn = frame.ElectricButtons and frame.ElectricButtons[name]
            if IsValid(btn) then
                btn:SetVisible(true)
                btn:SetEnabled(state.active and not electric.solved)
            end
        end
    end
    updateIdentificationVisuals(frame)
end

local function refreshManualDatapadTab(frame)
    if not IsValid(frame) or not IsValid(frame._datapadTab) then return end
    local seismic = (frame._state and frame._state.seismicControl) or {active = false}
    local seal = (frame._state and frame._state.radioactiveSeal) or {active = false}
    local pkb = (frame._state and frame._state.pkbControl) or {active = false}
    local show = (seismic.active == true) or (seal.active == true) or (pkb.active == true)
    frame._datapadTab:SetVisible(show)
    if IsValid(frame._datapadPage) then
        frame._datapadPage:SetVisible(show and frame._manualView == "datapad")
    end
    if not show and frame._manualView == "datapad" and frame._setManualView then
        frame._setManualView("manual")
    end
end

local function updateManual(frame)
    ensureManualLayout(frame)
    local signature = getManualStateSignature(frame._state or {})
    if frame._manualSignature ~= signature or not frame._manualPages then
        frame._manualSignature = signature
        frame._manualPages = buildManualPages(frame._state or {})
        frame._pageIndex = math.Clamp(frame._pageIndex or 1, 1, #frame._manualPages)
        frame:_refreshManual()
    end
    refreshManualDatapadTab(frame)
end



local function applyState(ent, role, state, isOpen)
    if not IsValid(ent) then return end
    if not isOpen and hiddenFrames[ent] then return end
    updateTensionTrack(ent, state)

    local frame = activeFrames[ent]
    if not IsValid(frame) then frame = makeFrame(ent) end

    local prevState = frame._state or {}
    local nextState = state or {}
    for _, key in ipairs({"manual", "moduleStatus", "modules", "activeSlots", "chatLog", "radioactiveSeal", "seismicControl", "pkbControl"}) do
        if nextState[key] == nil and prevState[key] ~= nil then
            nextState[key] = prevState[key]
        end
    end
    if (role == "manual" or role == "solo") and nextState.manual == nil and prevState.manual ~= nil then
        nextState.manual = prevState.manual
    end
    if (role == "manual" or role == "solo") and nextState.moduleStatus == nil and prevState.moduleStatus ~= nil then
        nextState.moduleStatus = prevState.moduleStatus
    end
    if nextState.powerOutage == nil and prevState.powerOutage ~= nil then
        nextState.powerOutage = prevState.powerOutage
    end

    if KTNE_ClientAudio and KTNE_ClientAudio.ProcessStateTransition then
        KTNE_ClientAudio.ProcessStateTransition(frame, prevState, nextState, isOpen)
    end

    frame._role = role
    frame._state = nextState
    updateHeader(frame)
    updateChat(frame)

    
if role == "manual" then
    updateManual(frame)
else
    updatePanel(frame)
end


    if not (state and state.active) then
        hiddenFrames[ent] = nil
        closeFrameForBomb(ent, false)
    end
end

net.Receive("ktne_open_ui_mp", function()
    local ent = net.ReadEntity()
    local role = net.ReadString()
    local state = net.ReadTable() or {}
    if role == "__debug_picker" then
        openDebugRolePicker(ent, state)
        return
    end
    hiddenFrames[ent] = nil
    updateTensionTrack(ent, state)
    applyState(ent, role, state, true)
end)

net.Receive("ktne_sync_state_mp", function()
    local ent = net.ReadEntity()
    local role = net.ReadString()
    local state = net.ReadTable() or {}
    applyState(ent, role, state, false)
end)

net.Receive("ktne_close_ui_mp", function()
    local ent = net.ReadEntity()
    hiddenFrames[ent] = nil
    closeFrameForBomb(ent, false)
end)

function ENT:Draw()
    self:DrawModel()
    if self:GetNWBool("KTNE_Inevitable", false) then return end
    local mins, maxs = self:GetRenderBounds()
    local pos = self:LocalToWorld(Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, maxs.z + 18))
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
    local dist = LocalPlayer():GetPos():Distance(self:GetPos())
    if dist > 300 then return end

    cam.Start3D2D(pos, ang, 0.12)
        draw.RoundedBox(8, -180, -64, 360, 128, Color(6, 20, 30, 220))
        draw.SimpleText("DETPACK DEVICE", "KTNE_Title", 0, -46, THEME.title, TEXT_ALIGN_CENTER)
        local line1 = self:GetGameActive() and ("Time: " .. self:GetTimeRemaining() .. "s") or "Use to join"
        local line2 = "Make: UNIDENTIFIED  |  Serial: ????"
        if self:GetPanelPlySID() ~= "" then
            line2 = "Players: " .. (((self:GetPanelPlySID() ~= "") and 1 or 0) + ((self:GetManualPlySID() ~= "") and 1 or 0)) .. "/2"
        end
        draw.SimpleText(line1, "KTNE_Body", 0, -10, THEME.amber, TEXT_ALIGN_CENTER)
        draw.SimpleText(line2, "KTNE_Body", 0, 18, Color(132, 224, 255), TEXT_ALIGN_CENTER)
        draw.SimpleText("Holo-panel styling active. Four live modules installed.", "KTNE_Small", 0, 44, THEME.text, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end



