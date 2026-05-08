if not properties then return end
if properties.List and properties.List["ktne_debug_one_player"] then return end

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
