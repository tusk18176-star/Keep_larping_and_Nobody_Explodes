ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "EMP Bomb (Single Player)"
ENT.Author = ""
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
