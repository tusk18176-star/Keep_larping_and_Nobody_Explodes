if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("ktne_set_bomb_timer")

    local KTNE_TIMER_CLASSES = {
        sent_ktne_bomb = 300,
        sent_ktne_abberant_mp = 240,
        sent_ktne_seismic_mp = 210,
        sent_ktne_pkb_mp = 270,
        sent_ktne_bomb_solo = 300,
        sent_ktne_detpack_solo = 150,
        sent_ktne_emp_solo = 165,
        sent_ktne_incendiary_solo = 165,
    }

    net.Receive("ktne_set_bomb_timer", function(_, ply)
        local ent = net.ReadEntity()
        local seconds = math.Clamp(math.floor(net.ReadUInt(9) or 0), 60, 480)
        if not IsValid(ent) then return end
        local defaultTime = KTNE_TIMER_CLASSES[ent:GetClass()]
        if not defaultTime then return end
        if not IsValid(ply) then return end
        if ent.GetGameActive and ent:GetGameActive() then return end
        if tostring(ent:GetNWString("KTNE_SpawnerSID", "")) ~= tostring(ply:SteamID64() or "") then return end

        ent.KTNESelectedStartTime = seconds
        ent:SetNWInt("KTNE_SelectedStartTime", seconds)
    end)

    return
end

if not properties then return end
if properties.List and properties.List["ktne_set_timer"] then return end

local KTNE_TIMER_CLASSES = {
    sent_ktne_bomb = 300,
    sent_ktne_abberant_mp = 240,
    sent_ktne_seismic_mp = 210,
    sent_ktne_pkb_mp = 270,
    sent_ktne_bomb_solo = 300,
    sent_ktne_detpack_solo = 150,
    sent_ktne_emp_solo = 165,
    sent_ktne_incendiary_solo = 165,
}

local function formatTimeLabel(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%02d", mins, secs)
end

properties.Add("ktne_set_timer", {
    MenuLabel = "Set Bomb Timer",
    Order = 901,

    Filter = function(self, ent, ply)
        if not IsValid(ent) then return false end
        local defaultTime = KTNE_TIMER_CLASSES[ent:GetClass()]
        if not defaultTime then return false end
        if not IsValid(ply) then return false end
        if ent.GetGameActive and ent:GetGameActive() then return false end
        return tostring(ent:GetNWString("KTNE_SpawnerSID", "")) == tostring(ply:SteamID64() or "")
    end,

    Action = function(self, ent)
        if not IsValid(ent) then return end
        local defaultTime = KTNE_TIMER_CLASSES[ent:GetClass()] or 300

        local frame = vgui.Create("DFrame")
        frame:SetTitle("Set Bomb Timer")
        frame:SetSize(360, 140)
        frame:Center()
        frame:MakePopup()
        frame:SetDeleteOnClose(true)

        local slider = vgui.Create("DNumSlider", frame)
        slider:Dock(TOP)
        slider:DockMargin(12, 12, 12, 0)
        slider:SetText("Timer")
        slider:SetMin(60)
        slider:SetMax(480)
        slider:SetDecimals(0)
        slider:SetValue(defaultTime)
        slider.Label:SetText(string.format("Timer (%s default)", formatTimeLabel(defaultTime)))

        local valueLabel = vgui.Create("DLabel", frame)
        valueLabel:Dock(TOP)
        valueLabel:DockMargin(12, 6, 12, 0)
        valueLabel:SetTall(20)
        valueLabel:SetText("Selected: " .. formatTimeLabel(defaultTime))

        slider.OnValueChanged = function(_, val)
            valueLabel:SetText("Selected: " .. formatTimeLabel(math.Clamp(math.floor(tonumber(val) or defaultTime), 60, 480)))
        end

        local apply = vgui.Create("DButton", frame)
        apply:Dock(BOTTOM)
        apply:DockMargin(12, 8, 12, 12)
        apply:SetTall(28)
        apply:SetText("Apply")
        apply.DoClick = function()
            if not IsValid(ent) then frame:Close() return end
            local seconds = math.Clamp(math.floor(tonumber(slider:GetValue()) or defaultTime), 60, 480)
            net.Start("ktne_set_bomb_timer")
                net.WriteEntity(ent)
                net.WriteUInt(seconds, 9)
            net.SendToServer()
            frame:Close()
        end
    end,
})
