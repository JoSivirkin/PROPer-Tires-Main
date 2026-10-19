E2Lib.RegisterExtension("proptire", true, "Reads PROPer Tires tire data")

local function Tire(e)
	return IsValid(e) and e.PropTire or nil
end

__e2setcost(2)

e2function number entity:propTireIs()
	return Tire(this) and 1 or 0
end

e2function number entity:propTireOnGround()
	local T = Tire(this)
	return T and T.ground and 1 or 0
end

e2function number entity:propTireLoad()
	local T = Tire(this)
	return T and (T.curLoad or T.load) or 0
end

e2function number entity:propTireSlip()
	local T = Tire(this)
	return T and T.slip or 0
end

e2function number entity:propTireSlipAngle()
	local T = Tire(this)
	return T and T.alpha or 0
end

e2function number entity:propTireSkid()
	local T = Tire(this)
	return T and PropTire.SkidLevel(T) or 0
end

e2function vector entity:propTireForce()
	local T = Tire(this)
	return T and PropTire.Force(T) or Vector(0, 0, 0)
end

e2function number entity:propTireGrip()
	local T = Tire(this)
	return T and T.mu or 0
end

e2function string entity:propTireSurface()
	local T = Tire(this)
	return T and T.surf or ""
end

e2function number entity:propTireWheelSpeed()
	local T = Tire(this)
	return T and T.wheelV or 0
end

e2function number entity:propTireGroundSpeed()
	local T = Tire(this)
	return T and T.groundV or 0
end

e2function number entity:propTireTemp()
	local T = Tire(this)
	return T and PropTire.Temp(T) or 0
end

e2function number entity:propTireRadius()
	local T = Tire(this)
	return T and T.radius or 0
end

e2function number entity:propTireWidth()
	local T = Tire(this)
	return T and T.wid or 0
end

e2function number entity:propTirePressure()
	local T = Tire(this)
	return T and T.pres or 0
end

e2function string entity:propTireTread()
	local T = Tire(this)
	return T and T.tread or ""
end
