if not PropTire or not PropTire.SURFACES then include("autorun/proptire_sh.lua") end

local AXES = { Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1) }
local WHITE = Color(255, 255, 255)
local SHADOW = Color(0, 0, 0, 170)
local ORANGE = Color(255, 170, 60)
local SEG = 48
local ARROWS = 4
local SPIN = 1.5
local TWO_PI = math.pi * 2

local mat = CreateMaterial("proptire_preview", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
	["$nocull"] = 1,
	["$ignorez"] = 1,
})

local function Usable(ent)
	if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() then return false end
	local class = ent:GetClass()
	if string.find(class, "prop_vehicle_") or class == "prop_ragdoll" then return false end
	return ent:GetMoveType() == MOVETYPE_VPHYSICS
end

local function Shape(ent)
	if ent:GetNW2Int("PropTireFX", 0) ~= 0 then
		local axis = ent:GetNW2Int("PropTireAxis", 0)
		if axis < 1 or axis > 3 then return nil end
		return axis, ent:OBBMaxs().x, ent:GetNW2Float("PropTireW", 4)
	end
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	if PropTire.CubeBox(ent) then mins, maxs = ent:GetModelBounds() end
	local size = maxs - mins
	local s = { size.x, size.y, size.z }
	local axis = math.Clamp(math.floor(GetConVarNumber("proptire_axis")), 0, 3)
	if axis == 0 then
		axis = 1
		for i = 2, 3 do if s[i] < s[axis] then axis = i end end
	end
	local mr = 0
	for i = 1, 3 do if i ~= axis then mr = math.max(mr, s[i] / 2) end end
	local r = GetConVarNumber("proptire_radius")
	local w = GetConVarNumber("proptire_width")
	return axis, math.Clamp(r > 0 and r or mr, 1, 200), math.Clamp(w > 0 and w or s[axis], 2, 15)
end

local function Lines(list, width, col)
	for _, ln in ipairs(list) do render.DrawBeam(ln[1], ln[2], width * (ln[3] or 1), 0, 1, col or ln[4]) end
end

hook.Add("PostDrawTranslucentRenderables", "PropTirePreview", function(depth, sky, sky3d)
	if depth or sky or sky3d then return end
	if GetConVarString("gmod_toolmode") ~= "proptire" then return end
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return end
	local ent = ply:GetEyeTrace().Entity
	if not Usable(ent) then return end
	local axis, r, w = Shape(ent)
	if not axis then return end

	local c = ent:GetPos()
	local a = Vector(AXES[axis])
	a:Rotate(ent:GetAngles())
	local u = a:Cross(math.abs(a.z) < 0.9 and vector_up or Vector(1, 0, 0))
	u:Normalize()
	local v = a:Cross(u)
	local lw = math.Clamp(r * 0.025, 0.25, 1.5)

	local list = {}
	local prev = c + u * r
	for i = 1, SEG do
		local t = i / SEG * TWO_PI
		local p = c + (u * math.cos(t) + v * math.sin(t)) * r
		list[#list + 1] = { prev, p, 1, WHITE }
		prev = p
	end
	list[#list + 1] = { c - a * (w / 2), c + a * (w / 2), 1, WHITE }
	local phase = RealTime() * SPIN
	local len = r * 0.22
	for k = 0, ARROWS - 1 do
		local t = phase + k / ARROWS * TWO_PI
		local radial = u * math.cos(t) + v * math.sin(t)
		local tang = v * math.cos(t) - u * math.sin(t)
		local tip = c + radial * r
		list[#list + 1] = { tip, tip - tang * len + radial * len * 0.55, 1.6, ORANGE }
		list[#list + 1] = { tip, tip - tang * len - radial * len * 0.55, 1.6, ORANGE }
	end

	render.SetMaterial(mat)
	Lines(list, lw * 2.4, SHADOW)
	Lines(list, lw)
end)
