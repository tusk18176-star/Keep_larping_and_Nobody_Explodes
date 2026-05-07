ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "PKB Bomb (Two Player)"
ENT.Author = "OpenAI"
ENT.Category = "Minigames"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "GameActive")
    self:NetworkVar("Int", 0, "TimeRemaining")
    self:NetworkVar("Int", 1, "Strikes")
    self:NetworkVar("String", 0, "PanelPlySID")
    self:NetworkVar("String", 1, "ManualPlySID")
end

if properties then
local KTNE_DEBUG_CLASSES = {
    sent_ktne_bomb = true,
    sent_ktne_abberant_mp = true,
    sent_ktne_seismic_mp = true,
    sent_ktne_pkb_mp = true,
    sent_ktne_bomb_solo = true,
    sent_ktne_detpack_solo = true,
    sent_ktne_emp_solo = true,
    sent_ktne_incendiary_solo = true,
}

properties.Add("ktne_debug_one_player", {
    MenuLabel = "Toggle Training Mode",
    Order = 900,

    Filter = function(self, ent, ply)
        if not IsValid(ent) or not KTNE_DEBUG_CLASSES[ent:GetClass()] then return false end
        if not IsValid(ply) or (not game.SinglePlayer() and not ply:IsAdmin()) then return false end
        return ent.GetGameActive == nil or ent:GetGameActive() ~= true
    end,

    Action = function(self, ent)
        self:MsgStart()
            net.WriteEntity(ent)
        self:MsgEnd()
    end,

    Receive = function(self, length, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) or not KTNE_DEBUG_CLASSES[ent:GetClass()] then return end
        if not IsValid(ply) or (not game.SinglePlayer() and not ply:IsAdmin()) then return end
        if ent.GetGameActive and ent:GetGameActive() then return end

        ent.KTNEDebugOnePlayer = not ent.KTNEDebugOnePlayer
        ent:SetNWBool("KTNE_DebugOnePlayer", ent.KTNEDebugOnePlayer == true)
        ent.DebugOnePlayerActive = false
        ent.DebugTestRole = nil
        ent.DebugTestSID = nil
    end,
})
end
