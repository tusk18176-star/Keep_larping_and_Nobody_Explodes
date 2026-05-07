if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "KTNE Remote Trigger"
SWEP.Author = "OpenAI"
SWEP.Instructions = "Right click a bomb to link. Left click to detonate."
SWEP.Category = "Minigames"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.HoldType = "pistol"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local VALID_BOMBS = {
    sent_ktne_bomb = true,
    sent_ktne_abberant_mp = true,
    sent_ktne_seismic_mp = true,
    sent_ktne_pkb_mp = true,
    sent_ktne_bomb_solo = true,
    sent_ktne_detpack_solo = true,
    sent_ktne_emp_solo = true,
    sent_ktne_incendiary_solo = true,
}

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:IsValidBomb(ent)
    return IsValid(ent) and VALID_BOMBS[ent:GetClass()] == true
end

function SWEP:GetLinkedBomb()
    local linked = self.LinkedBomb
    if self:IsValidBomb(linked) then
        return linked
    end

    local nw = self:GetNWEntity("KTNE_LinkedBomb")
    if self:IsValidBomb(nw) then
        self.LinkedBomb = nw
        return nw
    end

    return nil
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.5)
    if CLIENT then return end

    local owner = self:GetOwner()
    local bomb = self:GetLinkedBomb()
    if not self:IsValidBomb(bomb) then
        if IsValid(owner) then
            owner:ChatPrint("Remote trigger is not linked to a bomb.")
        end
        self.LinkedBomb = nil
        self:SetNWEntity("KTNE_LinkedBomb", NULL)
        return
    end

    if bomb.ExplodeBomb then
        bomb:ExplodeBomb("Remote trigger activated.")
    end

    if IsValid(owner) then
        owner:ChatPrint("Triggered linked bomb.")
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.25)
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local trace = owner:GetEyeTrace()
    local ent = trace.Entity
    if not self:IsValidBomb(ent) then
        owner:ChatPrint("No KTNE bomb targeted.")
        return
    end

    self.LinkedBomb = ent
    self:SetNWEntity("KTNE_LinkedBomb", ent)
    owner:ChatPrint("Linked remote trigger to " .. (ent.PrintName or ent:GetClass()) .. ".")
end
