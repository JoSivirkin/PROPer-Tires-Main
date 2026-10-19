AddCSLuaFile()

PropTire = PropTire or {}

PropTire.SND_SETS = { hl2 = 0, glide = 1, simfphys = 2, custom = 3, ace = 5 }
PropTire.DUST_SETS = { glide = 0, simfphys = 1, proper = 2 }
PropTire.MARK_SETS = { glide = 0, proper = 1 }
PropTire.HEAT_LIMIT = { race = 110, sport = 95, dirt = 80, military = 120, mud = 75, slick = 120, drift = 100 }

PropTire.SURFACES = {
	{ id = "asphalt", ru = "Асфальт / бетон", en = "Asphalt / concrete", mats = { MAT_CONCRETE, MAT_TILE } },
	{ id = "dirt",    ru = "Грунт / гравий",  en = "Dirt / gravel",      mats = { MAT_DIRT } },
	{ id = "sand",    ru = "Песок",           en = "Sand",               mats = { MAT_SAND } },
	{ id = "grass",   ru = "Трава",           en = "Grass",              mats = { MAT_GRASS, MAT_FOLIAGE } },
	{ id = "snow",    ru = "Снег",            en = "Snow",               mats = { MAT_SNOW } },
	{ id = "metal",   ru = "Металл",          en = "Metal",              mats = { MAT_METAL, MAT_GRATE, MAT_VENT } },
	{ id = "wood",    ru = "Дерево",          en = "Wood",               mats = { MAT_WOOD } },
	{ id = "water",   ru = "Вода",            en = "Water",              mats = { MAT_SLOSH } },
	{ id = "other",   ru = "Остальное",       en = "Other",              mats = {} },
}

local GROUP_OF = {}
for _, g in ipairs(PropTire.SURFACES) do
	g.nw = "PropTireC_" .. g.id
	for _, m in ipairs(g.mats) do GROUP_OF[m] = g end
end
PropTire.SURFACE_OTHER = PropTire.SURFACES[#PropTire.SURFACES]

function PropTire.SurfaceGroup(matType)
	return GROUP_OF[matType] or PropTire.SURFACE_OTHER
end

local surfName, remapById = {}, {}
function PropTire.SurfaceName(id)
	if not id or id < 0 then return "" end
	local n = surfName[id]
	if not n then
		n = util.GetSurfacePropName(id) or ""
		surfName[id] = n
	end
	return n
end

function PropTire.TraceMat(tr)
	local id = tr.SurfaceProps
	if not id then return tr.MatType end
	local m = remapById[id]
	if m == nil then
		local n = string.lower(PropTire.SurfaceName(id))
		m = (n:find("rubber", 1, true) or n:find("tire", 1, true)) and MAT_CONCRETE or false
		remapById[id] = m
	end
	return m or tr.MatType
end

local SOUND_EXT = { wav = true, mp3 = true, ogg = true }
function PropTire.CleanSoundPath(path)
	if not isstring(path) then return "" end
	path = string.lower(string.Trim(path)):gsub("\\", "/")
	if #path == 0 or #path > 200 or path:find("..", 1, true) or path:sub(1, 1) == "/" then return "" end
	if path:find("[^%w_%-%./ ]") then return "" end
	if not SOUND_EXT[string.GetExtensionFromFilename(path) or ""] then return "" end
	return path
end

function PropTire.CubeBox(ent)
	local s = ent:OBBMaxs() - ent:OBBMins()
	if math.abs(s.x - s.y) > 0.01 or math.abs(s.y - s.z) > 0.01 then return false end
	local a, b = ent:GetModelBounds()
	local m = b - a
	return math.abs(m.x - m.y) > 0.5 or math.abs(m.y - m.z) > 0.5 or math.abs(m.x - m.z) > 0.5
end

function PropTire.WheelSize(mins, maxs, axis, radius, width)
	local size = maxs - mins
	local s = { size.x, size.y, size.z }
	if axis == 0 then
		axis = 1
		for i = 2, 3 do if s[i] < s[axis] then axis = i end end
	end
	local mr = 0
	for i = 1, 3 do if i ~= axis then mr = math.max(mr, s[i] / 2) end end
	return axis, s, math.Clamp(radius > 0 and radius or mr, 1, 200), math.Clamp(width > 0 and width or s[axis], 2, 15)
end

local CONTENT = {
	ace = "sound/acf_extra/vehiclefx/tires/road.wav",
	glide = "sound/glide/wheels/roll_dirt.wav",
	simfphys = "sound/simulated_vehicles/sfx/concrete_roll.wav",
}
local hasContent = {}

function PropTire.HasLua(id)
	if id == "glide" then return Glide ~= nil and Glide.WHEEL_SOUNDS ~= nil end
	if id == "simfphys" then return simfphys ~= nil end
	return false
end

function PropTire.HasContent(id)
	if hasContent[id] == nil then hasContent[id] = CONTENT[id] ~= nil and file.Exists(CONTENT[id], "GAME") end
	return hasContent[id]
end

function PropTire.Installed(id)
	return PropTire.HasLua(id) or PropTire.HasContent(id)
end

if CLIENT then
	CreateClientConVar("proptire_ru", "0", false, true)
	CreateClientConVar("proptire_others", "1", true, true, "PROPer Tires: show other players' tire effects", 0, 1)
	CreateClientConVar("proptire_debug", "0", true, true, "PROPer Tires: show tire data (grip, surface, temperature) next to wheels", 0, 1)

	function PropTire.RU()
		return GetConVarString("gmod_language") == "ru"
	end

	function PropTire.L(ru, en)
		return PropTire.RU() and ru or en
	end

	local function SyncLang()
		RunConsoleCommand("proptire_ru", PropTire.RU() and "1" or "0")
	end
	SyncLang()
	cvars.AddChangeCallback("gmod_language", SyncLang, "PropTire")
else
	function PropTire.RU(ply)
		return IsValid(ply) and ply:GetInfoNum("proptire_ru", 0) == 1
	end

	function PropTire.L(ply, ru, en)
		return PropTire.RU(ply) and ru or en
	end
end
