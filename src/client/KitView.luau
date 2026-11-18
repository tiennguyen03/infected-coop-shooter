--!strict
-- The pieces of the Loadout screen (docs/STYLES.md section 5 > The Loadout screen) that every
-- kit screen shares: the Loadmaster's Loadout (LoadoutMenu) and the Carrier's desk screens
-- (the lobby's DeskScreen: the Quartermaster, Call-ins, Vehicles). The menu-style frame fitted
-- to the screen with its "//" header, a row with the item's flat shape, and the inspect panel
-- with the item turning in 3D (Shared.Showcase) over its stat bars (Rules/ArmsStats for guns,
-- Rules/KitCard for call-ins and grenades, read from each item's own Config row). One look,
-- one place to change it.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local ArmsStats = require(Rules:WaitForChild("ArmsStats"))
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Config = require(Shared:WaitForChild("Config"))
local KitCard = require(Rules:WaitForChild("KitCard"))
local Showcase = require(Shared:WaitForChild("Showcase"))
local WeaponDefinitions = require(Shared:WaitForChild("WeaponDefinitions"))
local HudTheme = require(script.Parent.HudTheme)

local KitView = {}

local C = HudTheme.Color
local SCREEN = Config.LoadoutScreen
local FOV = 30
KitView.ELEVATION = math.rad(12) -- the inspect camera looks down this much
local MAX_FIT = 1.5 -- the screen grows with the display up to this (1440p and up)

export type Kind = "gun" | "grenade" | "callIn"

export type Entry = {
	id: string,
	kind: Kind,
	section: string, -- "PRIMARY"
	title: string, -- "SERVICE RIFLE"
	subtitle: string, -- "M16A4"
	description: string,
}

-- Every size on the screen, in design pixels (the frame's UIScale fits it to the display).
export type Layout = {
	compact: boolean,
	size: Vector2,
	pad: number,
	header: number, -- header text size
	bodyTop: number,
	footer: number, -- footer height
	column: number, -- a list's width
	gap: number,
	row: number, -- a row's height
	shape: Vector2, -- a row's item shape
	name: number,
	sub: number,
	stat: number,
	body: number,
	title: number, -- the inspected item's name
	view: number, -- the inspect view's height
	confirm: Vector2,
}

KitView.WIDE = table.freeze({
	compact = false,
	size = Vector2.new(1560, 880),
	pad = 28,
	header = 36,
	bodyTop = 100,
	footer = 100,
	column = 272,
	gap = 14,
	row = 64,
	shape = Vector2.new(92, 48),
	name = 17,
	sub = 13,
	stat = 15,
	body = 16,
	title = 32,
	view = 300,
	confirm = Vector2.new(300, 56),
}) :: Layout

KitView.COMPACT = table.freeze({
	compact = true,
	size = Vector2.new(960, 540),
	pad = 18,
	header = 28,
	bodyTop = 112,
	footer = 80,
	column = 410,
	gap = 12,
	row = 72,
	shape = Vector2.new(100, 54),
	name = 20,
	sub = 15,
	stat = 17,
	body = 17,
	title = 28,
	view = 180,
	confirm = Vector2.new(250, 60),
}) :: Layout

-- --------------------------------------------------------------- entries and numbers
function KitView.weaponEntry(id: string, section: string): Entry
	local row = WeaponDefinitions.get(id)
	return {
		id = id,
		kind = "gun",
		section = section,
		title = string.upper(row.Name),
		subtitle = row.Designation,
		description = row.Description,
	}
end

function KitView.grenadeEntry(id: string): Entry
	local row = WeaponDefinitions.grenade(id)
	return {
		id = id,
		kind = "grenade",
		section = "GRENADE",
		title = string.upper(row.Name),
		subtitle = row.Designation,
		description = row.Description,
	}
end

function KitView.callInEntry(id: string, section: string?): Entry
	local row = CallInDefinitions.get(id)
	return {
		id = id,
		kind = "callIn",
		section = section or "CALL-IN",
		title = string.upper(if row then row.Name else id),
		subtitle = if row then row.Codename else "",
		description = if row then row.Description else "",
	}
end

function KitView.gunStats(id: string): ArmsStats.Stats
	local def = WeaponDefinitions.get(id)
	return {
		damage = def.Damage,
		pellets = def.Pellets,
		fireCooldown = def.FireCooldown,
		magazine = def.MagazineSize,
		reload = def.ReloadTime,
		range = def.Range,
		adsSpread = def.AdsSpread,
	}
end

function KitView.grenadeBlock(id: string): { [string]: any }
	return (Config.Grenade :: any)[WeaponDefinitions.grenade(id).ConfigKey] or {}
end

function KitView.callInBlock(id: string): { [string]: any }
	local row = CallInDefinitions.get(id)
	return if row then (Config.CallIns :: any)[row.ConfigKey] or {} else {}
end

-- Every gun's, grenade's and call-in's numbers, for the bars' "against the rest".
export type Roster = {
	guns: { ArmsStats.Stats },
	noise: { number },
	grenades: { { [string]: any } },
	callIns: { { [string]: any } },
}

function KitView.roster(guns: { string }, grenades: { string }, callIns: { string }): Roster
	local roster: Roster = { guns = {}, noise = {}, grenades = {}, callIns = {} }
	for _, id in guns do
		table.insert(roster.guns, KitView.gunStats(id))
		table.insert(roster.noise, WeaponDefinitions.get(id).Noise)
	end
	for _, id in grenades do
		table.insert(roster.grenades, KitView.grenadeBlock(id))
	end
	for _, id in callIns do
		table.insert(roster.callIns, KitView.callInBlock(id))
	end
	return roster
end

-- The inspect panel's stat rows for `entry`; `barrel` is the gun's fitted barrel option.
function KitView.statRows(entry: Entry, roster: Roster, barrel: string?): { KitCard.Row }
	if entry.kind == "gun" then
		local rows: { KitCard.Row } = ArmsStats.rows(KitView.gunStats(entry.id), roster.guns)
		local def = WeaponDefinitions.get(entry.id)
		table.insert(rows, KitCard.stealth(WeaponDefinitions.shotNoise(def, barrel), roster.noise))
		return rows
	elseif entry.kind == "grenade" then
		return KitCard.grenade(KitView.grenadeBlock(entry.id), roster.grenades)
	end
	return KitCard.callIn(KitView.callInBlock(entry.id), roster.callIns)
end

-- --------------------------------------------------------------- 3D views
-- The camera distance that keeps `model` in a `view`-shaped ViewportFrame, seen side on from
-- `yaw` (or from any side when it turns), and the point to look at.
function KitView.fit(model: Model, view: Vector2, turning: boolean): (Vector3, number, number)
	local cframe, size = model:GetBoundingBox()
	local vHalf = math.rad(FOV / 2)
	local hHalf = math.atan(math.tan(vHalf) * view.X / math.max(view.Y, 1))
	-- Side on to its long axis: from +X when it is long along Z (a gun), else from -Z.
	local yaw = if size.X > size.Z then math.pi / 2 else 0
	local across = if turning
		then math.sqrt(size.X * size.X + size.Z * size.Z)
		else math.max(size.X, size.Z)
	local depth = if turning then across else math.min(size.X, size.Z)
	local distance = math.max(across / 2 / math.tan(hHalf), size.Y / 2 / math.tan(vHalf)) * 1.12
		+ depth / 2
	return cframe.Position, distance, yaw
end

function KitView.aim(
	camera: Camera,
	centre: Vector3,
	distance: number,
	yaw: number,
	elevation: number
)
	local offset = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(
		Vector3.new(math.cos(elevation), math.sin(elevation), 0) * distance
	)
	camera.CFrame = CFrame.lookAt(centre + offset, centre)
end

function KitView.viewport(parent: Instance, size: UDim2): (ViewportFrame, Camera)
	local frame = Instance.new("ViewportFrame")
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = frame
	frame.CurrentCamera = camera
	return frame, camera
end

-- An item's flat shape for its row: every part white and unlit, tinted by ImageColor3.
function KitView.fillShape(frame: ViewportFrame, camera: Camera, id: string, size: Vector2)
	for _, child in frame:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	local model = Showcase.get(id)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
			if part:IsA("MeshPart") then
				-- The palette texture off, so the shape reads flat (kept if Roblox refuses).
				pcall(function()
					part.TextureID = ""
				end)
			end
		end
	end
	model.Parent = frame
	local centre, distance, yaw = KitView.fit(model, size, false)
	KitView.aim(camera, centre, distance, yaw, 0)
end

-- Four L-shaped corner marks round a box (Prototype 2's framing, as the results screen's).
function KitView.corners(parent: GuiObject, color: Color3)
	local arm, thick = 18, 2
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		for _, horizontal in { true, false } do
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = color
			bar.AnchorPoint = corner
			bar.Position = UDim2.fromScale(corner.X, corner.Y)
			bar.Size = if horizontal
				then UDim2.fromOffset(arm, thick)
				else UDim2.fromOffset(thick, arm)
			bar.ZIndex = parent.ZIndex
			bar.Parent = parent
		end
	end
end

function KitView.list(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	if horizontal then
		layout.FillDirection = Enum.FillDirection.Horizontal
	end
	layout.Parent = parent
	return layout
end

function KitView.scroller(
	parent: Instance,
	position: Vector2,
	size: Vector2,
	bar: number
): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset(position.X, position.Y)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.ScrollBarThickness = bar
	frame.ScrollBarImageColor3 = C.TextDim
	frame.Selectable = false
	frame.Parent = parent
	return frame
end

-- --------------------------------------------------------------- the frame
export type Screen = {
	frame: Frame,
	L: Layout,
	W: number,
	H: number,
	touch: boolean,
	header: TextLabel,
	hint: TextLabel,
	connections: { RBXScriptConnection },
}

-- The menu-style frame (near-black red field, red 1 px box) centred in `parent` and fitted to
-- the screen, the "//" header and the dim hint under it. Compact under Config.LoadoutScreen.
-- Compact. The caller disconnects `connections` when it closes.
function KitView.screen(parent: Instance, title: string, hintText: string): Screen
	local connections: { RBXScriptConnection } = {}
	local gui: ScreenGui? = if parent:IsA("ScreenGui")
		then parent
		else parent:FindFirstAncestorOfClass("ScreenGui")
	local function available(): Vector2
		local camera = Workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
		return size - Vector2.new(0, GuiService:GetGuiInset().Y)
	end
	local room = available()
	local L: Layout = if room.X < SCREEN.Compact.X or room.Y < SCREEN.Compact.Y
		then KitView.COMPACT
		else KitView.WIDE
	local W, H = L.size.X, L.size.Y
	local touch = HudTheme.isTouch()

	local frame = HudTheme.rect(parent, UDim2.fromOffset(W, H), C.MenuBack, 0.06)
	frame.Name = "ArmsRoom"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Red
	stroke.Thickness = 1
	stroke.Parent = frame
	-- Fit the design size to the screen, over the ScreenGui's own UIScale.
	local fitScale = Instance.new("UIScale")
	fitScale.Parent = frame
	local function rescale()
		local space = available()
		local outerScale = gui and gui:FindFirstChildOfClass("UIScale")
		local outer = if outerScale then outerScale.Scale else 1
		local want = math.min(space.X * 0.96 / W, space.Y * 0.94 / H, MAX_FIT)
		fitScale.Scale = want / math.max(outer, 0.01)
	end
	rescale()
	local camera = Workspace.CurrentCamera
	if camera then
		-- Deferred: the ScreenGui's own UIScale listens to the same signal.
		table.insert(
			connections,
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				task.defer(rescale)
			end)
		)
	end

	local header = HudTheme.label(frame, {
		text = `//{title}`,
		font = HudTheme.Font.Headline,
		size = L.header,
		color = C.Text,
	})
	header.Position = UDim2.fromOffset(L.pad, if L.compact then 10 else 18)
	local hint = HudTheme.label(frame, { text = hintText, size = 13, color = C.TextDim })
	hint.Position = UDim2.fromOffset(L.pad + 2, 62)
	hint.Visible = not L.compact and not touch

	return {
		frame = frame,
		L = L,
		W = W,
		H = H,
		touch = touch,
		header = header,
		hint = hint,
		connections = connections,
	}
end

-- A BACK button in the frame's top right corner (design pixels: the frame is fitted).
function KitView.backButton(frame: Frame): TextButton
	local back = Instance.new("TextButton")
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(1, 0)
	back.Position = UDim2.new(1, -24, 0, 16)
	back.Size = UDim2.fromOffset(120, 36)
	back.BackgroundColor3 = C.Track
	back.BorderSizePixel = 0
	back.Font = HudTheme.Font.Headline
	back.TextSize = 16
	back.TextColor3 = C.Text
	back.Text = "BACK"
	back.Modal = true -- frees the mouse while the screen is open
	back.Parent = frame
	return back
end

-- The cream confirm button bottom right of the frame (SIGN FOR IT, BUY).
function KitView.confirmButton(screen: Screen, text: string): TextButton
	local L = screen.L
	local button = Instance.new("TextButton")
	button.Name = "Confirm"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -L.pad, 1, -(L.footer - L.confirm.Y) / 2)
	button.Size = UDim2.fromOffset(L.confirm.X, L.confirm.Y)
	button.BackgroundColor3 = C.MenuSelect
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = C.MenuSelectText
	button.TextSize = 20
	button.Font = HudTheme.Font.Headline
	button.Parent = screen.frame
	return button
end

-- --------------------------------------------------------------- the inspect panel
export type Inspect = {
	panel: Frame,
	kicker: TextLabel,
	name: TextLabel,
	sub: TextLabel,
	status: TextLabel,
	line: TextLabel,
	details: ScrollingFrame,
	show: (entry: Entry) -> (), -- the item's model in the view (only when it changes)
	reshow: (id: string) -> (), -- a model that arrived late replaces its stand-in
	stats: (rows: { KitCard.Row }) -> (),
	turn: (dt: number) -> (),
}

-- The inspect panel at `position`, `size` inside `frame`: a dim kicker, the item turning in
-- one ViewportFrame (dark field, cream corner brackets), its name, designation, a status line,
-- its description and the stat rows (pooled: made once, re-labelled for each item).
function KitView.inspect(frame: Frame, L: Layout, position: Vector2, size: Vector2): Inspect
	local inspectW, inspectH = size.X, size.Y
	local panel = HudTheme.rect(
		frame,
		UDim2.fromOffset(inspectW, inspectH),
		C.Track,
		HudTheme.TrackTransparency
	)
	panel.Name = "Inspect"
	panel.Position = UDim2.fromOffset(position.X, position.Y)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = C.Red
	panelStroke.Parent = panel

	local kicker = HudTheme.label(panel, { size = 13, color = C.TextDim, rich = true })
	kicker.Position = UDim2.fromOffset(14, 10)
	local viewSize = Vector2.new(inspectW - 28, L.view)
	local view, viewCamera = KitView.viewport(panel, UDim2.fromOffset(viewSize.X, viewSize.Y))
	view.Name = "Model"
	view.Position = UDim2.fromOffset(14, 34)
	view.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	view.BackgroundTransparency = 0.25
	view.Ambient = Color3.fromRGB(205, 205, 210)
	view.LightColor = Color3.fromRGB(255, 250, 240)
	view.LightDirection = Vector3.new(-1, -1.5, -0.6)
	KitView.corners(view, C.MenuSelect)

	local details = KitView.scroller(
		panel,
		Vector2.new(14, 34 + L.view + 12),
		Vector2.new(inspectW - 20, inspectH - (34 + L.view + 12) - 10),
		4
	)
	KitView.list(details, 6)
	local detailWidth = inspectW - 34
	local itemName = HudTheme.label(details, { size = L.title, font = HudTheme.Font.Headline })
	itemName.LayoutOrder = 1
	local itemSub = HudTheme.label(details, { size = L.sub + 2, color = C.TextDim })
	itemSub.LayoutOrder = 2
	local itemStatus = HudTheme.label(details, {
		size = L.stat,
		font = HudTheme.Font.Headline,
		rich = true,
	})
	itemStatus.LayoutOrder = 3
	local itemLine = HudTheme.label(details, { size = L.body, font = HudTheme.Font.Body })
	itemLine.LayoutOrder = 4
	itemLine.AutomaticSize = Enum.AutomaticSize.Y
	itemLine.Size = UDim2.fromOffset(detailWidth, 0)
	itemLine.TextWrapped = true
	local statList = Instance.new("Frame")
	statList.BackgroundTransparency = 1
	statList.Size = UDim2.fromOffset(detailWidth, 0)
	statList.AutomaticSize = Enum.AutomaticSize.Y
	statList.LayoutOrder = 5
	statList.Parent = details
	KitView.list(statList, 8)

	type StatRow = { frame: Frame, label: TextLabel, value: TextLabel, cells: { Frame } }
	local statRows: { StatRow } = {}
	local function statRow(index: number): StatRow
		local existing = statRows[index]
		if existing then
			return existing
		end
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(detailWidth, L.stat + 16)
		holder.LayoutOrder = index
		holder.Parent = statList
		local label = HudTheme.label(holder, { size = L.stat })
		local value = HudTheme.label(holder, {
			size = L.stat,
			color = C.TextDim,
			align = Enum.TextXAlignment.Right,
		})
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.fromScale(1, 0)
		local strip = Instance.new("Frame")
		strip.BackgroundTransparency = 1
		strip.Position = UDim2.fromOffset(0, L.stat + 6)
		strip.Size = UDim2.new(1, 0, 0, 8)
		strip.Parent = holder
		KitView.list(strip, 3, true)
		local cells = {}
		for cell = 1, SCREEN.Cells do
			local box = HudTheme.rect(strip, UDim2.new(1 / SCREEN.Cells, -3, 1, 0), C.White, 0.85)
			box.LayoutOrder = cell
			table.insert(cells, box)
		end
		local made: StatRow = { frame = holder, label = label, value = value, cells = cells }
		statRows[index] = made
		return made
	end

	-- The model, turning.
	local shown: Model? = nil
	local shownId: string? = nil
	local centre, distance, yaw = Vector3.zero, 5, 0
	local function showModel(id: string)
		if shown then
			shown:Destroy()
		end
		local model = Showcase.get(id)
		model.Parent = view
		shown = model
		shownId = id
		centre, distance, yaw = KitView.fit(model, viewSize, true)
		KitView.aim(viewCamera, centre, distance, yaw, KitView.ELEVATION)
	end

	return {
		panel = panel,
		kicker = kicker,
		name = itemName,
		sub = itemSub,
		status = itemStatus,
		line = itemLine,
		details = details,
		show = function(entry: Entry)
			if shownId ~= entry.id then
				showModel(entry.id)
				details.CanvasPosition = Vector2.zero
			end
		end,
		reshow = function(id: string)
			if shownId == id then
				showModel(id)
			end
		end,
		stats = function(rows: { KitCard.Row })
			for index, row in rows do
				local slot = statRow(index)
				slot.frame.Visible = true
				slot.label.Text = row.label
				slot.value.Text = row.text
				local filled = KitCard.cells(row.fraction, SCREEN.Cells)
				for cell, box in slot.cells do
					box.BackgroundColor3 = if cell <= filled then C.Yellow else C.White
					box.BackgroundTransparency = if cell <= filled then 0 else 0.85
				end
			end
			for index = #rows + 1, #statRows do
				statRows[index].frame.Visible = false
			end
		end,
		turn = function(dt: number)
			if shown then
				yaw += dt * SCREEN.SpinSpeed
				KitView.aim(viewCamera, centre, distance, yaw, KitView.ELEVATION)
			end
		end,
	}
end

-- --------------------------------------------------------------- a row
export type Look = {
	selected: boolean, -- cream fill (picked)
	focus: boolean, -- the inspected row: a 2 px yellow box
	dim: boolean, -- locked or not on the record: faded
	badge: string,
	badgeColor: Color3,
	sub: string,
}

export type Row = {
	item: TextButton,
	paint: (look: Look) -> (),
	refill: (() -> ())?, -- refills the shape when its model arrives
}

-- One row in a list: the item's flat shape on the left, its name and designation, a badge top
-- right. `selector` is the gamepad's selection box.
function KitView.row(
	section: Instance,
	index: number,
	entry: Entry,
	L: Layout,
	selector: GuiObject
): Row
	local item = Instance.new("TextButton")
	item.Name = entry.id
	item.AutoButtonColor = false
	item.Text = ""
	item.BorderSizePixel = 0
	item.Size = UDim2.new(1, -8, 0, L.row)
	item.LayoutOrder = index
	item.SelectionImageObject = selector
	item.Parent = section
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = item

	local textLeft = 12
	local shape: ViewportFrame? = nil
	local refill: (() -> ())? = nil
	if SCREEN.RowSilhouettes then
		local box, boxCamera = KitView.viewport(item, UDim2.fromOffset(L.shape.X, L.shape.Y))
		box.Name = "Shape"
		box.AnchorPoint = Vector2.new(0, 0.5)
		box.Position = UDim2.new(0, 8, 0.5, 0)
		box.Ambient = Color3.new(1, 1, 1)
		box.LightColor = Color3.new(0, 0, 0)
		KitView.fillShape(box, boxCamera, entry.id, L.shape)
		refill = function()
			KitView.fillShape(box, boxCamera, entry.id, L.shape)
		end
		shape = box
		textLeft = 8 + L.shape.X + 12
	end
	local title = HudTheme.label(item, { text = entry.title, size = L.name })
	title.Position = UDim2.fromOffset(textLeft, math.floor(L.row / 2) - L.name - 1)
	local sub = HudTheme.label(item, {
		text = entry.subtitle,
		font = HudTheme.Font.Body,
		size = L.sub,
	})
	sub.Position = UDim2.fromOffset(textLeft, math.floor(L.row / 2) + 3)
	local badge = HudTheme.label(item, {
		text = "",
		size = L.sub,
		font = HudTheme.Font.Headline,
		align = Enum.TextXAlignment.Right,
	})
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -10, 0, 8)

	return {
		item = item,
		refill = refill,
		paint = function(look: Look)
			local selected, focus, dim = look.selected, look.focus, look.dim
			item.BackgroundColor3 = if selected then C.MenuSelect else C.Track
			item.BackgroundTransparency = if selected then 0 elseif dim then 0.7 else 0.35
			outline.Color = if focus then C.Yellow else C.White
			outline.Thickness = if focus then 2 else 1
			outline.Transparency = if focus then 0 else HudTheme.OutlineTransparency
			local ink = if selected then C.MenuSelectText elseif dim then C.TextDim else C.Text
			title.TextColor3 = ink
			title.TextStrokeTransparency = if selected then 1 else 0.55
			sub.TextColor3 = if selected then C.MenuSelectText else C.TextDim
			sub.TextStrokeTransparency = if selected then 1 else 0.55
			sub.Text = look.sub
			badge.TextStrokeTransparency = if selected then 1 else 0.55
			badge.Text = look.badge
			badge.TextColor3 = look.badgeColor
			if shape then
				shape.ImageColor3 = ink
				shape.ImageTransparency = if dim then 0.45 else 0
			end
		end,
	}
end

-- A section in a list: its dim header and its rows, stacked.
function KitView.section(
	holder: Instance,
	order: number,
	headerText: string,
	showHeader: boolean
): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = holder
	KitView.list(frame, 6)
	local title = HudTheme.label(frame, { text = headerText, size = 14, color = C.TextDim })
	title.LayoutOrder = 0
	title.Visible = showHeader
	return frame
end

-- The gamepad's selection box on a row (cream, as Prototype 2's highlight).
function KitView.selector(): Frame
	local selector = Instance.new("Frame")
	selector.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.MenuSelect
	stroke.Thickness = 3
	stroke.Parent = selector
	return selector
end

return KitView
