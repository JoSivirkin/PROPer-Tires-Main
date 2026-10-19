PropTire = PropTire or {}

local cvMax = CreateClientConVar("proptire_marks_max", "1024", true, false, "PROPer Tires: how many tire mark pieces to keep", 64, 8192)
local cvLife = CreateClientConVar("proptire_marks_life", "30", true, false, "PROPer Tires: tire mark lifetime, seconds", 5, 300)

local CHUNK = 64
local REBUILD = 0.1
local FADE = 5
local STEP = 8
local BREAK = 60
local LIFT = 0.6

local function MarkMaterial(name, texture)
	return CreateMaterial(name, "UnlitGeneric", {
		["$basetexture"] = texture,
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$translucent"] = 1,
		["$nocull"] = 1,
	})
end

local SKINS = {
	default = { tex = "vgui/white", soft = true },
	glide_skid = { tex = "glide/skidmarks/skid_asphalt" },
	glide_roll = { tex = "glide/skidmarks/roll_dirt" },
}
for id, sk in pairs(SKINS) do sk.id = id sk.chunks = {} end

local pieceCount = 0
local WHITE = { 255, 255, 255 }

local function NewChunk(sk)
	local ch = { verts = {}, pieces = 0, dirty = false, nextBuild = 0, die = 0 }
	sk.chunks[#sk.chunks + 1] = ch
	return ch
end

local function DropChunk(sk, i)
	local ch = table.remove(sk.chunks, i)
	if ch.mesh then ch.mesh:Destroy() end
	pieceCount = pieceCount - ch.pieces
end

local function Build(ch)
	if ch.mesh then ch.mesh:Destroy() end
	ch.mesh = Mesh()
	ch.mesh:BuildFromTriangles(ch.verts)
	ch.dirty = false
	ch.nextBuild = RealTime() + REBUILD
end

local function V(pos, col, a, n, u, v)
	return { pos = pos, u = u, v = v, normal = n, color = Color(col[1], col[2], col[3], a) }
end

function PropTire.MarkPiece(strip, pos, fwd, normal, halfW, col, alpha, skin)
	local sk = SKINS[skin or "default"] or SKINS.default
	if not sk.soft then col = WHITE end
	local right = normal:Cross(fwd)
	if right:LengthSqr() < 0.01 then return strip end
	right:Normalize()
	local c = pos + normal * LIFT
	local last = strip and strip.sk == sk and strip.c
	if last then
		local d2 = c:DistToSqr(last)
		if d2 < STEP * STEP then return strip end
		if d2 > BREAK * BREAK then last = nil end
	end
	local now = { l = c + right * halfW, c = c, r = c - right * halfW, a = alpha, sk = sk }
	if last then
		local list = sk.chunks
		local ch = list[#list]
		if not ch or ch.pieces >= CHUNK then
			if ch then Build(ch) end
			ch = NewChunk(sk)
		end
		local vt, n = ch.verts, normal
		local pl, pc, pr, pa = strip.l, strip.c, strip.r, strip.a
		local e0, e1 = 0, 0
		if not sk.soft then e0, e1 = pa, alpha end
		local t = {
			V(pl, col, e0, n, 0, 0), V(pc, col, pa, n, 0.5, 0), V(now.c, col, alpha, n, 0.5, 1),
			V(pl, col, e0, n, 0, 0), V(now.c, col, alpha, n, 0.5, 1), V(now.l, col, e1, n, 0, 1),
			V(pc, col, pa, n, 0.5, 0), V(pr, col, e0, n, 1, 0), V(now.r, col, e1, n, 1, 1),
			V(pc, col, pa, n, 0.5, 0), V(now.r, col, e1, n, 1, 1), V(now.c, col, alpha, n, 0.5, 1),
		}
		for i = 1, #t do vt[#vt + 1] = t[i] end
		ch.pieces = ch.pieces + 1
		ch.dirty = true
		ch.die = RealTime() + cvLife:GetFloat()
		pieceCount = pieceCount + 1
		while pieceCount > cvMax:GetInt() and #list > 1 do DropChunk(sk, 1) end
	end
	return now
end

hook.Add("PreDrawTranslucentRenderables", "PropTireMarks", function(depth, sky, sky3d)
	if depth or sky or sky3d or pieceCount <= 0 then return end
	local t = RealTime()
	for _, sk in pairs(SKINS) do
		local list = sk.chunks
		if list[1] then
			if not sk.mat then sk.mat = MarkMaterial("proptire_mark_" .. sk.id, sk.tex) end
			local mat = sk.mat
			render.SetMaterial(mat)
			local i = 1
			while i <= #list do
				local ch = list[i]
				local a = (ch.die - t) / FADE
				if a <= 0 and ch.pieces > 0 then
					DropChunk(sk, i)
				else
					if ch.dirty and t >= ch.nextBuild then Build(ch) end
					if ch.mesh then
						mat:SetFloat("$alpha", math.Clamp(a, 0, 1))
						ch.mesh:Draw()
					end
					i = i + 1
				end
			end
			mat:SetFloat("$alpha", 1)
		end
	end
end)

local SMOKE = {}
for i = 1, 16 do SMOKE[i] = Material(string.format("particle/smokesprites_%04d", i)) end
local FLECK = Material("effects/fleck_cement1")
if FLECK:IsError() then FLECK = nil end

local GLIDE = "glide/effects/tire_particles/"
local GLIDE_DUST = { dirt = "dirt", sand = "sand", snow = "snow", water = "water" }
local glideMats = {}
local function GlideMat(name)
	if glideMats[name] == nil then
		local m = Material(GLIDE .. name)
		glideMats[name] = not m:IsError() and m or false
	end
	return glideMats[name] or nil
end
local function GlideSmoke()
	return GlideMat("tire_slip_forward_" .. math.random(4))
end

local DUST_COLOR = {
	dirt = { 115, 92, 66 }, sand = { 175, 155, 115 }, grass = { 95, 100, 62 }, snow = { 228, 232, 240 },
	water = { 205, 215, 225 }, asphalt = { 165, 165, 165 }, other = { 150, 145, 135 },
}

local emitter
local function Emit(mat, pos)
	if not emitter then emitter = ParticleEmitter(pos, false) end
	emitter:SetPos(pos)
	return emitter:Add(mat, pos)
end

local function Rand3(s)
	return Vector(math.Rand(-s, s), math.Rand(-s, s), math.Rand(-s, s))
end

function PropTire.DustPuff(group, pos, vel, dir, amount, size, skin)
	local col = DUST_COLOR[group] or DUST_COLOR.other
	local mat = SMOKE[math.random(16)]
	if skin == "glide" then
		if group == "grass" then return end
		local g = GLIDE_DUST[group] and GlideMat(GLIDE_DUST[group])
		if g then mat, col = g, { 255, 255, 255 } end
	end
	local p = Emit(mat, pos + vector_up * size * 0.5)
	if not p then return end
	p:SetVelocity(vel * 0.25 + dir * 30 + vector_up * 25 + Rand3(15))
	p:SetDieTime(math.Rand(1.5, 2.5))
	p:SetStartAlpha(70 * amount)
	p:SetEndAlpha(0)
	p:SetStartSize(size * math.Rand(0.8, 1.2))
	p:SetEndSize(size * math.Rand(3.5, 5))
	p:SetRoll(math.Rand(0, 360))
	p:SetRollDelta(math.Rand(-1, 1))
	p:SetColor(col[1], col[2], col[3])
	p:SetAirResistance(60)
	p:SetGravity(Vector(0, 0, -15))
end

function PropTire.Clumps(group, pos, dir, amount, size, skin)
	local mat, col = FLECK, DUST_COLOR[group] or DUST_COLOR.other
	col = { col[1] * 0.7, col[2] * 0.7, col[3] * 0.7 }
	if skin == "glide" and group == "grass" then
		local g = GlideMat("grass_debris")
		if g then mat, col = g, { 255, 255, 255 } end
	end
	if not mat then return end
	for _ = 1, amount > 0.6 and 2 or 1 do
		local p = Emit(mat, pos + vector_up * 2)
		if not p then return end
		p:SetVelocity(dir * math.Rand(80, 160) + vector_up * math.Rand(80, 160) + Rand3(40))
		p:SetDieTime(math.Rand(0.8, 1.2))
		p:SetStartAlpha(255)
		p:SetEndAlpha(0)
		p:SetStartSize(size * math.Rand(0.15, 0.3))
		p:SetEndSize(0)
		p:SetRoll(math.Rand(0, 360))
		p:SetRollDelta(math.Rand(-6, 6))
		p:SetColor(col[1], col[2], col[3])
		p:SetGravity(Vector(0, 0, -500))
		p:SetCollide(true)
		p:SetBounce(0.3)
	end
end

function PropTire.TireSmoke(pos, dir, strength, size, skin)
	local mat = skin == "glide" and GlideSmoke() or SMOKE[math.random(16)]
	local p = Emit(mat, pos + vector_up * size * 0.5)
	if not p then return end
	p:SetVelocity(dir * 25 + vector_up * 15 + Rand3(12))
	p:SetDieTime(math.Rand(3, 5))
	p:SetStartAlpha(110 * strength)
	p:SetEndAlpha(0)
	p:SetStartSize(size * math.Rand(1, 1.5))
	p:SetEndSize(size * math.Rand(7, 10))
	p:SetRoll(math.Rand(0, 360))
	p:SetRollDelta(math.Rand(-0.5, 0.5))
	p:SetColor(200, 200, 200)
	p:SetAirResistance(40)
	p:SetGravity(Vector(0, 0, 8))
end
