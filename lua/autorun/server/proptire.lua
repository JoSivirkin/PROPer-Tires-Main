PropTire = PropTire or {}
local PropTire = PropTire
if not PropTire.SURFACES then include("autorun/proptire_sh.lua") end

PropTire.Tires = PropTire.Tires or {}
local Tires = PropTire.Tires

local U = 0.0254
local function Gravity()
	return physenv.GetGravity():Length() * 0.0254
end
PropTire.Gravity = Gravity
local MARGIN = 3
local V0 = 40
local V_SLOW = 10
local V_FAST = 20
local RELAX = 0.5
local ALPHA_MAX = 1.55

PropTire.SOUNDS = { impactSoft = "Rubber_Tire.ImpactSoft", impactHard = "Rubber_Tire.ImpactHard" }
local SND_SETS, DUST_SETS, MARK_SETS = PropTire.SND_SETS, PropTire.DUST_SETS, PropTire.MARK_SETS
local IMPACT_MIN = 50
local IMPACT_HARD = 250

local function ServerSound(path)
	path = PropTire.CleanSoundPath(path)
	if path ~= "" and not file.Exists("sound/" .. path, "GAME") then return "" end
	return path
end
local SKID_MIN = 60
local SKID_FULL = 300

local AMBIENT = 20
local TEMP_MAX = 250
local HEAT_K = 0.8
local ROLL_K = 0.02
local COOL_0 = 0.03
local COOL_V = 0.003
local COOL_SURF = { dirt = 2, sand = 2, grass = 2, snow = 3, water = 4 }
local HEAT_DROP = 0.8
local HEAT_SPAN = 20
PropTire.HEAT_LIMIT = { race = 110, sport = 95, dirt = 80 }
PropTire.AMBIENT = AMBIENT

PropTire.TREADS = {
	race  = { hard = 1.15, dirt = 0.5,  sand = 0.4,  grass = 0.45, snow = 0.25, other = 0.7 },
	sport = { hard = 1.0,  dirt = 0.7,  sand = 0.55, grass = 0.6,  snow = 0.35, other = 0.75 },
	dirt  = { hard = 0.85, dirt = 0.95, sand = 0.85, grass = 0.85, snow = 0.5,  other = 0.75 },
}
local TREADS = PropTire.TREADS
local SURF_GROUP = {
	[MAT_CONCRETE] = "hard", [MAT_TILE] = "hard", [MAT_DIRT] = "dirt", [MAT_SAND] = "sand",
	[MAT_GRASS] = "grass", [MAT_FOLIAGE] = "grass", [MAT_SNOW] = "snow",
}
local SOFT_GROUP = { dirt = true, sand = true, grass = true, snow = true }

PropTire.MAT_NAMES = {
	[MAT_CONCRETE] = { "бетон/асфальт", "concrete/asphalt" }, [MAT_TILE] = { "плитка", "tile" },
	[MAT_DIRT] = { "грунт", "dirt" }, [MAT_METAL] = { "металл", "metal" }, [MAT_SAND] = { "песок", "sand" },
	[MAT_GRASS] = { "трава", "grass" }, [MAT_FOLIAGE] = { "листва", "foliage" }, [MAT_SNOW] = { "снег", "snow" },
	[MAT_WOOD] = { "дерево", "wood" },
}

function PropTire.MatName(ply, matType)
	local n = PropTire.MAT_NAMES[matType]
	if not n then return PropTire.L(ply, "другое", "other") end
	return PropTire.RU(ply) and n[1] or n[2]
end

function PropTire.Friction(tread, matType, pres)
	local t = TREADS[tread] or TREADS.sport
	local g = SURF_GROUP[matType] or "other"
	local mu = t[g]
	if SOFT_GROUP[g] and pres then mu = mu * (1 + 0.15 * (55 - pres) / 50) end
	return mu
end

local BX, CX, EX = 12, 1.65, 0.6
local BY, CY, EY = 10, 1.3, 0.4

local AXES = { Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1) }
local AXIS_NAMES = { "X", "Y", "Z" }
PropTire.AXIS_NAMES = AXIS_NAMES
local DOWN = Vector(0, 0, -1)

local abs, max, min, sqrt, tan, sin, cos, atan, pi = math.abs, math.max, math.min, math.sqrt, math.tan, math.sin, math.cos, math.atan, math.pi

local function CopyConstraints(ent)
	local list = constraint.GetTable(ent)
	for _, c in ipairs(list) do
		local ctrl = c.MyCrtl and Entity(c.MyCrtl)
		if ctrl and IsValid(ctrl) then
			c.WireCtrl = ctrl
			if IsValid(c.Constraint) then c.Constraint:DontDeleteOnRemove(ctrl) end
		end
		if IsValid(c.Constraint) and c.Constraint:GetClass() == "phys_spring" then
			c.SpringLen = tonumber(c.Constraint:GetKeyValues().length)
		end
	end
	constraint.RemoveAll(ent)
	return list
end

local function RestoreConstraints(ent, list)
	if not list[1] or not IsValid(ent) or not IsValid(ent:GetPhysicsObject()) then return end
	for _, c in ipairs(list) do
		local byIndex, ok = {}, true
		for _, e in pairs(c.Entity or {}) do
			if not e.World then
				if IsValid(e.Entity) then byIndex[e.Index] = e.Entity else ok = false end
			end
		end
		if ok then
			c.MyCrtl = nil
			local done, const, rope = pcall(duplicator.CreateConstraintFromTable, c, byIndex)
			if not done then
				print("[PROPer Tires] constraint '" .. tostring(c.Type) .. "' was not restored: " .. tostring(const))
			elseif IsValid(const) and IsValid(c.WireCtrl) and c.WireCtrl.SetConstraint then
				local ctrl = c.WireCtrl
				const.MyCrtl = ctrl:EntIndex()
				ctrl.MyId = ctrl:EntIndex()
				ctrl:SetConstraint(const, IsValid(rope) and rope or nil)
				ctrl:DeleteOnRemove(const)
				if IsValid(rope) then ctrl:DeleteOnRemove(rope) end
			end
			local len = c.SpringLen
			if done and IsValid(const) and len and len > 0 and const:GetClass() == "phys_spring" then
				local ctrl = IsValid(c.WireCtrl) and c.WireCtrl or nil
				local wired = ctrl and ctrl.Inputs and ctrl.Inputs.Length and ctrl.Inputs.Length.Src
				if ctrl and ctrl.SetLength and not wired then
					ctrl:SetLength(len)
				elseif not wired then
					const:Fire("SetSpringLength", len, 0)
					if IsValid(rope) then rope:Fire("SetLength", len, 0) end
				end
			end
		end
	end
end

local function RestoreLater(ent, list, tries)
	tries = tries or 0
	timer.Simple(engine.TickInterval(), function()
		if tries < 60 then
			for _, c in ipairs(list) do
				if IsValid(c.Constraint) then
					RestoreLater(ent, list, tries + 1)
					return
				end
			end
		end
		RestoreConstraints(ent, list)
		PropTire.UpdateLoads()
	end)
end

local function AddOwn(own, e)
	if own[e] then return end
	own[e] = true
	for _, c in ipairs(e:GetChildren()) do
		if IsValid(c) then AddOwn(own, c) end
	end
end

local function Carries(c)
	if not IsValid(c) or c.Type == "NoCollide" then return false end
	if c.Type == "AdvBallsocket" then
		local o = c.onlyrotation
		if o == true or (tonumber(o) or 0) ~= 0 then return false end
	end
	return true
end

local function WeightGroup(start)
	local seen, list, i = { [start] = true }, { start }, 1
	while list[i] do
		local e = list[i]
		i = i + 1
		local p = e:GetPhysicsObject()
		if not IsValid(p) or p:IsMoveable() then
			for _, c in pairs(e.Constraints or {}) do
				if Carries(c) then
					for k = 1, 6 do
						local o = c["Ent" .. k]
						if IsValid(o) and not seen[o] then
							seen[o] = true
							list[#list + 1] = o
						end
					end
				end
			end
		end
	end
	return list
end

function PropTire.UpdateLoads()
	local seenOwn, seenLoad = {}, {}
	for ent in pairs(Tires) do
		if not IsValid(ent) or not ent.PropTire then
			Tires[ent] = nil
		else
			if not seenOwn[ent] then
				local own = {}
				for _, e in pairs(constraint.GetAllConstrainedEntities(ent)) do
					if IsValid(e) then AddOwn(own, e) end
				end
				own[ent] = true
				local filter = function(e) return not own[e] and not IsValid(e:GetParent()) end
				for e in pairs(own) do
					if Tires[e] and e.PropTire then
						seenOwn[e] = true
						e.PropTire.own = own
						e.PropTire.filter = filter
					end
				end
			end
			if not seenLoad[ent] then
				local mass, tires = 0, {}
				for _, e in ipairs(WeightGroup(ent)) do
					local p = e:GetPhysicsObject()
					if IsValid(p) and p:IsMoveable() and p:IsGravityEnabled() then mass = mass + p:GetMass() end
					if Tires[e] and e.PropTire then tires[#tires + 1] = e end
				end
				local g = Gravity()
				for _, t in ipairs(tires) do
					seenLoad[t] = true
					t.PropTire.mass = mass
					t.PropTire.ntires = #tires
					if mass > 0 then t.PropTire.load = mass * g / #tires end
				end
			end
		end
	end
end

timer.Create("PropTireLoads", 1, 0, PropTire.UpdateLoads)

local SOUNDS = PropTire.SOUNDS
local OWN_SOUNDS = {}
OWN_SOUNDS[SOUNDS.impactSoft] = true
OWN_SOUNDS[SOUNDS.impactHard] = true

hook.Add("EntityEmitSound", "PropTire", function(data)
	local ent = data.Entity
	if IsValid(ent) and Tires[ent] and not (OWN_SOUNDS[data.OriginalSoundName] or OWN_SOUNDS[data.SoundName]) then
		return false
	end
end)

local function ImpactFilter(ent)
	local owner = ent:GetNW2Entity("PropTireOwner")
	local rf
	for _, p in ipairs(player.GetHumans()) do
		if p ~= owner and p:GetInfoNum("proptire_others", 1) == 0 then
			if not rf then
				rf = RecipientFilter()
				rf:AddPAS(ent:GetPos())
			end
			rf:RemovePlayer(p)
		end
	end
	return rf
end

local function OnCollide(ent, data)
	local T = ent.PropTire
	if not T or not T.sounds or T.own and T.own[data.HitEntity] then return end
	local imp = abs((data.OurOldVelocity - data.TheirOldVelocity):Dot(data.HitNormal))
	if imp < IMPACT_MIN or CurTime() < (T.nextImpact or 0) then return end
	T.nextImpact = CurTime() + 0.15
	local snd = imp >= IMPACT_HARD and SOUNDS.impactHard or SOUNDS.impactSoft
	local rf = ImpactFilter(ent)
	if rf then
		ent:EmitSound(snd, 75, 100, 1, CHAN_AUTO, 0, 0, rf)
	else
		ent:EmitSound(snd)
	end
end

function PropTire.MSData(ent)
	local mods = ent.EntityMods
	if not mods then return nil end
	local d = mods.MakeSphericalCollisions
	if istable(d) and d.enabled then return d end
	return mods.sphere
end

local function ClearMS(ent)
	duplicator.ClearEntityModifier(ent, "MakeSphericalCollisions")
	duplicator.ClearEntityModifier(ent, "sphere")
end

function PropTire.RemoveMS(ent)
	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return false end
	local list = CopyConstraints(ent)
	local mass, mat, ismove, sleep = phys:GetMass(), phys:GetMaterial(), phys:IsMoveable(), phys:IsAsleep()
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:SetCollisionBounds(ent:GetModelBounds())
	phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(mass)
		phys:SetMaterial(mat)
		phys:EnableMotion(ismove)
		if not sleep then phys:Wake() end
	end
	ClearMS(ent)
	RestoreLater(ent, list)
	return true
end

function PropTire.SkidLevel(T)
	return math.Clamp(((T.skid or 0) - SKID_MIN) / (SKID_FULL - SKID_MIN), 0, 1)
end

function PropTire.Temp(T)
	return T.heat and T.temp or AMBIENT
end

local function HeatLimit(T)
	return PropTire.HEAT_LIMIT[T.tread] or PropTire.HEAT_LIMIT.sport
end

local function HeatGrip(T)
	if not T.heat then return 1 end
	return 1 - HEAT_DROP * math.Clamp((T.temp - HeatLimit(T)) / HEAT_SPAN, 0, 1)
end

local SLOW_CANDIDATES = { "rubber", "rubbertire", "default", "plastic", "metal", "wood", "concrete", "dirt",
	"gravel", "mud", "sand", "snow", "glass", "paper", "carpet", "slipperymetal", "slipperyslime", "ice", "gmod_ice" }
local slowMats, rubberF

local function SlowMaterial(factor)
	if factor >= 0.99 then return "rubber" end
	if not slowMats then
		slowMats = {}
		for _, name in ipairs(SLOW_CANDIDATES) do
			local i = util.GetSurfaceIndex(name)
			local d = i and i >= 0 and util.GetSurfaceData(i)
			if d and d.friction then
				slowMats[#slowMats + 1] = { name = name, f = d.friction }
				if name == "rubber" then rubberF = d.friction end
			end
		end
	end
	local target = (rubberF or 0.8) * factor
	local best, bd = "rubber", math.huge
	for _, m in ipairs(slowMats) do
		local d = abs(m.f - target)
		if d < bd then best, bd = m.name, d end
	end
	return best
end

local function UpdateHeat(T, dt)
	if not T.heat then return end
	local t = T.temp or AMBIENT
	t = t + (HEAT_K * (T.hP or 0) + ROLL_K * abs(T.wheelV or 0) * U) * T.heatrate * dt
	t = t - (t - AMBIENT) * (COOL_0 + COOL_V * (T.hV or 0)) * (T.hCool or 1) * T.coolrate * dt
	T.temp = math.Clamp(t, AMBIENT, TEMP_MAX)
end

local function UpdateSkid(ent, T)
	if T.heat then
		local h = math.Round(math.Clamp(0.6 + 0.4 * (T.temp - HeatLimit(T)) / HEAT_SPAN, 0, 1), 1)
		if h ~= (T.heatQ or 0) then
			T.heatQ = h
			ent:SetNW2Float("PropTireHeat", h)
		end
	end
	if not T.sounds and not T.marks and not T.dust then return end
	local vol = math.Round(PropTire.SkidLevel(T), 1)
	if vol ~= (T.skidQ or 0) then
		T.skidQ = vol
		ent:SetNW2Float("PropTireSkid", vol)
	end
end

function PropTire.Force(T)
	if T.ground and T.fdir then return T.fdir * (T.fx or 0) + T.ldir * (T.fy or 0) end
	return Vector(0, 0, 0)
end

function PropTire.Info(ent)
	local T = IsValid(ent) and ent.PropTire
	if not T then return nil end
	return {
		onGround = T.ground or false,
		load = T.load or 0,
		slip = T.slip or 0,
		slipAngle = T.alpha or 0,
		skid = PropTire.SkidLevel(T),
		force = PropTire.Force(T),
		grip = T.mu or 0,
		surface = T.surf or "",
		wheelSpeed = T.wheelV or 0,
		groundSpeed = T.groundV or 0,
		temp = PropTire.Temp(T),
		radius = T.radius,
		width = T.wid,
		pressure = T.pres,
		tread = T.tread,
		gripSetting = math.Round((T.grip or 3) * 100),
	}
end

timer.Create("PropTireSkid", 0.1, 0, function()
	for ent in pairs(Tires) do
		if IsValid(ent) and ent.PropTire then UpdateSkid(ent, ent.PropTire) end
	end
end)

local cvMaxRadius = CreateConVar("proptire_max_radius", "200", FCVAR_ARCHIVE, "PROPer Tires: maximum wheel radius", 1, 200)
local cvMaxWidth = CreateConVar("proptire_max_width", "15", FCVAR_ARCHIVE, "PROPer Tires: maximum contact patch width", 2, 15)
local cvMaxGrip = CreateConVar("proptire_max_grip", "500", FCVAR_ARCHIVE, "PROPer Tires: maximum Grip %", 50, 500)

local function Requested(data)
	local size = data.maxs - data.mins
	local s = { size.x, size.y, size.z }
	local axis = data.axis
	if axis == 0 then
		axis = 1
		for i = 2, 3 do if s[i] < s[axis] then axis = i end end
	end
	local mr = 0
	for i = 1, 3 do if i ~= axis then mr = max(mr, s[i] / 2) end end
	local radius = math.Clamp(data.radius > 0 and data.radius or mr, 1, 200)
	local wid = math.Clamp(data.width > 0 and data.width or s[axis], 2, 15)
	return axis, s, radius, wid
end

local function Limited(radius, wid, grip)
	return min(radius, cvMaxRadius:GetFloat()), min(wid, cvMaxWidth:GetFloat()), min(grip, cvMaxGrip:GetFloat())
end

local function LimitNotice(ply, key, ru, en, value)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	ply.PropTireNotice = ply.PropTireNotice or {}
	if CurTime() < (ply.PropTireNotice[key] or 0) then return end
	ply.PropTireNotice[key] = CurTime() + 2
	ply:ChatPrint(string.format(PropTire.L(ply, ru, en), value))
end

function PropTire.Apply(ent, data, ply)
	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return end

	local old = ent.PropTireData
	if PropTire.MSData(ent) then
		data.mins, data.maxs = ent:GetModelBounds()
		ClearMS(ent)
	elseif not data.mins and not old and PropTire.CubeBox(ent) then
		data.mins, data.maxs = ent:GetModelBounds()
	end
	data.mins = data.mins or old and old.mins or ent:OBBMins()
	data.maxs = data.maxs or old and old.maxs or ent:OBBMaxs()
	data.mat = data.mat or old and old.mat or phys:GetMaterial()
	data.radius = math.Clamp(tonumber(data.radius) or 0, 0, 200)
	data.width = math.Clamp(tonumber(data.width) or 0, 0, 15)
	data.pres = math.Clamp(tonumber(data.pres) or 20, 5, 55)
	data.axis = math.Clamp(math.floor(tonumber(data.axis) or 0), 0, 3)
	if not TREADS[data.tread] then data.tread = "sport" end
	data.sounds = data.sounds ~= false
	data.marks = data.marks ~= false
	data.dust = data.dust ~= false
	local oldset = data.fxset or data.soundset
	data.fxset, data.soundset = nil, nil
	data.sndset = data.sndset or oldset
	data.dustset = data.dustset or (oldset == "simfphys" and "simfphys" or "glide")
	if not SND_SETS[data.sndset] then data.sndset = "hl2" end
	if not DUST_SETS[data.dustset] then data.dustset = "glide" end
	if not MARK_SETS[data.markset] then data.markset = "glide" end
	data.dustsize = math.Clamp(math.Round(tonumber(data.dustsize) or 10), 1, 10)
	data.grip = math.Clamp(math.Round(tonumber(data.grip) or 300), 50, 500)
	data.heat = data.heat == true
	data.heatrate = math.Clamp(math.Round(tonumber(data.heatrate) or 100), 10, 200)
	data.coolrate = math.Clamp(math.Round(tonumber(data.coolrate) or 100), 10, 200)
	local custom = {}
	if istable(data.custom) then
		for _, g in ipairs(PropTire.SURFACES) do
			local c = data.custom[g.id]
			if istable(c) then
				custom[g.id] = { roll = ServerSound(c.roll), skid = ServerSound(c.skid),
					vol = math.Clamp(tonumber(c.vol) or 1, 0, 1) }
			end
		end
	end
	data.custom = custom

	local axis, s, reqR, reqW = Requested(data)
	local radius, wid, grip = Limited(reqR, reqW, data.grip)
	if radius < reqR then
		LimitNotice(ply, "radius", "Радиус ограничен сервером: %.1f", "Radius limited by the server: %.1f", radius)
	end
	if wid < reqW then
		LimitNotice(ply, "width", "Ширина пятна ограничена сервером: %.1f", "Patch width limited by the server: %.1f", wid)
	end
	if grip < data.grip then
		LimitNotice(ply, "grip", "Сцепление ограничено сервером: %d%%", "Grip limited by the server: %d%%", grip)
	end
	local rs = radius

	local list = CopyConstraints(ent)
	local mass, ismove, sleep = phys:GetMass(), phys:IsMoveable(), phys:IsAsleep()
	ent:PhysicsInitSphere(rs, "rubber")
	ent:SetCollisionBounds(Vector(-rs, -rs, -rs), Vector(rs, rs, rs))
	phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(mass)
		phys:SetMaterial("rubber")
		phys:EnableMotion(ismove)
		if not sleep then phys:Wake() end
	end

	local T = ent.PropTire
	ent.PropTire = {
		axis = axis, alocal = AXES[axis], radius = radius, rs = rs, wid = wid,
		pres = data.pres, tread = data.tread,
		sounds = data.sounds, marks = data.marks, dust = data.dust,
		sndset = data.sndset, dustset = data.dustset, markset = data.markset, dustsize = data.dustsize,
		load = T and T.load or mass * Gravity(), own = T and T.own,
		filter = T and T.filter or function(e) return e ~= ent and not IsValid(e:GetParent()) end,
		grip = grip / 100,
		slow = true,
		heat = data.heat, heatrate = data.heatrate / 100, coolrate = data.coolrate / 100,
		temp = T and T.temp or AMBIENT,
	}
	ent.PropTireData = data
	Tires[ent] = true

	local fx = (data.sounds and 1 or 0) + (data.marks and 2 or 0) + (data.heat and 4 or 0) + (data.dust and 8 or 0)
		+ SND_SETS[data.sndset] * 16 + DUST_SETS[data.dustset] * 128 + MARK_SETS[data.markset] * 512
		+ data.dustsize * 1024
	ent:SetNW2Int("PropTireFX", fx)
	if IsValid(ply) then ent:SetNW2Entity("PropTireOwner", ply) end
	for _, g in ipairs(PropTire.SURFACES) do
		local c = data.sndset == "custom" and data.custom[g.id]
		local raw = c and (c.roll .. "|" .. c.skid .. "|" .. math.Round(c.vol, 2)) or ""
		if ent:GetNW2String(g.nw, "") ~= raw then ent:SetNW2String(g.nw, raw) end
	end
	ent:SetNW2Float("PropTireHW", s[axis] / 2)
	ent:SetNW2Float("PropTireW", wid)
	ent:SetNW2Int("PropTireAxis", axis)
	ent:SetNW2Float("PropTireSkid", 0)
	ent:SetNW2Float("PropTireHeat", 0)
	ent.PropTire.heatQ = 0
	if not ent.PropTireCB then ent.PropTireCB = ent:AddCallback("PhysicsCollide", OnCollide) end
	duplicator.StoreEntityModifier(ent, "PropTire", data)

	RestoreLater(ent, list)
end

function PropTire.Restore(ent)
	local data = ent.PropTireData
	local phys = ent:GetPhysicsObject()
	if not data or not IsValid(phys) then return end

	local list = CopyConstraints(ent)
	local mass, ismove, sleep = phys:GetMass(), phys:IsMoveable(), phys:IsAsleep()
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:SetCollisionBounds(data.mins, data.maxs)
	phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(mass)
		phys:SetMaterial(data.mat)
		phys:EnableMotion(ismove)
		if not sleep then phys:Wake() end
	end

	ent:SetNW2Float("PropTireSkid", 0)
	ent:SetNW2Float("PropTireHeat", 0)
	ent:SetNW2Int("PropTireAxis", 0)
	ent:SetNW2Int("PropTireFX", 0)
	if ent.PropTireCB then
		ent:RemoveCallback("PhysicsCollide", ent.PropTireCB)
		ent.PropTireCB = nil
	end
	Tires[ent] = nil
	ent.PropTire = nil
	ent.PropTireData = nil
	duplicator.ClearEntityModifier(ent, "PropTire")

	RestoreLater(ent, list)
end

local reapplyQueue, reapplyQueued = {}, {}

local function ReapplyNext()
	local ent = table.remove(reapplyQueue, 1)
	while ent and not (IsValid(ent) and ent.PropTireData) do
		reapplyQueued[ent] = nil
		ent = table.remove(reapplyQueue, 1)
	end
	if ent then
		reapplyQueued[ent] = nil
		PropTire.Apply(ent, ent.PropTireData, ent:GetNW2Entity("PropTireOwner"))
	end
	if not reapplyQueue[1] then timer.Remove("PropTireReapply") end
end

local function ReapplyLimits()
	for ent in pairs(Tires) do
		local T = IsValid(ent) and ent.PropTire
		local data = T and ent.PropTireData
		if data then
			local _, _, reqR, reqW = Requested(data)
			local radius, wid, grip = Limited(reqR, reqW, data.grip)
			if abs(radius - T.radius) > 0.01 then
				if not reapplyQueued[ent] then
					reapplyQueued[ent] = true
					reapplyQueue[#reapplyQueue + 1] = ent
				end
			else
				T.wid, T.grip = wid, grip / 100
				ent:SetNW2Float("PropTireW", wid)
			end
		end
	end
	if reapplyQueue[1] and not timer.Exists("PropTireReapply") then
		timer.Create("PropTireReapply", 0.1, 0, ReapplyNext)
	end
end

local LIMITS = { radius = cvMaxRadius, width = cvMaxWidth, grip = cvMaxGrip }
for _, cv in pairs(LIMITS) do
	cvars.AddChangeCallback(cv:GetName(), function()
		timer.Create("PropTireLimits", 0.2, 1, ReapplyLimits)
	end, "PropTire")
end

concommand.Add("proptire_limit", function(ply, cmd, args)
	local valid = IsValid(ply)
	local function reply(s)
		if valid then ply:PrintMessage(HUD_PRINTCONSOLE, s) else print(s) end
	end
	local L = function(ru, en) return PropTire.L(ply, ru, en) end
	if not args[1] then
		reply(string.format(L("PROPer Tires, ограничения сервера: радиус %g, ширина пятна %g, сцепление %g%%",
			"PROPer Tires server limits: radius %g, patch width %g, grip %g%%"),
			cvMaxRadius:GetFloat(), cvMaxWidth:GetFloat(), cvMaxGrip:GetFloat()))
		return
	end
	if valid and not ply:IsSuperAdmin() then
		reply(L("PROPer Tires: менять ограничения может только суперадмин", "PROPer Tires: only superadmins can change the limits"))
		return
	end
	local cv = LIMITS[string.lower(args[1])]
	local v = tonumber(args[2])
	if not cv or not v then
		reply(L("Использование: proptire_limit <radius|width|grip> <значение>", "Usage: proptire_limit <radius|width|grip> <value>"))
		return
	end
	v = math.Clamp(v, cv:GetMin() or v, cv:GetMax() or v)
	RunConsoleCommand(cv:GetName(), tostring(v))
	reply(string.format(L("PROPer Tires: %s = %g", "PROPer Tires: %s = %g"), cv:GetName(), v))
end)

duplicator.RegisterEntityModifier("PropTire", function(ply, ent, data)
	PropTire.Apply(ent, data, ply)
end)

local function MagicFormula(B, C, E, x)
	local bx = B * x
	return sin(C * atan(bx - E * (bx - atan(bx))))
end

local function TireModel(load, wid, pres, mu, s, alpha)
	local D = mu * load * (0.9 + 0.2 * (wid - 2) / 13)
	local stiff = 0.6 + 0.8 * (pres - 5) / 50
	local fx = D * MagicFormula(BX * stiff, CX, EX, s)
	local fy = D * MagicFormula(BY * stiff, CY, EY, alpha)
	local f = sqrt(fx * fx + fy * fy)
	if f > D then fx, fy = fx * D / f, fy * D / f end
	return fx, fy
end

local STATES = {
	frozen = { "заморожена или спит", "frozen or asleep" },
	flat = { "лежит плашмя (ось вертикальна)", "lying flat (axis vertical)" },
	inside = { "трасса начинается внутри", "trace starts inside" },
	air = { "в воздухе", "in the air" },
	rest = { "касается, стоит (резина)", "touching, standing (rubber)" },
	model = { "касается, модель шины", "touching, tire model" },
}
local HITS = { world = { "мир", "world" }, none = { "ничего", "nothing" } }

local TR = { mask = MASK_SOLID }

local function Simulate(ent, T, dt)
	T.skid = 0
	T.ground, T.surf, T.slip, T.alpha, T.fx, T.fy, T.mu, T.groundV = false, "", 0, 0, 0, 0, 0, 0
	T.wheelV, T.hP, T.hV, T.hCool = 0, 0, 0, 1
	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) or not phys:IsMoveable() or phys:IsAsleep() or T.load <= 0 then
		T.dState = "frozen"
		return
	end
	T.wheelV = math.rad(phys:GetAngleVelocity():Dot(T.alocal)) * T.rs
	T.hV = phys:GetVelocity():Length() * U

	local pos = phys:GetPos()
	local a = phys:LocalToWorldVector(T.alocal)
	local d = DOWN - a * DOWN:Dot(a)
	if d:LengthSqr() < 0.09 then T.dState = "flat" return end
	d:Normalize()
	TR.start = pos
	TR.endpos = pos + d * (T.rs * 2 + MARGIN)
	TR.filter = T.filter
	local tr = util.TraceLine(TR)
	local ge = tr.Entity
	T.dHit = IsValid(ge) and ge:GetClass() or (tr.Hit and "world" or "none")
	if tr.StartSolid then T.dState = "inside" return end
	if not tr.Hit then T.dState = "air" return end
	local n = tr.HitNormal
	if (pos - tr.HitPos):Dot(n) > T.rs + MARGIN then T.dState = "air" return end

	local f = a:Cross(n)
	if f:LengthSqr() < 0.01 then return end
	f:Normalize()
	local l = n:Cross(f)
	local p = pos - n * T.rs

	local v = phys:GetVelocity()
	if IsValid(ge) then
		local gp = ge:GetPhysicsObject()
		if IsValid(gp) then v = v - gp:GetVelocityAtPoint(p) end
	end
	local forvel, latvel = v:Dot(f), v:Dot(l)
	local linvel = T.wheelV
	local moving = max(abs(forvel), abs(linvel), abs(latvel))
	T.dFor, T.dLin, T.dLat = forvel, linvel, latvel
	T.dS, T.dFx, T.dJx, T.dJmax = 0, 0, 0, 0

	local mat = PropTire.TraceMat(tr)
	local group = PropTire.SurfaceGroup(mat).id
	local mu = PropTire.Friction(T.tread, mat, T.pres) * (T.grip or 3) * HeatGrip(T)
	T.ground, T.surf, T.groundV, T.mu = true, group, forvel, mu
	T.fdir, T.ldir = f, l
	T.hCool = COOL_SURF[group] or 1

	if T.slow and moving >= V_FAST then
		T.slow = false
		T.slowMat = nil
		phys:SetMaterial("gmod_ice")
	elseif not T.slow and moving < V_SLOW then
		T.slow = true
	end
	if T.slow then
		local m = T.heat and SlowMaterial(HeatGrip(T)) or "rubber"
		if m ~= T.slowMat then
			T.slowMat = m
			phys:SetMaterial(m)
		end
		T.dState = "rest"
		return
	end
	T.dState = "model"

	local s = math.Clamp((linvel - forvel) / max(abs(forvel), abs(linvel), V0), -0.99, 0.99)
	local alpha = min(atan(abs(latvel) / max(abs(forvel), V0)), ALPHA_MAX)
	local fx, fy = TireModel(T.load, T.wid, T.pres, mu, s, alpha)

	local k = dt / U
	local m = phys:GetMass()
	local I = phys:GetInertia():Dot(T.alocal) / U ^ 2
	local mx = I > 0 and 1 / (1 / m + T.rs ^ 2 / I) or m
	local jxMax = RELAX * abs(linvel - forvel) * mx
	local jx = math.Clamp(fx * k, -jxMax, jxMax)
	local jy = min(abs(fy) * k, RELAX * abs(latvel) * m)
	T.dS, T.dFx, T.dJx, T.dJmax = s, fx, jx, jxMax
	T.skid = sqrt((linvel - forvel) ^ 2 + latvel ^ 2)
	local jl = latvel > 0 and -jy or jy
	T.slip = s
	T.alpha = math.deg(latvel > 0 and alpha or -alpha)
	T.fx, T.fy = jx / k, jl / k
	T.hP = (abs(T.fx) * abs(linvel - forvel) + abs(T.fy) * abs(latvel)) * U / max(T.load, 1)

	if jx ~= 0 then phys:ApplyForceOffset(f * jx, p) end
	if jy > 0 then phys:ApplyForceCenter(l * jl) end
end

timer.Create("PropTireDebug", 1, 0, function()
	for ent in pairs(Tires) do
		local T = IsValid(ent) and ent.PropTire
		local ply = T and T.dbgPly
		if IsValid(ply) then
			local i = PropTire.RU(ply) and 1 or 2
			local st = STATES[T.dState]
			local hit = HITS[T.dHit] and HITS[T.dHit][i] or T.dHit or "-"
			local state = st and st[i] or "-"
			if T.dState == "inside" then state = state .. " " .. hit end
			ply:ChatPrint(string.format(PropTire.L(ply,
				"[%d] %s, трасса: %s | ход %.0f, колесо %.0f, бок %.0f юн/с, s %.2f, сила %.0f Н, импульс %.0f / %.0f",
				"[%d] %s, trace: %s | travel %.0f, wheel %.0f, side %.0f u/s, s %.2f, force %.0f N, impulse %.0f / %.0f"),
				ent:EntIndex(), state, hit, T.dFor or 0, T.dLin or 0, T.dLat or 0,
				T.dS or 0, T.dFx or 0, T.dJx or 0, T.dJmax or 0)
				.. (T.heat and string.format(", %.0f°C x%.2f", T.temp, HeatGrip(T)) or ""))
		end
	end
end)

util.AddNetworkString("PropTireDbg")

local DBG_RANGE = 1500
local DBG_MAX = 32
local SURF_INDEX = {}
for i, g in ipairs(PropTire.SURFACES) do SURF_INDEX[g.id] = i end

timer.Create("PropTireDbgNet", 0.1, 0, function()
	for _, ply in ipairs(player.GetHumans()) do
		if ply:GetInfoNum("proptire_debug", 0) == 1 then
			local eye = ply:EyePos()
			local list = {}
			for ent in pairs(Tires) do
				if IsValid(ent) and ent.PropTire and ent:GetNW2Entity("PropTireOwner") == ply
					and ent:GetPos():DistToSqr(eye) < DBG_RANGE * DBG_RANGE then
					list[#list + 1] = ent
					if #list >= DBG_MAX then break end
				end
			end
			if list[1] then
				net.Start("PropTireDbg", true)
				net.WriteUInt(#list, 6)
				for _, ent in ipairs(list) do
					local T = ent.PropTire
					net.WriteUInt(ent:EntIndex(), 16)
					net.WriteUInt(math.Clamp(math.Round((T.mu or 0) * 100), 0, 4095), 12)
					net.WriteUInt(T.ground and SURF_INDEX[T.surf] or 0, 4)
					net.WriteUInt(math.Clamp(math.Round(PropTire.Temp(T)), 0, 1023), 10)
				end
				net.Send(ply)
			end
		end
	end
end)

hook.Add("Tick", "PropTire", function()
	local dt = engine.TickInterval()
	for ent in pairs(Tires) do
		if IsValid(ent) and ent.PropTire then
			Simulate(ent, ent.PropTire, dt)
			UpdateHeat(ent.PropTire, dt)
		else
			Tires[ent] = nil
		end
	end
end)
