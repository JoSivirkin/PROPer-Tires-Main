if not PropTire or not PropTire.SURFACES then include("autorun/proptire_sh.lua") end

TOOL.Category = "Construction"
TOOL.Name = "#tool.proptire.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
	radius = "0",
	width = "0",
	pres = "20",
	tread = "sport",
	axis = "0",
	sounds = "1",
	sndset = "ace",
	dust = "1",
	dustset = "proper",
	dustsize = "10",
	marks = "1",
	markset = "proper",
	grip = "300",
	heat = "0",
	heatrate = "100",
	coolrate = "100",
}
for _, g in ipairs(PropTire.SURFACES) do
	TOOL.ClientConVar["c_" .. g.id .. "_roll"] = ""
	TOOL.ClientConVar["c_" .. g.id .. "_skid"] = ""
	TOOL.ClientConVar["c_" .. g.id .. "_vol"] = "1"
end
local ConVarsDefault = TOOL:BuildConVarList()

local SND_NAMES = { ace = "ACE", proper = "PROPer", hl2 = "HL2", glide = "Glide", simfphys = "Simfphys", custom = "Custom" }
local DUST_NAMES = { proper = "Default", glide = "Glide", simfphys = "Simfphys" }
local MARK_NAMES = { proper = "Default", glide = "Glide" }

TOOL.Information = {
	{ name = "left" },
	{ name = "right" },
	{ name = "reload" },
}

if CLIENT then
	local L = PropTire.L
	language.Add("tool.proptire.name", "PROPer Tires")
	language.Add("tool.proptire.desc", L("Любой проп - шина с симуляцией сцепления", "Any prop becomes a tire with grip simulation"))
	language.Add("tool.proptire.left", L("Сделать проп шиной / обновить настройки", "Make the prop a tire / update settings"))
	language.Add("tool.proptire.right", L("Показать шину или покрытие под прицелом", "Show the tire or surface under the crosshair"))
	language.Add("tool.proptire.reload", L("Вернуть изначальную коллизию", "Restore the original collision"))
end

local function CanTire(ent)
	if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() then return false end
	local class = ent:GetClass()
	if string.find(class, "prop_vehicle_") or class == "prop_ragdoll" then return false end
	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
	if SERVER and not IsValid(ent:GetPhysicsObject()) then return false end
	return true
end

function TOOL:LeftClick(trace)
	local ent = trace.Entity
	if not CanTire(ent) then return false end
	if CLIENT then return true end

	local sndset = self:GetClientInfo("sndset")
	local custom
	if sndset == "custom" then
		custom = {}
		for _, g in ipairs(PropTire.SURFACES) do
			custom[g.id] = {
				roll = self:GetClientInfo("c_" .. g.id .. "_roll"),
				skid = self:GetClientInfo("c_" .. g.id .. "_skid"),
				vol = self:GetClientNumber("c_" .. g.id .. "_vol", 1),
			}
		end
	end

	PropTire.Apply(ent, {
		radius = self:GetClientNumber("radius"),
		width = self:GetClientNumber("width"),
		pres = self:GetClientNumber("pres"),
		tread = self:GetClientInfo("tread"),
		axis = self:GetClientNumber("axis"),
		sounds = self:GetClientNumber("sounds") ~= 0,
		sndset = sndset,
		custom = custom,
		dust = self:GetClientNumber("dust") ~= 0,
		dustset = self:GetClientInfo("dustset"),
		dustsize = self:GetClientNumber("dustsize"),
		marks = self:GetClientNumber("marks") ~= 0,
		markset = self:GetClientInfo("markset"),
		grip = self:GetClientNumber("grip", 300),
		heat = self:GetClientNumber("heat") ~= 0,
		heatrate = self:GetClientNumber("heatrate", 100),
		coolrate = self:GetClientNumber("coolrate", 100),
	}, self:GetOwner())
	local T = ent.PropTire
	if T then
		local ply = self:GetOwner()
		ply:ChatPrint(string.format(PropTire.L(ply,
			"Шина: радиус %.1f (сфера %.1f), ширина %.1f, ось %s. Нагрузка считается сама",
			"Tire: radius %.1f (sphere %.1f), width %.1f, axis %s. The load is computed automatically"),
			T.radius, T.rs, T.wid, PropTire.AXIS_NAMES[T.axis]))
	end
	return true
end

function TOOL:RightClick(trace)
	if CLIENT then return false end
	local ply = self:GetOwner()
	local L = function(ru, en) return PropTire.L(ply, ru, en) end
	local ent = trace.Entity
	local T = IsValid(ent) and ent.PropTire
	if T then
		ply:ChatPrint(string.format(L(
			"Шина: радиус %.1f (сфера %.1f), ширина %.1f, давление %.0f PSI, протектор %s, ось %s, сцепление %d%%, нагрузка %.0f Н",
			"Tire: radius %.1f (sphere %.1f), width %.1f, pressure %.0f PSI, tread %s, axis %s, grip %d%%, load %.0f N"),
			T.radius, T.rs, T.wid, T.pres, T.tread, PropTire.AXIS_NAMES[T.axis], math.Round((T.grip or 3) * 100), T.load))
		ply:ChatPrint(string.format(L("Вес на шинах: %.0f кг, шин: %d (замороженное, без гравитации, NoCollide и AdvBallsocket «только вращение» не считаются)",
			"Weight on tires: %.0f kg, tires: %d (frozen, gravity-off, NoCollide and rotation-only AdvBallsocket are not counted)"),
			T.mass or 0, T.ntires or 0))
		local off = L("выкл", "off")
		ply:ChatPrint(string.format(L("Звуки: %s, пыль: %s, следы: %s", "Sounds: %s, dust: %s, marks: %s"),
			T.sounds and SND_NAMES[T.sndset] or off,
			T.dust and (DUST_NAMES[T.dustset] .. L(", размер ", ", size ") .. T.dustsize) or off,
			T.marks and MARK_NAMES[T.markset] or off))
		if T.heat then
			ply:ChatPrint(string.format(L("Нагрев: %.0f°C (предел %d°C), нагрев %d%%, остывание %d%%",
				"Heating: %.0f°C (limit %d°C), heating %d%%, cooling %d%%"),
				T.temp, PropTire.HEAT_LIMIT[T.tread] or PropTire.HEAT_LIMIT.sport,
				math.Round(T.heatrate * 100), math.Round(T.coolrate * 100)))
		else
			ply:ChatPrint(L("Нагрев: выкл", "Heating: off"))
		end
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			ply:ChatPrint(string.format(L("Колесо: масса %.0f кг, инерция по оси %.1f кг*м^2",
				"Wheel: mass %.0f kg, axial inertia %.1f kg*m^2"),
				phys:GetMass(), phys:GetInertia():Dot(T.alocal)))
		end
		if T.dbgPly == ply then
			T.dbgPly = nil
			ply:ChatPrint(L("Отладка шины выключена", "Tire debug off"))
		else
			T.dbgPly = ply
			ply:ChatPrint(L("Отладка шины включена (ПКМ ещё раз - выключить)", "Tire debug on (right-click again to turn off)"))
		end
	else
		local mat = PropTire.TraceMat(trace)
		local mu = PropTire.Friction(self:GetClientInfo("tread"), mat, self:GetClientNumber("pres"))
		local grip = math.Clamp(math.Round(self:GetClientNumber("grip", 300)), 50, 500)
		ply:ChatPrint(string.format(L("Покрытие: %s (%s), трение протектора %.2f (со сцеплением %d%%: %.2f)",
			"Surface: %s (%s), tread friction %.2f (with grip %d%%: %.2f)"),
			PropTire.MatName(ply, mat), PropTire.SurfaceName(trace.SurfaceProps), mu, grip, mu * grip / 100))
	end
	return false
end

function TOOL:Reload(trace)
	local ent = trace.Entity
	if not CanTire(ent) then return false end
	if CLIENT then return true end
	local ply = self:GetOwner()
	if not ent.PropTire then
		if not PropTire.MSData(ent) or not PropTire.RemoveMS(ent) then return false end
		ply:ChatPrint(PropTire.L(ply, "Make Spherical снят, у пропа снова изначальная коллизия",
			"Make Spherical removed, the prop has its original collision again"))
		return true
	end
	PropTire.Restore(ent)
	ply:ChatPrint(PropTire.L(ply, "Шина снята, у пропа снова изначальная коллизия", "Tire removed, the prop has its original collision again"))
	return true
end

if SERVER then return end

local L = PropTire.L

local previewChan
local function StopPreview()
	if IsValid(previewChan) then previewChan:Stop() end
	previewChan = nil
end

local function TogglePreview(path)
	if IsValid(previewChan) then StopPreview() return end
	path = PropTire.CleanSoundPath(path)
	if path == "" then return end
	sound.PlayFile("sound/" .. path, "noplay", function(ch)
		if not IsValid(ch) then return end
		StopPreview()
		previewChan = ch
		ch:Play()
	end)
end

local function OpenBrowser(onPick)
	local f = vgui.Create("DFrame")
	f:SetTitle(L("PROPer Tires - выбор звука", "PROPer Tires - pick a sound"))
	f:SetSize(760, 480)
	f:Center()
	f:MakePopup()
	f.OnClose = StopPreview

	local bottom = vgui.Create("DPanel", f)
	bottom:Dock(BOTTOM)
	bottom:SetTall(24)
	bottom:DockMargin(0, 4, 0, 0)
	bottom.Paint = nil
	local pick = vgui.Create("DButton", bottom)
	pick:Dock(RIGHT)
	pick:SetWide(90)
	pick:SetText(L("Выбрать", "Select"))
	local play = vgui.Create("DButton", bottom)
	play:Dock(RIGHT)
	play:SetWide(110)
	play:DockMargin(0, 0, 4, 0)
	play:SetText(L("Слушать / стоп", "Play / stop"))
	play:SetImage("icon16/sound.png")
	local pathEntry = vgui.Create("DTextEntry", bottom)
	pathEntry:Dock(FILL)
	pathEntry:DockMargin(0, 0, 4, 0)
	pathEntry:SetEditable(false)

	local search = vgui.Create("DTextEntry", f)
	search:Dock(TOP)
	search:DockMargin(0, 0, 0, 4)
	search:SetPlaceholderText(L("Поиск в выбранной папке", "Search in the selected folder"))
	search:SetUpdateOnType(true)

	local div = vgui.Create("DHorizontalDivider", f)
	div:Dock(FILL)
	local tree = vgui.Create("DTree", div)
	local list = vgui.Create("DListView", div)
	list:AddColumn(L("Файл", "File"))
	list:SetMultiSelect(false)
	div:SetLeft(tree)
	div:SetRight(list)
	div:SetLeftWidth(260)

	local selected, curDir, curFiles = nil, "", {}

	local function ShowFiles()
		list:Clear()
		local q = string.lower(search:GetValue() or "")
		for _, name in ipairs(curFiles) do
			if q == "" or string.find(string.lower(name), q, 1, true) then list:AddLine(name) end
		end
	end

	local function OpenDir(node, dir)
		curDir = dir
		local files, dirs = file.Find("sound/" .. dir .. "*", "GAME")
		curFiles = {}
		for _, fn in ipairs(files or {}) do
			if PropTire.CleanSoundPath(dir .. fn) ~= "" then curFiles[#curFiles + 1] = fn end
		end
		table.sort(curFiles)
		if not node.Filled then
			node.Filled = true
			dirs = dirs or {}
			table.sort(dirs)
			for _, d in ipairs(dirs) do
				local child = node:AddNode(d, "icon16/folder.png")
				child.DoClick = function() OpenDir(child, dir .. d .. "/") end
			end
			node:SetExpanded(true)
		end
		ShowFiles()
	end

	local root = tree:AddNode("sound", "icon16/folder_explore.png")
	root.DoClick = function() OpenDir(root, "") end
	OpenDir(root, "")

	search.OnValueChange = ShowFiles
	list.OnRowSelected = function(_, _, line)
		selected = curDir .. line:GetColumnText(1)
		pathEntry:SetValue(selected)
	end
	list.DoDoubleClick = function(_, _, line)
		onPick(curDir .. line:GetColumnText(1))
		f:Close()
	end
	play.DoClick = function()
		if selected then TogglePreview(selected) else StopPreview() end
	end
	pick.DoClick = function()
		if selected then onPick(selected) end
		f:Close()
	end
end

local function SoundLine(parent, label, cvar)
	local line = vgui.Create("DPanel", parent)
	line:Dock(TOP)
	line:SetTall(22)
	line:DockMargin(0, 1, 0, 1)
	line.Paint = nil
	local lbl = vgui.Create("DLabel", line)
	lbl:Dock(LEFT)
	lbl:SetWide(60)
	lbl:SetText(label)
	lbl:SetDark(true)
	local play = vgui.Create("DButton", line)
	play:Dock(RIGHT)
	play:SetWide(24)
	play:SetText("")
	play:SetImage("icon16/sound.png")
	play:SetTooltip(L("Слушать / стоп", "Play / stop"))
	play.DoClick = function() TogglePreview(GetConVarString(cvar)) end
	local browse = vgui.Create("DButton", line)
	browse:Dock(RIGHT)
	browse:SetWide(24)
	browse:DockMargin(0, 0, 2, 0)
	browse:SetText("")
	browse:SetImage("icon16/folder_explore.png")
	browse:SetTooltip(L("Выбрать в браузере звуков", "Pick in the sound browser"))
	browse.DoClick = function() OpenBrowser(function(path) RunConsoleCommand(cvar, path) end) end
	local clear = vgui.Create("DButton", line)
	clear:Dock(RIGHT)
	clear:SetWide(24)
	clear:DockMargin(0, 0, 2, 0)
	clear:SetText("")
	clear:SetImage("icon16/cross.png")
	clear:SetTooltip(L("Без звука", "No sound"))
	clear.DoClick = function() RunConsoleCommand(cvar, "") end
	local entry = vgui.Create("DTextEntry", line)
	entry:Dock(FILL)
	entry:DockMargin(0, 0, 2, 0)
	entry:SetConVar(cvar)
end

local customFrame
local function OpenCustomWindow()
	if IsValid(customFrame) then customFrame:MakePopup() return end
	local f = vgui.Create("DFrame")
	customFrame = f
	f:SetTitle(L("PROPer Tires - свои звуки шин", "PROPer Tires - custom tire sounds"))
	f:SetSize(620, 560)
	f:Center()
	f:MakePopup()
	f.OnClose = StopPreview

	local help = vgui.Create("DLabel", f)
	help:Dock(TOP)
	help:DockMargin(0, 0, 0, 4)
	help:SetWrap(true)
	help:SetAutoStretchVertical(true)
	help:SetText(L("Для набора звуков Custom. На каждую поверхность - звук качения, звук заноса и громкость; пусто - тишина. "
		.. "Звуки должны быть циклами (wav с точками цикла), иначе доиграют и начнутся заново с паузой. "
		.. "Только звуки из игры и установленных аддонов: звук, которого нет на сервере, не примется; "
		.. "у игрока без нужного аддона - тишина. Наборы сохраняются пресетами в панели инструмента.",
		"For the Custom sound set. Each surface gets a rolling sound, a skid sound and a volume; empty means silence. "
		.. "Sounds must be loops (wav with loop points), otherwise they play to the end and restart after a gap. "
		.. "Only sounds from the game and installed addons: a sound the server does not have is not accepted; "
		.. "players without the addon hear silence. Sets are saved with presets in the tool panel."))

	local scroll = vgui.Create("DScrollPanel", f)
	scroll:Dock(FILL)
	for _, g in ipairs(PropTire.SURFACES) do
		local row = scroll:Add("DPanel")
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, 4)
		row:DockPadding(6, 4, 6, 4)
		row:SetTall(102)
		local name = vgui.Create("DLabel", row)
		name:Dock(TOP)
		name:SetText(L(g.ru, g.en))
		name:SetFont("DermaDefaultBold")
		name:SetDark(true)
		SoundLine(row, L("Качение", "Roll"), "proptire_c_" .. g.id .. "_roll")
		SoundLine(row, L("Занос", "Skid"), "proptire_c_" .. g.id .. "_skid")
		local vol = vgui.Create("DNumSlider", row)
		vol:Dock(TOP)
		vol:SetText(L("Громкость", "Volume"))
		vol:SetMinMax(0, 1)
		vol:SetDecimals(2)
		vol:SetConVar("proptire_c_" .. g.id .. "_vol")
		vol:SetDark(true)
	end
end

local function Section(panel, title)
	local line = vgui.Create("DPanel")
	line:SetTall(2)
	line.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(0, 0, w, h)
	end
	panel:AddItem(line)
	panel:Help(title):SetFont("DermaDefaultBold")
end

local function SetChoice(panel, cvar, options)
	local combo = panel:ComboBox(L("Набор", "Set"), cvar)
	combo:SetSortItems(false)
	local missing = {}
	for _, o in ipairs(options) do
		if o.need and not PropTire.Installed(o.need) then
			missing[o.id] = o.name
			combo:AddChoice(o.name .. L(" - не установлен", " - not installed"), o.id, false, "icon16/cross.png")
		else
			combo:AddChoice(o.name, o.id)
		end
	end
	local base = combo.OnSelect
	combo.OnSelect = function(self, index, value, data)
		if missing[data] then
			notification.AddLegacy(string.format(L("Нужен аддон %s", "Requires the %s addon"), missing[data]), NOTIFY_ERROR, 4)
			surface.PlaySound("buttons/button10.wav")
			local cur = GetConVarString(cvar)
			self:SetValue(self.GetOptionTextByData and self:GetOptionTextByData(cur) or cur)
			return
		end
		if base then base(self, index, value, data) else RunConsoleCommand(cvar, tostring(data or value)) end
	end
	return combo
end

function TOOL.BuildCPanel(panel)
	panel:Help("#tool.proptire.desc")
	panel:AddControl("ComboBox", {
		MenuButton = 1,
		Folder = "proptire",
		Options = { ["#preset.default"] = ConVarsDefault },
		CVars = table.GetKeys(ConVarsDefault),
	})

	panel:NumSlider(L("Радиус", "Radius"), "proptire_radius", 0, 200, 1)
	panel:NumSlider(L("Ширина пятна", "Patch width"), "proptire_width", 0, 15, 1)
	panel:Help(L("0 - по модели", "0 = from the model"))
	panel:NumSlider(L("Давление, PSI", "Pressure, PSI"), "proptire_pres", 5, 55, 0)
	panel:NumSlider(L("Сцепление, %", "Grip, %"), "proptire_grip", 50, 500, 0)
	panel:Help(L("Давление: выше - шина жёстче, отклик резче; ниже - мягче, а на грунте, песке, траве и снегу цепче (до +15%). Ширина пятна: шире - цепче (до ±10%). Сфера - ровно по колесу.",
		"Pressure: higher - stiffer tire, sharper response; lower - softer, with more grip on dirt, sand, grass and snow (up to +15%). Contact patch width: wider - more grip (up to ±10%). The sphere matches the wheel exactly."))
	panel:Help(L("Сцепление: 100% - честная физика, больше - цепче и проще в управлении.",
		"Grip: 100% is realistic physics, more is grippier and easier to drive."))

	local tread = panel:ComboBox(L("Протектор", "Tread"), "proptire_tread")
	tread:SetSortItems(false)
	tread:AddChoice(L("Гоночный", "Race"), "race")
	tread:AddChoice(L("Спортивный", "Sport"), "sport")
	tread:AddChoice(L("Грунтовый", "Off-road"), "dirt")
	panel:Help(L("Гоночный - очень цепкий на асфальте и бетоне, почти без сцепления на грунте. Спортивный - средний везде. Грунтовый - лучший на грунте и песке.",
		"Race - very grippy on asphalt and concrete, almost no grip on dirt. Sport - average everywhere. Off-road - best on dirt and sand."))

	local axis = panel:ComboBox(L("Ось колеса", "Wheel axis"), "proptire_axis")
	axis:SetSortItems(false)
	axis:AddChoice(L("Авто (самая тонкая сторона модели)", "Auto (thinnest side of the model)"), "0")
	axis:AddChoice("X", "1")
	axis:AddChoice("Y", "2")
	axis:AddChoice("Z", "3")

	panel:Help(L("Связи пропа сохраняются, масса и заморозка тоже. Нагрузку на шину аддон считает сам раз в секунду: масса конструкции / число шин.",
		"The prop keeps its constraints, mass and freeze state. The addon computes the tire load itself once a second: contraption mass / number of tires."))
	panel:Help(L("Идея - аддоны Advanced Tire (Tibbles) и Make Spherical (Falcqn). Модель шины - «магическая формула» Пасейки.",
		"Inspired by the Advanced Tire (Tibbles) and Make Spherical (Falcqn) addons. Tire model: Pacejka Magic Formula."))

	Section(panel, L("Нагрев шин", "Tire heating"))
	panel:CheckBox(L("Включить", "Enable"), "proptire_heat")
	panel:NumSlider(L("Нагрев, %", "Heating, %"), "proptire_heatrate", 10, 200, 0)
	panel:NumSlider(L("Остывание, %", "Cooling, %"), "proptire_coolrate", 10, 200, 0)

	Section(panel, L("Звуки шин", "Tire sounds"))
	panel:CheckBox(L("Включить", "Enable"), "proptire_sounds")
	SetChoice(panel, "proptire_sndset", {
		{ id = "hl2", name = "HL2" },
		{ id = "ace", name = "ACE", need = "ace" },
		{ id = "glide", name = "Glide", need = "glide" },
		{ id = "simfphys", name = "Simfphys", need = "simfphys" },
		{ id = "custom", name = "Custom" },
	})
	panel:Button(L("Свои звуки по поверхностям...", "Custom sounds per surface...")).DoClick = OpenCustomWindow

	Section(panel, L("Пыль и дым", "Dust and smoke"))
	panel:CheckBox(L("Включить", "Enable"), "proptire_dust")
	SetChoice(panel, "proptire_dustset", {
		{ id = "proper", name = "Default" },
		{ id = "glide", name = "Glide", need = "glide" },
		{ id = "simfphys", name = "Simfphys", need = "simfphys" },
	})
	panel:NumSlider(L("Размер", "Size"), "proptire_dustsize", 1, 10, 0)

	Section(panel, L("Следы шин", "Tire marks"))
	panel:CheckBox(L("Включить", "Enable"), "proptire_marks")
	SetChoice(panel, "proptire_markset", {
		{ id = "proper", name = "Default" },
		{ id = "glide", name = "Glide", need = "glide" },
	})
	panel:NumSlider(L("Следов у себя, кусков", "Local mark pieces"), "proptire_marks_max", 64, 8192, 0)
	panel:NumSlider(L("Следы живут, с", "Mark lifetime, s"), "proptire_marks_life", 5, 300, 0)
	panel:CheckBox(L("Эффекты шин других игроков", "Other players' tire effects"), "proptire_others")
	panel:CheckBox(L("Данные шин на экране (отладка)", "Tire data on screen (debug)"), "proptire_debug")
end
