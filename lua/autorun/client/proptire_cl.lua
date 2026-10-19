if not PropTire or not PropTire.SURFACES then include("autorun/proptire_sh.lua") end

local RATE = 0.05
local SCAN = 1
local MAX_DIST = 4000
local REST = 0.5
local SILENT_STOP = 1
local SKID_FADE = 0.15
local CONTACT_HOLD = 0.2

local ROLL_FROM, ROLL_FULL = 150, 900
local SLOW_FROM, SLOW_FADE, SLOW_OFF = 20, 300, 700

local MARK_SKID = 0.35
local MARK_ROLL = 30
local DUST_FROM, DUST_FULL = 250, 900
local DUST_HARD = 0.6
local SLIP_FX = 0.25
local PUFF_SKID = 0.15
local HEAT_UP, HEAT_DOWN, HEAT_SMOKE = 1.2, 0.4, 0.6
local PUFFS = 2
local DUST_DROP = 0.9

local HL2 = {
	ROLL = {
		[MAT_DIRT] = "physics/body/body_medium_scrape_rough_loop1.wav",
		[MAT_SAND] = "physics/body/body_medium_scrape_rough_loop1.wav",
		[MAT_GRASS] = "physics/body/body_medium_scrape_rough_loop1.wav",
		[MAT_SNOW] = "physics/body/body_medium_scrape_smooth_loop1.wav",
		[MAT_FOLIAGE] = "physics/cardboard/cardboard_box_scrape_rough_loop1.wav",
		[MAT_METAL] = "physics/metal/metal_box_scrape_smooth_loop1.wav",
		[MAT_GRATE] = "physics/metal/metal_box_scrape_smooth_loop1.wav",
	},
	SIDE_SLIP = {
		[MAT_DEFAULT] = "vehicles/v8/skid_normalfriction.wav",
		[MAT_CONCRETE] = "vehicles/v8/skid_highfriction.wav",
		[MAT_TILE] = "vehicles/v8/skid_highfriction.wav",
		[MAT_DIRT] = "vehicles/v8/skid_lowfriction.wav",
		[MAT_GRASS] = "vehicles/v8/skid_lowfriction.wav",
		[MAT_SAND] = "physics/body/body_medium_scrape_rough_loop1.wav",
		[MAT_SNOW] = "physics/body/body_medium_scrape_smooth_loop1.wav",
		[MAT_FOLIAGE] = "physics/cardboard/cardboard_box_scrape_rough_loop1.wav",
		[MAT_PLASTIC] = "physics/plastic/plastic_barrel_scrape_smooth_loop1.wav",
		[MAT_METAL] = "physics/metal/metal_box_scrape_smooth_loop1.wav",
		[MAT_GRATE] = "physics/metal/metal_box_scrape_smooth_loop1.wav",
		[MAT_VENT] = "physics/metal/metal_box_scrape_smooth_loop1.wav",
		[MAT_GLASS] = "physics/metal/metal_grenade_scrape_rough_loop1.wav",
	},
	ROLL_VOLUME = { [MAT_METAL] = 0.6, [MAT_GRATE] = 0.6, [MAT_DIRT] = 0.4, [MAT_SAND] = 0.5, [MAT_GRASS] = 0.4, [MAT_SNOW] = 0.3, [MAT_FOLIAGE] = 0.4 },
}

local SOFT = { [MAT_DIRT] = true, [MAT_SNOW] = true, [MAT_SAND] = true, [MAT_FOLIAGE] = true, [MAT_GRASS] = true, [MAT_SLOSH] = true }

local SIMF = "simulated_vehicles/sfx/"
local SIMF_HARD = { concrete = true, rock = true, tile = true }
local SIMF_DUST = { grass = true, dirt = true, sand = true }

local SMOKE_COLOR = Vector(0.6, 0.6, 0.6)
local function GetTireSmokeColor() return SMOKE_COLOR end

local band, Clamp, min, max, abs = bit.band, math.Clamp, math.min, math.max, math.abs
local HasLua, HasContent, Installed = PropTire.HasLua, PropTire.HasContent, PropTire.Installed
local tires = {}
local dusting = {}
local TR = { mask = MASK_SOLID_BRUSHONLY }
local DOWN = Vector()

local function Ramp(x, a, b)
	return Clamp((x - a) / (b - a), 0, 1)
end

local SET_HL2, SET_GLIDE, SET_SIMF, SET_CUSTOM, SET_ACE, SET_LVS = 0, 1, 2, 3, 5, 6
local SET_GLIDE_FILES = 10
local ACE = "acf_extra/vehiclefx/tires/"
local function SndSet(fx)
	local set = math.floor(fx / 16) % 8
	if set == SET_GLIDE then
		if HasLua("glide") then return SET_GLIDE end
		return HasContent("glide") and SET_GLIDE_FILES or SET_HL2
	end
	if set == SET_SIMF and not Installed("simfphys") then return SET_HL2 end
	if set == SET_ACE and not HasContent("ace") then return SET_HL2 end
	if set == SET_LVS and not HasContent("lvs") then return SET_HL2 end
	return set
end

local LVS = "lvs/vehicles/generic/"
local LVS_HEAVY_R = 20
local LVS_SND = {
	asphalt = { roll = "wheel_roll",      skid = "wheel_skid",      heavy = true, vol = 0.8 },
	dirt    = { roll = "wheel_roll_dirt", skid = "wheel_skid_dirt", heavy = true, vol = 0.9 },
	sand    = { roll = "wheel_roll_dirt", skid = "wheel_skid_dirt", heavy = true, vol = 0.9, pitch = 0.9 },
	grass   = { roll = "wheel_roll_dirt", skid = "wheel_skid_dirt", heavy = true, vol = 0.8, pitch = 1.05 },
	snow    = { roll = "wheel_roll_dirt", skid = "wheel_skid_dirt", heavy = true, vol = 0.7, pitch = 0.9 },
	wood    = { roll = "wheel_roll",      skid = "wheel_skid",      heavy = true, vol = 0.8, pitch = 0.9 },
	metal   = { roll = "wheel_roll",      skid = "wheel_skid",      heavy = true, vol = 0.7, pitch = 1.1 },
	water   = { roll = "wheel_roll_wet",  skid = "wheel_skid_wet",  vol = 0.8 },
	other   = { roll = "wheel_roll",      skid = "wheel_skid",      heavy = true, vol = 0.7 },
}

local ACE_SND = {
	asphalt = { roll = "road",      skid = "skidroadlight",    heavy = "skidroadheavymajor", vol = 0.8 },
	dirt    = { roll = "dirtroll",  skid = "dirtskid",         vol = 0.9 },
	sand    = { roll = "dirtroll",  skid = "dirtskid",         vol = 0.9, pitch = 0.9 },
	grass   = { roll = "grassroll", skid = "grassskid",        vol = 0.8 },
	snow    = { roll = "snowroll",  skid = "dirtskid",         vol = 0.7 },
	wood    = { roll = "woodroll",  skid = "concretetireskid", vol = 0.8 },
	metal   = { roll = "road",      skid = "concretetireskid", vol = 0.7, pitch = 1.1 },
	water   = { roll = "grassroll",                            vol = 0.5, pitch = 0.8 },
	other   = { roll = "road",      skid = "concretetireskid", vol = 0.7 },
}
local HEAVY_FROM, HEAVY_FULL = 0.45, 0.8

local GLIDE_WAV = "glide/wheels/"
local GLIDE_SND = {
	asphalt = {                    slow = "roll_road_slow", skid = "side_skid_road_1",   vol = 0.4 },
	dirt    = { roll = "roll_dirt",     slow = "roll_dirt_slow", skid = "side_skid_dirt",     vol = 0.5 },
	sand    = { roll = "roll_sand",     slow = "roll_dirt_slow", skid = "side_skid_dirt",     vol = 0.6 },
	grass   = { roll = "roll_grass",    slow = "roll_dirt_slow", skid = "side_skid_dirt",     vol = 0.5 },
	snow    = { roll = "roll_dirt",     slow = "roll_dirt_slow", skid = "side_skid_dirt",     vol = 0.4 },
	metal   = { roll = "roll_metal",    slow = "roll_road_slow", skid = "side_skid_road_1",   vol = 0.6 },
	wood    = { roll = "roll_wood",     slow = "roll_road_slow", skid = "side_skid_wood",     vol = 0.6 },
	water   = { roll = "roll_road_wet",                          skid = "side_skid_road_wet", vol = 0.5 },
	other   = {                    slow = "roll_road_slow", skid = "side_skid_road_1",   vol = 0.4 },
}

local DUST_GLIDE, DUST_SIMF, DUST_PROPER = 0, 1, 2
local DUST_GLIDE_FILES, DUST_SIMF_FILES = 10, 11
local function DustSet(fx)
	local set = math.floor(fx / 128) % 4
	if set == DUST_GLIDE then
		if HasLua("glide") then return DUST_GLIDE end
		return HasContent("glide") and DUST_GLIDE_FILES or DUST_PROPER
	end
	if set == DUST_SIMF then
		if HasLua("simfphys") then return DUST_SIMF end
		return HasContent("simfphys") and DUST_SIMF_FILES or DUST_PROPER
	end
	return DUST_PROPER
end

local MARKS_GLIDE, MARKS_PROPER = 0, 1
local MARKS_GLIDE_FILES = 10
local function MarkSet(fx)
	local set = math.floor(fx / 512) % 2
	if set == MARKS_GLIDE then
		if Glide and Glide.AddSkidMarkPiece then return MARKS_GLIDE end
		return HasContent("glide") and MARKS_GLIDE_FILES or MARKS_PROPER
	end
	return MARKS_PROPER
end

local function SetSoundsFor(set, g)
	if set == "ace" then
		local p = ACE_SND[g.id] or ACE_SND.other
		return ACE .. p.roll .. ".wav", p.skid and (ACE .. p.skid .. ".wav") or "", p.vol
	elseif set == "glide" then
		local p = GLIDE_SND[g.id] or GLIDE_SND.other
		local roll = p.roll or p.slow
		return roll and (GLIDE_WAV .. roll .. ".wav") or "", p.skid and (GLIDE_WAV .. p.skid .. ".wav") or "", p.vol
	elseif set == "simfphys" then
		local grass = g.id == "grass" or g.id == "snow"
		local soft = g.id == "dirt" or g.id == "sand"
		local kind = grass and "grass" or soft and "dirt" or "concrete"
		return SIMF .. kind .. "_roll.wav", SIMF .. kind .. "_skid.wav", (grass or soft) and 0.9 or 0.8
	elseif set == "lvs" then
		local p = LVS_SND[g.id] or LVS_SND.other
		return LVS .. p.roll .. ".wav", LVS .. p.skid .. ".wav", p.vol
	elseif set == "hl2" then
		local mat = g.mats[1] or MAT_DEFAULT
		return HL2.ROLL[mat] or "", HL2.SIDE_SLIP[mat] or HL2.SIDE_SLIP[MAT_DEFAULT] or "", 0.8
	end
end

function PropTire.SetSoundPaths(set)
	local out = {}
	for _, g in ipairs(PropTire.SURFACES) do
		local roll, skid, vol = SetSoundsFor(set, g)
		if not roll then return nil end
		out[g.id] = { roll = roll, skid = skid, vol = vol }
	end
	return out
end

local MARK_SKID_COLOR = { 18, 18, 18 }
local MARK_ROLL_COLOR = { dirt = { 62, 48, 34 }, sand = { 120, 104, 78 }, grass = { 46, 50, 30 }, snow = { 140, 146, 158 } }

local hasFile = {}
local function Usable(path)
	if not path or path == "" then return nil end
	if hasFile[path] == nil then hasFile[path] = file.Exists("sound/" .. path, "GAME") end
	return hasFile[path] and path or nil
end

local function CustomOf(ent, C, g)
	local raw = ent:GetNW2String(g.nw, "")
	local c = C.custom[g.id]
	if c and c.raw == raw then return c end
	local roll, skid, vol = string.match(raw, "^([^|]*)|([^|]*)|([%d%.]+)$")
	c = { raw = raw, roll = Usable(roll or ""), skid = Usable(skid or ""), vol = tonumber(vol) or 0 }
	C.custom[g.id] = c
	return c
end

local function DustPos(ent, C)
	return ent:GetPos() - Vector(0, 0, C.dustR * DUST_DROP)
end

local pcfLoaded
local function LoadSimfParticles()
	if pcfLoaded then return end
	pcfLoaded = true
	game.AddParticles("particles/vehicle.pcf")
	PrecacheParticleSystem("WheelDust")
end

local function Pick(tbl, s, fallback)
	if not tbl then return nil end
	return tbl[s] or fallback and tbl[MAT_DEFAULT]
end

local function StopSounds(C)
	for _, snd in pairs(C.snd) do snd:Stop() end
	C.snd, C.path, C.vol, C.pit, C.quiet = {}, {}, {}, {}, {}
end

local function StopDust(ent, C)
	if C.dust and C.dust:IsValid() then C.dust:StopEmission() end
	C.dustOn = false
	dusting[ent] = nil
end

local function StopAll(ent, C)
	StopSounds(C)
	StopDust(ent, C)
end

local function Layer(ent, C, key, path, vol, pitch)
	local snd = C.snd[key]
	if snd and C.path[key] ~= path then
		snd:Stop()
		snd = nil
		C.snd[key] = nil
		C.quiet[key] = nil
	end
	if not path then return end
	if vol < 0.01 then
		if snd and snd:IsPlaying() then
			local now = RealTime()
			if not C.quiet[key] then
				C.quiet[key] = now
				snd:ChangeVolume(0, RATE)
				C.vol[key] = 0
			elseif now - C.quiet[key] > SILENT_STOP then
				snd:Stop()
				C.quiet[key] = nil
			end
		end
		return
	end
	C.quiet[key] = nil
	if not snd then
		snd = CreateSound(ent, path)
		snd:SetSoundLevel(80)
		C.snd[key], C.path[key] = snd, path
	end
	if not snd:IsPlaying() then
		snd:PlayEx(vol, pitch)
	else
		if abs(vol - (C.vol[key] or -1)) < 0.02 and abs(pitch - (C.pit[key] or -1)) < 1 then return end
		snd:ChangeVolume(vol, RATE)
		snd:ChangePitch(pitch, RATE)
	end
	C.vol[key], C.pit[key] = vol, pitch
end

local function TableSounds(ent, C, set, s, speed, skid)
	local fast = Ramp(speed, ROLL_FROM, ROLL_FULL)
	local slow = Ramp(speed, SLOW_FROM, SLOW_FADE) * (1 - Ramp(speed, SLOW_FADE, SLOW_OFF))
	local rv = set.ROLL_VOLUME and set.ROLL_VOLUME[s] or 0.4
	Layer(ent, C, "roll", Pick(set.ROLL, s), fast * rv, 80 + 30 * fast)
	Layer(ent, C, "slow", Pick(set.ROLL_SLOW, s, true), slow * 0.6, 90 + 25 * Ramp(speed, 0, 500))
	Layer(ent, C, "skid", Pick(set.SIDE_SLIP, s, true), skid, 90 + 25 * skid)
end

local function GlideFile(name)
	return name and Usable(GLIDE_WAV .. name .. ".wav")
end

local function GlideSounds(ent, C, s, speed, skid)
	local p = GLIDE_SND[PropTire.SurfaceGroup(s).id] or GLIDE_SND.other
	local fast = Ramp(speed, ROLL_FROM, ROLL_FULL)
	local slow = Ramp(speed, SLOW_FROM, SLOW_FADE) * (1 - Ramp(speed, SLOW_FADE, SLOW_OFF))
	Layer(ent, C, "roll", GlideFile(p.roll), fast * p.vol, 80 + 30 * fast)
	Layer(ent, C, "slow", GlideFile(p.slow), slow * 0.6, 90 + 25 * Ramp(speed, 0, 500))
	Layer(ent, C, "skid", GlideFile(p.skid), skid, 90 + 25 * skid)
end

local function SimfSounds(ent, C, name, speed, skid)
	local grass = name == "grass" or name == "snow"
	local soft = name == "dirt" or name == "sand"
	local roll = Ramp(speed, 80, 1300)
	Layer(ent, C, "roll", SIMF .. (grass and "grass_roll.wav" or soft and "dirt_roll.wav" or "concrete_roll.wav"),
		roll * ((grass or soft) and 0.9 or 1), 85 + 45 * Ramp(speed, 0, 1500))
	Layer(ent, C, "slow", nil, 0, 100)
	local skidPath = name ~= "ice" and SIMF .. (grass and "grass_skid.wav" or soft and "dirt_skid.wav" or "concrete_skid.wav")
	Layer(ent, C, "skid", skidPath, skid * ((grass or soft) and 0.9 or 0.6), 90 + 35 * skid + (soft and 15 or 0))
end

local function CustomSounds(ent, C, s, speed, skid)
	local c = CustomOf(ent, C, PropTire.SurfaceGroup(s))
	local roll = Ramp(speed, SLOW_FROM, ROLL_FULL)
	Layer(ent, C, "roll", c.roll, roll * c.vol, 85 + 35 * Ramp(speed, 0, 1200))
	Layer(ent, C, "slow", nil, 0, 100)
	Layer(ent, C, "skid", c.skid, skid * c.vol, 90 + 25 * skid)
end

local function AceSounds(ent, C, s, speed, skid)
	local p = ACE_SND[PropTire.SurfaceGroup(s).id] or ACE_SND.other
	local pitch = p.pitch or 1
	Layer(ent, C, "roll", Usable(ACE .. p.roll .. ".wav"), Ramp(speed, SLOW_FROM, ROLL_FULL) * p.vol,
		(85 + 35 * Ramp(speed, 0, 1200)) * pitch)
	Layer(ent, C, "slow", nil, 0, 100)
	local h = p.heavy and Ramp(skid, HEAVY_FROM, HEAVY_FULL) or 0
	local sp = (90 + 20 * skid) * pitch
	Layer(ent, C, "skid", p.skid and Usable(ACE .. p.skid .. ".wav"), skid * (1 - h) * p.vol, sp)
	Layer(ent, C, "skid2", p.heavy and Usable(ACE .. p.heavy .. ".wav"), skid * h * p.vol, sp)
end

local function LvsFile(name, heavy)
	if heavy then
		local h = Usable(LVS .. "heavy" .. name .. ".wav")
		if h then return h end
	end
	return Usable(LVS .. name .. ".wav")
end

local function LvsSounds(ent, C, s, speed, skid, r)
	local p = LVS_SND[PropTire.SurfaceGroup(s).id] or LVS_SND.other
	local heavy = p.heavy and r >= LVS_HEAVY_R
	local pitch = p.pitch or 1
	Layer(ent, C, "roll", LvsFile(p.roll, heavy), Ramp(speed, SLOW_FROM, ROLL_FULL) * p.vol,
		(85 + 35 * Ramp(speed, 0, 1200)) * pitch)
	Layer(ent, C, "slow", nil, 0, 100)
	Layer(ent, C, "skid", LvsFile(p.skid, heavy), skid * p.vol, (90 + 20 * skid) * pitch)
end

local function Heat(C, on, skid, dt)
	if C.real then
		C.heat = C.real
		return C.heat
	end
	if on then
		C.heat = min((C.heat or 0) + skid * HEAT_UP * dt, 1)
	else
		C.heat = max((C.heat or 0) - HEAT_DOWN * dt, 0)
	end
	return C.heat
end

local function ProperDust(ent, C, contact, tr, s, vel, speed, skid, dt, size, skin)
	local group = PropTire.SurfaceGroup(s).id
	local dir = C.fwd and -C.fwd:GetNormalized() or vector_up
	if contact and SOFT[s] then
		local dust = min(Ramp(speed, DUST_FROM, DUST_FULL) + skid * 0.5, 1)
		if dust > 0.05 then PropTire.DustPuff(group, tr.HitPos, vel, dir, dust, size, skin) end
		if skid > SLIP_FX then PropTire.Clumps(group, tr.HitPos, dir, skid, size, skin) end
	end
	local heat = Heat(C, contact and not SOFT[s] and skid > 0.1, skid, dt)
	if heat > HEAT_SMOKE and contact then
		PropTire.TireSmoke(tr.HitPos, dir, Ramp(heat, HEAT_SMOKE * 0.8, 1), size, skin)
	end
end

local function GlideDust(ent, C, tr, s, vel, speed, skid, base)
	if not ent.GetTireSmokeColor then ent.GetTireSmokeColor = GetTireSmokeColor end
	local dust = SOFT[s] and min(Ramp(speed, DUST_FROM, DUST_FULL) + skid * 0.5, 1) or Ramp(skid, DUST_HARD, 1)
	if dust > 0.05 then
		local eff = EffectData()
		eff:SetOrigin(tr.HitPos)
		eff:SetStart(vel)
		eff:SetSurfaceProp(s)
		eff:SetScale(base * dust)
		eff:SetEntity(ent)
		util.Effect("glide_tire_roll", eff)
	end
	if skid > SLIP_FX and C.fwd then
		local eff = EffectData()
		eff:SetOrigin(tr.HitPos)
		eff:SetSurfaceProp(s)
		eff:SetScale(base * skid)
		eff:SetNormal(-C.fwd:GetNormalized())
		eff:SetEntity(ent)
		util.Effect("glide_tire_slip_forward", eff)
	end
end

local function SimfDust(ent, C, contact, name, tr, s, speed, skid, r, dt, mul, size, own)
	if contact and speed > DUST_FROM and SIMF_DUST[name] then
		C.dustR = r
		if not (C.dust and C.dust:IsValid()) then
			if own then LoadSimfParticles() end
			C.dust = CreateParticleSystem(ent, "WheelDust", PATTACH_CUSTOMORIGIN)
			C.dustOn = C.dust ~= nil
			if C.dust then C.dust:SetControlPoint(0, DustPos(ent, C)) end
		elseif not C.dustOn then
			C.dust:StartEmission()
			C.dustOn = true
		end
		if C.dustOn then dusting[ent] = C end
	elseif C.dustOn then
		StopDust(ent, C)
	end

	local heat = Heat(C, contact and SIMF_HARD[name] and skid > 0.1, skid, dt)
	local dir = C.fwd and -C.fwd:GetNormalized() or vector_up
	if own then
		if heat > HEAT_SMOKE and contact then
			PropTire.TireSmoke(tr.HitPos, dir, Ramp(heat, HEAT_SMOKE * 0.8, 1), size)
		end
		if contact and SOFT[s] and skid > PUFF_SKID then
			PropTire.Clumps(PropTire.SurfaceGroup(s).id, tr.HitPos, dir, skid, size)
		end
		return
	end
	local pos = ent:GetPos()
	if heat > HEAT_SMOKE then
		local eff = EffectData()
		eff:SetOrigin(pos)
		eff:SetNormal(dir)
		eff:SetMagnitude((0.35 + 0.65 * Ramp(heat, HEAT_SMOKE, 1)) * mul)
		eff:SetRadius(r * mul)
		eff:SetStart(SMOKE_COLOR * 255)
		eff:SetEntity(NULL)
		for _ = 1, PUFFS do util.Effect("simfphys_tiresmoke", eff) end
	end
	if contact and skid > PUFF_SKID then
		local eff = EffectData()
		eff:SetOrigin(pos)
		eff:SetNormal(dir)
		eff:SetMagnitude(skid * mul)
		eff:SetRadius(r * mul)
		eff:SetEntity(ent)
		for _ = 1, PUFFS do util.Effect("simfphys_tiresmoke", eff) end
	end
end

local function Rest(ent, C, dt)
	if next(C.snd) or C.dustOn then StopAll(ent, C) end
	C.skidId, C.rollId, C.pmSkid, C.pmRoll = nil, nil, nil, nil
	C.skidS = 0
	if C.heat then C.heat = max(C.heat - HEAT_DOWN * dt, 0) end
end

local function UpdateTire(ent, C, fx, dt)
	local pos = ent:GetPos()
	local skidNW = ent:GetNW2Float("PropTireSkid", 0)
	if C.last and skidNW == 0 and pos:DistToSqr(C.last) < REST * REST then
		C.last = pos
		Rest(ent, C, dt)
		return
	end
	local vel = C.last and (pos - C.last) / dt or Vector()
	C.last = pos

	local r = ent:OBBMaxs().x
	DOWN.z = -(r + 8)
	TR.start = pos
	TR.endpos = pos + DOWN
	local tr = util.TraceLine(TR)
	local contact = tr.Hit and (pos - tr.HitPos):Dot(tr.HitNormal) <= r + 4
	local s = contact and PropTire.TraceMat(tr) or 0
	local speed = contact and vel:Length() or 0
	if speed > 20 then C.fwd = vel end
	C.real = band(fx, 4) ~= 0 and ent:GetNW2Float("PropTireHeat", 0) or nil
	local set, dset = SndSet(fx), DustSet(fx)
	local simf = set == SET_SIMF or dset == DUST_SIMF or dset == DUST_SIMF_FILES
	local name = simf and contact and util.GetSurfacePropName(tr.SurfaceProps) or ""

	local now = RealTime()
	if contact then C.contactT, C.lastS, C.lastName = now, s, name end
	local held = contact or (C.contactT ~= nil and now - C.contactT < CONTACT_HOLD)
	local target = held and skidNW or 0
	local sk, step = C.skidS or 0, dt / SKID_FADE
	if target > sk then sk = min(target, sk + step) else sk = max(target, sk - step) end
	C.skidS = sk
	local skid = sk

	if band(fx, 1) ~= 0 and held then
		local ss, sname, sspeed = contact and s or C.lastS or 0, contact and name or C.lastName or "", vel:Length()
		if set ~= SET_ACE then Layer(ent, C, "skid2", nil, 0, 100) end
		if set == SET_ACE then
			AceSounds(ent, C, ss, sspeed, skid)
		elseif set == SET_LVS then
			LvsSounds(ent, C, ss, sspeed, skid, r)
		elseif set == SET_SIMF then
			SimfSounds(ent, C, sname, sspeed, skid)
		elseif set == SET_CUSTOM then
			CustomSounds(ent, C, ss, sspeed, skid)
		elseif set == SET_GLIDE_FILES then
			GlideSounds(ent, C, ss, sspeed, skid)
		else
			TableSounds(ent, C, set == SET_GLIDE and Glide.WHEEL_SOUNDS or HL2, ss, sspeed, skid)
		end
	elseif band(fx, 1) ~= 0 then
		for key, path in pairs(C.path) do
			if C.snd[key] then Layer(ent, C, key, path, 0, C.pit[key] or 100) end
		end
	elseif next(C.snd) then
		StopSounds(C)
	end
	if not contact then skid = 0 end

	local mset = band(fx, 2) ~= 0 and contact and C.fwd and MarkSet(fx)
	local skidOn = mset and skid > MARK_SKID
	local rollOn = mset and SOFT[s] and s ~= MAT_SLOSH and speed > MARK_ROLL
	local w = mset and ent:GetNW2Float("PropTireHW", 8)
	if mset == MARKS_PROPER or mset == MARKS_GLIDE_FILES then
		local glide = mset == MARKS_GLIDE_FILES
		local fwd = C.fwd:GetNormalized()
		C.pmSkid = skidOn and PropTire.MarkPiece(C.pmSkid, tr.HitPos, fwd, tr.HitNormal, w, MARK_SKID_COLOR,
			(glide and 255 or 200) * skid, glide and "glide_skid") or nil
		local rc = rollOn and MARK_ROLL_COLOR[PropTire.SurfaceGroup(s).id]
		C.pmRoll = rc and PropTire.MarkPiece(C.pmRoll, tr.HitPos, fwd, tr.HitNormal, w, rc,
			glide and 200 or 130, glide and "glide_roll") or nil
		C.skidId, C.rollId = nil, nil
	elseif mset == MARKS_GLIDE then
		C.skidId = skidOn and Glide.AddSkidMarkPiece(C.skidId, tr.HitPos, C.fwd * 1, tr.HitNormal, w, skid) or nil
		C.rollId = rollOn and Glide.AddTireRollPiece(C.rollId, tr.HitPos, C.fwd * 1, tr.HitNormal, w, 1) or nil
		C.pmSkid, C.pmRoll = nil, nil
	else
		C.skidId, C.rollId, C.pmSkid, C.pmRoll = nil, nil, nil, nil
	end

	local mul = math.floor(fx / 1024) / 10
	if mul <= 0 then mul = 1 end
	local size = Clamp(r * 0.6, 3, 10) * mul
	local dustOn = band(fx, 8) ~= 0
	if dustOn and (dset == DUST_SIMF or dset == DUST_SIMF_FILES) then
		SimfDust(ent, C, contact, name, tr, s, speed, skid, r, dt, mul, size, dset == DUST_SIMF_FILES)
	else
		if C.dustOn then StopDust(ent, C) end
		if dustOn and (dset == DUST_PROPER or dset == DUST_GLIDE_FILES) then
			ProperDust(ent, C, contact, tr, s, vel, speed, skid, dt, size, dset == DUST_GLIDE_FILES and "glide" or nil)
		elseif dustOn and dset == DUST_GLIDE and contact then
			GlideDust(ent, C, tr, s, vel, speed, skid, size)
		end
	end
end

local function Forget(ent, C)
	StopAll(ent, C)
	tires[ent] = nil
end

local Iterate = ents.Iterator or function() return ipairs(ents.GetAll()) end
timer.Create("PropTireScan", SCAN, 0, function()
	for _, ent in Iterate() do
		if not tires[ent] and ent:GetNW2Int("PropTireFX", 0) ~= 0 then
			tires[ent] = { snd = {}, path = {}, vol = {}, pit = {}, quiet = {}, custom = {} }
		end
	end
end)

local cvOthers = GetConVar("proptire_others")
local nextUpdate, lastUpdate = 0, 0
hook.Add("Think", "PropTire", function()
	for ent, C in pairs(dusting) do
		if IsValid(ent) and C.dust:IsValid() then
			C.dust:SetControlPoint(0, DustPos(ent, C))
		else
			dusting[ent] = nil
		end
	end

	local t = RealTime()
	if t < nextUpdate then return end
	nextUpdate = t + RATE
	local dt = Clamp(t - lastUpdate, RATE, 1)
	lastUpdate = t

	local eye = EyePos()
	local me = LocalPlayer()
	local others = cvOthers:GetBool()
	for ent, C in pairs(tires) do
		if not IsValid(ent) then
			Forget(ent, C)
		else
			local fx = ent:GetNW2Int("PropTireFX", 0)
			if fx == 0 then
				Forget(ent, C)
			elseif ent:IsDormant() or ent:GetPos():DistToSqr(eye) > MAX_DIST * MAX_DIST
				or not others and ent:GetNW2Entity("PropTireOwner") ~= me then
				Rest(ent, C, dt)
				C.last, C.heat = nil, 0
			else
				UpdateTire(ent, C, fx, dt)
			end
		end
	end
end)

hook.Add("EntityRemoved", "PropTire", function(ent)
	local C = tires[ent]
	if C then Forget(ent, C) end
end)
