AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "PROPer Tires controller"
ENT.Spawnable = false
ENT.DisableDuplicator = true
ENT.DoNotDuplicate = true

if CLIENT then return end

function ENT:Initialize()
	self:SetNoDraw(true)
	self:SetNotSolid(true)
	self:SetMoveType(MOVETYPE_NONE)
	self:StartMotionController()
end

function ENT:UpdateTransmitState()
	return TRANSMIT_NEVER
end

function ENT:PhysicsSimulate(phys, dt)
	local a = PropTire and PropTire.SpringStep and PropTire.SpringStep(phys, dt)
	if not a then return SIM_NOTHING end
	return vector_origin, a, SIM_GLOBAL_ACCELERATION
end
