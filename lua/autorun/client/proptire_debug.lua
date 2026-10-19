if not PropTire or not PropTire.SURFACES then include("autorun/proptire_sh.lua") end

local cvDebug = GetConVar("proptire_debug")
local data, stamp = {}, 0

net.Receive("PropTireDbg", function()
	local list = {}
	for i = 1, net.ReadUInt(6) do
		list[i] = {
			idx = net.ReadUInt(16),
			mu = net.ReadUInt(12) / 100,
			surf = net.ReadUInt(4),
			temp = net.ReadUInt(10),
		}
	end
	data, stamp = list, RealTime()
end)

surface.CreateFont("PropTireDbg", { font = "Roboto", size = 16, weight = 600, extended = true })

local BG = Color(0, 0, 0, 170)
local MAIN = Color(255, 255, 255, 240)
local DIM = Color(190, 190, 190, 230)
local PAD = 6

hook.Add("HUDPaint", "PropTireDbg", function()
	if not cvDebug or not cvDebug:GetBool() or RealTime() - stamp > 1 then return end
	local L = PropTire.L
	surface.SetFont("PropTireDbg")
	for _, d in ipairs(data) do
		local ent = Entity(d.idx)
		if IsValid(ent) then
			local sp = ent:GetPos():ToScreen()
			if sp.visible then
				local g = PropTire.SURFACES[d.surf]
				local lines = {
					string.format("μ %.2f", d.mu),
					g and L(g.ru, g.en) or L("в воздухе", "airborne"),
					d.temp .. "°C",
				}
				local w, lh = 0, 16
				for _, s in ipairs(lines) do
					local tw, th = surface.GetTextSize(s)
					w, lh = math.max(w, tw), th
				end
				local bw, bh = w + PAD * 2, #lines * lh + PAD
				local x, y = math.floor(sp.x - bw / 2), math.floor(sp.y - bh / 2)
				draw.RoundedBox(4, x, y, bw, bh, BG)
				for i, s in ipairs(lines) do
					draw.SimpleText(s, "PropTireDbg", sp.x, y + PAD / 2 + (i - 1) * lh, i == 1 and MAIN or DIM, TEXT_ALIGN_CENTER)
				end
			end
		end
	end
end)
