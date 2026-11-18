--!strict
-- The Loadout menu (docs/PROGRESSION.md > Loadout; titled "Arms Room" in the match): UI only,
-- hosted by the match (LoadoutUI) and the lobby's Loadmaster (LoadmasterUI, via `options`).
-- `mount(parent, onConfirm)` builds the screen in the menu style (HudTheme: near-black red
-- field, "//" header, cream selection; layout in docs/STYLES.md section 5 > Loadout screen)
-- inside `parent` and returns a handle. Owner 2026-11-16: bigger, each item with its shape,
-- and the picked item turning in 3D beside its stats. So: lists of rows, each with a small
-- dark shape of the item (Shared.Showcase), and an inspect panel with the item turning slowly
-- in one ViewportFrame and its numbers as segmented bars (Rules/ArmsStats for guns,
-- Rules/KitCard for call-ins and grenades, read from each item's own Config row). A screen
-- smaller than Config.LoadoutScreen.Compact gets tabs and one list instead of three columns.
-- The soldier picks one primary, one sidearm, one grenade and up to Config.CallIns.Slots
-- different call-ins (click or tap to add in slot order, again to take out; hovering or a
-- gamepad's selection inspects); confirm (or Enter / gamepad Y) hands the table to
-- `onConfirm`. Whether the change is allowed is the server's call (LoadoutService.apply); the
-- host shows the answer with `handle.status`. The picks are checked with the same pure rules
-- the server uses (Rules/Loadout) so confirm greys out on a short pick.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local ArmsRoom = require(Shared:WaitForChild("ArmsRoom"))
local ArmsStats = require(Rules:WaitForChild("ArmsStats"))
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Config = require(Shared:WaitForChild("Config"))
local KeyBindings = require(Rules:WaitForChild("KeyBindings"))
local KitCard = require(Rules:WaitForChild("KitCard"))
local Loadout = require(Rules:WaitForChild("Loadout"))
local Showcase = require(Shared:WaitForChild("Showcase"))
local WeaponDefinitions = require(Shared:WaitForChild("WeaponDefinitions"))
local HudTheme = require(script.Parent.HudTheme)

local LoadoutMenu = {}

local C = HudTheme.Color
local SCREEN = Config.LoadoutScreen
local callInKeys = Config.Keys.CallIns
local ACTION_CONFIRM = "LoadoutMenuConfirm"
local ACTION_TAB = "LoadoutMenuTab"
local FOV = 30
local ELEVATION = math.rad(12) -- the inspect camera looks down this much
local MAX_FIT = 1.5 -- the screen grows with the display up to this (1440p and up)

local function keyLabel(key: Enum.KeyCode): string
	return KeyBindings.label(key.Name)
end

-- What a host may change; left out, the match's Arms Room text is used.
export type Options = {
	title: string?, -- the header, after the "//"
	hint: string?,
	confirm: string?, -- the confirm button
	-- A gun the soldier may not carry: returns the badge shown in its place (e.g. its price),
	-- or nil when it may be picked. Locked items cannot be picked and keep confirm greyed.
	locked: ((id: string) -> string?)?,
	-- The Loadmaster's EDIT (GunsmithUI): given, a gun that takes attachments gets an EDIT
	-- button; the host opens its screen with what is fitted and calls `done` with the new
	-- fitting ([slot] = option).
	edit: ((
		gunId: string,
		fitted: { [string]: string },
		done: (fitted: { [string]: string }) -> ()
	) -> ())?,
}

export type Handle = {
	frame: Frame,
	set: (loadout: Loadout.Loadout) -> (),
	status: (text: string, good: boolean?) -> (),
	refresh: () -> (), -- repaint after what `locked` answers has changed
	destroy: () -> (),
}

type Kind = "gun" | "grenade" | "callIn"

type Entry = {
	id: string,
	kind: Kind,
	section: string, -- "PRIMARY"
	title: string, -- "SERVICE RIFLE"
	subtitle: string, -- "M16A4"
	description: string,
}

-- Every size on the screen, in design pixels (the frame's UIScale fits it to the display).
type Layout = {
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

local WIDE: Layout = {
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
}

local COMPACT: Layout = {
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
}

local function weaponEntry(id: string, section: string): Entry
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

local function grenadeEntry(id: string): Entry
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

local function callInEntry(id: string): Entry
	local row = CallInDefinitions.get(id)
	return {
		id = id,
		kind = "callIn",
		section = "CALL-IN",
		title = string.upper(if row then row.Name else id),
		subtitle = if row then row.Codename else "",
		description = if row then row.Description else "",
	}
end

-- --------------------------------------------------------------- the numbers
local function gunStats(id: string): ArmsStats.Stats
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

local function grenadeBlock(id: string): { [string]: any }
	return (Config.Grenade :: any)[WeaponDefinitions.grenade(id).ConfigKey] or {}
end

local function callInBlock(id: string): { [string]: any }
	local row = CallInDefinitions.get(id)
	return if row then (Config.CallIns :: any)[row.ConfigKey] or {} else {}
end

-- --------------------------------------------------------------- 3D views
-- The camera distance that keeps `model` in a `view`-shaped ViewportFrame, seen side on from
-- `yaw` (or from any side when it turns), and the point to look at.
local function fit(model: Model, view: Vector2, turning: boolean): (Vector3, number, number)
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

local function aim(
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

local function viewport(parent: Instance, size: UDim2): (ViewportFrame, Camera)
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
local function fillShape(frame: ViewportFrame, camera: Camera, id: string, size: Vector2)
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
	local centre, distance, yaw = fit(model, size, false)
	aim(camera, centre, distance, yaw, 0)
end

-- Four L-shaped corner marks round a box (Prototype 2's framing, as the results screen's).
local function corners(parent: GuiObject, color: Color3)
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
			bar.Parent = parent
		end
	end
end

local function list(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	if horizontal then
		layout.FillDirection = Enum.FillDirection.Horizontal
	end
	layout.Parent = parent
	return layout
end

local function scroller(
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

function LoadoutMenu.mount(
	parent: Instance,
	onConfirm: (loadout: Loadout.Loadout) -> (),
	options: Options?
): Handle
	local opts: Options = options or {}
	local catalog = ArmsRoom.catalog()
	local pick = Loadout.default(catalog)
	pick.attachments = {}
	local connections: { RBXScriptConnection } = {}

	-- Every gun's, grenade's and call-in's numbers, for the bars' "against the rest".
	local allGuns: { ArmsStats.Stats } = {}
	local allNoise: { number } = {}
	for _, ids in { catalog.primaries, catalog.secondaries } do
		for _, id in ids do
			table.insert(allGuns, gunStats(id))
			table.insert(allNoise, WeaponDefinitions.get(id).Noise)
		end
	end
	local allGrenades: { { [string]: any } } = {}
	for _, id in catalog.grenades do
		table.insert(allGrenades, grenadeBlock(id))
	end
	local allCallIns: { { [string]: any } } = {}
	for _, id in catalog.callIns do
		table.insert(allCallIns, callInBlock(id))
	end

	-- --------------------------------------------------------------- size and layout
	local screen: ScreenGui? = if parent:IsA("ScreenGui")
		then parent
		else parent:FindFirstAncestorOfClass("ScreenGui")
	local function available(): Vector2
		local camera = Workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
		return size - Vector2.new(0, GuiService:GetGuiInset().Y)
	end
	local room = available()
	local L: Layout = if room.X < SCREEN.Compact.X or room.Y < SCREEN.Compact.Y
		then COMPACT
		else WIDE
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
		local outerScale = screen and screen:FindFirstChildOfClass("UIScale")
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
		text = `//{opts.title or "ARMS ROOM"}`,
		font = HudTheme.Font.Headline,
		size = L.header,
		color = C.Text,
	})
	header.Position = UDim2.fromOffset(L.pad, if L.compact then 10 else 18)
	local hintText = opts.hint
		or `[{keyLabel(Config.Keys.Loadout)}] CLOSE   ·   CHANGES AT INSERT, READY-UP, OR AT THE LZ WHEN CALM`
	if UserInputService.GamepadEnabled then
		hintText ..= "   ·   [A] PICK   [Y] CONFIRM   [B] BACK"
	end
	local hint = HudTheme.label(frame, { text = hintText, size = 13, color = C.TextDim })
	hint.Position = UDim2.fromOffset(L.pad + 2, 62)
	hint.Visible = not L.compact and not touch

	-- --------------------------------------------------------------- the inspect panel
	local inspectX = if L.compact
		then L.pad + L.column + 16
		else L.pad + 3 * L.column + 2 * L.gap + 24
	local inspectY = if L.compact then 52 else L.bodyTop
	local inspectW = W - L.pad - inspectX
	local inspectH = H - L.footer - inspectY
	local inspect = HudTheme.rect(
		frame,
		UDim2.fromOffset(inspectW, inspectH),
		C.Track,
		HudTheme.TrackTransparency
	)
	inspect.Name = "Inspect"
	inspect.Position = UDim2.fromOffset(inspectX, inspectY)
	local inspectStroke = Instance.new("UIStroke")
	inspectStroke.Color = C.Red
	inspectStroke.Parent = inspect

	local kicker = HudTheme.label(inspect, { size = 13, color = C.TextDim, rich = true })
	kicker.Position = UDim2.fromOffset(14, 10)
	local viewSize = Vector2.new(inspectW - 28, L.view)
	local view, viewCamera = viewport(inspect, UDim2.fromOffset(viewSize.X, viewSize.Y))
	view.Name = "Model"
	view.Position = UDim2.fromOffset(14, 34)
	view.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	view.BackgroundTransparency = 0.25
	view.Ambient = Color3.fromRGB(205, 205, 210)
	view.LightColor = Color3.fromRGB(255, 250, 240)
	view.LightDirection = Vector3.new(-1, -1.5, -0.6)
	corners(view, C.MenuSelect)

	local details = scroller(
		inspect,
		Vector2.new(14, 34 + L.view + 12),
		Vector2.new(inspectW - 20, inspectH - (34 + L.view + 12) - 10),
		4
	)
	list(details, 6)
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
	list(statList, 8)

	-- Stat rows are pooled: made once, re-labelled for each item.
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
		list(strip, 3, true)
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
	local function showStats(rows: { KitCard.Row })
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
	end

	-- --------------------------------------------------------------- footer
	local summaryTitle =
		HudTheme.label(frame, { text = "YOUR LOADOUT", size = 13, color = C.TextDim })
	summaryTitle.Position = UDim2.fromOffset(L.pad, H - L.footer + 22)
	local summary = HudTheme.label(frame, { size = L.stat, rich = true })
	summary.Position = UDim2.fromOffset(L.pad, H - L.footer + 42)
	summaryTitle.Visible = not L.compact
	summary.Visible = not L.compact

	local statusLabel = HudTheme.label(frame, {
		text = "",
		size = L.stat - 1,
		color = C.TextDim,
		align = Enum.TextXAlignment.Right,
	})
	statusLabel.AnchorPoint = Vector2.new(1, 0.5)
	if L.compact then
		statusLabel.Position = UDim2.new(1, -(L.pad + L.confirm.X + 16), 1, -(L.footer / 2))
	else
		statusLabel.AnchorPoint = Vector2.new(1, 1)
		statusLabel.Position = UDim2.new(1, -L.pad, 1, -(20 + L.confirm.Y + 8))
	end

	local deploy = Instance.new("TextButton")
	deploy.Name = "Confirm"
	deploy.AnchorPoint = Vector2.new(1, 1)
	deploy.Position = UDim2.new(1, -L.pad, 1, -(L.footer - L.confirm.Y) / 2)
	deploy.Size = UDim2.fromOffset(L.confirm.X, L.confirm.Y)
	deploy.BackgroundColor3 = C.MenuSelect
	deploy.BorderSizePixel = 0
	deploy.AutoButtonColor = false
	deploy.Text = opts.confirm or "DEPLOY LOADOUT"
	deploy.TextColor3 = C.MenuSelectText
	deploy.TextSize = 20
	deploy.Font = HudTheme.Font.Headline
	deploy.Parent = frame

	-- --------------------------------------------------------------- state
	local painters: { () -> () } = {}
	local inspected: Entry? = nil
	local rowsById: { [string]: TextButton } = {}
	local shapes: { [string]: () -> () } = {} -- refills a row's shape when its model arrives

	local function isLocked(id: string): string?
		local locked = opts.locked
		return if locked then locked(id) else nil
	end

	local function isPicked(entry: Entry): (boolean, number?)
		if entry.kind == "callIn" then
			local slot = table.find(pick.callIns, entry.id)
			return slot ~= nil, slot
		end
		return pick.primary == entry.id or pick.secondary == entry.id or pick.grenade == entry.id,
			nil
	end

	-- The inspected item's model, turning.
	local shown: Model? = nil
	local centre, distance, yaw = Vector3.zero, 5, 0
	local function showModel(id: string)
		if shown then
			shown:Destroy()
		end
		local model = Showcase.get(id)
		model.Parent = view
		shown = model
		centre, distance, yaw = fit(model, viewSize, true)
		aim(viewCamera, centre, distance, yaw, ELEVATION)
	end

	local function paintInspect()
		local entry = inspected
		if not entry then
			return
		end
		local picked, slot = isPicked(entry)
		local lock = isLocked(entry.id)
		local where = entry.section
		if picked then
			local key = slot and callInKeys[slot]
			where ..= if key
				then `  ·  {HudTheme.tint(`ON KEY {keyLabel(key)}`, C.Yellow)}`
				else `  ·  {HudTheme.tint("IN YOUR LOADOUT", C.Yellow)}`
		end
		kicker.Text = where
		itemName.Text = entry.title
		itemSub.Text = entry.subtitle
		if lock then
			itemStatus.Text =
				`{HudTheme.tint("NOT ON YOUR RECORD", C.RedLight)}  {HudTheme.tint(lock, C.Yellow)}`
		elseif opts.locked then
			itemStatus.Text = HudTheme.tint("ON YOUR RECORD", C.Yellow)
		else
			itemStatus.Text = ""
		end
		itemStatus.Visible = itemStatus.Text ~= ""
		itemLine.Text = entry.description
		if entry.kind == "gun" then
			local rows: { KitCard.Row } = ArmsStats.rows(gunStats(entry.id), allGuns)
			local fitted = pick.attachments and pick.attachments[entry.id]
			local def = WeaponDefinitions.get(entry.id)
			table.insert(
				rows,
				KitCard.stealth(
					WeaponDefinitions.shotNoise(def, fitted and fitted.Barrel),
					allNoise
				)
			)
			showStats(rows)
		elseif entry.kind == "grenade" then
			showStats(KitCard.grenade(grenadeBlock(entry.id), allGrenades))
		else
			showStats(KitCard.callIn(callInBlock(entry.id), allCallIns))
		end
	end

	local function setInspected(entry: Entry)
		local before = inspected
		inspected = entry
		if not before or before.id ~= entry.id then
			showModel(entry.id)
			details.CanvasPosition = Vector2.zero
		end
		for _, paint in painters do
			paint()
		end
		paintInspect()
	end

	local function repaint()
		for _, paint in painters do
			paint()
		end
		paintInspect()
		local ok = Loadout.validate(pick, catalog)
			and not isLocked(pick.primary)
			and not isLocked(pick.secondary)
			and not isLocked(pick.grenade)
		for _, id in pick.callIns do
			ok = ok and not isLocked(id)
		end
		deploy.Active = ok
		deploy.BackgroundTransparency = if ok then 0 else 0.5
		-- The footer's one line: what the soldier is taking.
		local parts = {
			string.upper(WeaponDefinitions.get(pick.primary).Name),
			string.upper(WeaponDefinitions.get(pick.secondary).Name),
			string.upper(WeaponDefinitions.grenade(pick.grenade).Name),
		}
		for slot, id in pick.callIns do
			local row = CallInDefinitions.get(id)
			local key = callInKeys[slot]
			table.insert(
				parts,
				`{if key then HudTheme.tint(keyLabel(key), C.Yellow) .. " " else ""}{string.upper(
					if row then row.Name else id
				)}`
			)
		end
		summary.Text = table.concat(parts, "   ·   ")
	end

	-- The selection box a gamepad shows on a row (cream, as Prototype 2's highlight).
	local selector = Instance.new("Frame")
	selector.BackgroundTransparency = 1
	local selectorStroke = Instance.new("UIStroke")
	selectorStroke.Color = C.MenuSelect
	selectorStroke.Thickness = 3
	selectorStroke.Parent = selector

	-- --------------------------------------------------------------- lists
	local function addItem(section: Frame, index: number, entry: Entry, onPick: () -> ())
		local item = Instance.new("TextButton")
		item.Name = entry.id
		item.AutoButtonColor = false
		item.Text = ""
		item.BorderSizePixel = 0
		item.Size = UDim2.new(1, -8, 0, L.row)
		item.LayoutOrder = index
		item.SelectionImageObject = selector
		item.Parent = section
		rowsById[entry.id] = item
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Parent = item

		local textLeft = 12
		local shape: ViewportFrame? = nil
		if SCREEN.RowSilhouettes then
			local box, boxCamera = viewport(item, UDim2.fromOffset(L.shape.X, L.shape.Y))
			box.Name = "Shape"
			box.AnchorPoint = Vector2.new(0, 0.5)
			box.Position = UDim2.new(0, 8, 0.5, 0)
			box.Ambient = Color3.new(1, 1, 1)
			box.LightColor = Color3.new(0, 0, 0)
			fillShape(box, boxCamera, entry.id, L.shape)
			shapes[entry.id] = function()
				fillShape(box, boxCamera, entry.id, L.shape)
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

		-- EDIT: what is fitted to this gun (the Loadmaster only).
		local editGun = opts.edit
		local offers = catalog.attachments and catalog.attachments[entry.id]
		if entry.kind == "gun" and editGun and offers then
			local editButton = Instance.new("TextButton")
			editButton.Name = "Edit"
			editButton.AutoButtonColor = false
			editButton.AnchorPoint = Vector2.new(1, 1)
			editButton.Position = UDim2.new(1, -8, 1, -8)
			editButton.Size =
				UDim2.fromOffset(if L.compact then 64 else 52, if L.compact then 30 else 22)
			editButton.BackgroundColor3 = C.Red
			editButton.BorderSizePixel = 0
			editButton.Font = HudTheme.Font.Line
			editButton.TextSize = L.sub - 1
			editButton.TextColor3 = C.Text
			editButton.Text = "EDIT"
			editButton.SelectionImageObject = selector
			editButton.Parent = item
			editButton.Activated:Connect(function()
				local attachments = pick.attachments or {}
				pick.attachments = attachments
				editGun(entry.id, table.clone(attachments[entry.id] or {}), function(fitted)
					attachments[entry.id] = if next(fitted) then fitted else nil
					repaint()
				end)
			end)
		end

		item.MouseEnter:Connect(function()
			setInspected(entry)
		end)
		item.SelectionGained:Connect(function()
			setInspected(entry)
		end)
		item.Activated:Connect(function()
			if not isLocked(entry.id) then
				onPick()
			end
			setInspected(entry)
			repaint()
		end)

		table.insert(painters, function()
			local selected, slot = isPicked(entry)
			local lock = isLocked(entry.id)
			local focus = inspected ~= nil and inspected.id == entry.id
			item.BackgroundColor3 = if selected then C.MenuSelect else C.Track
			item.BackgroundTransparency = if selected then 0 elseif lock then 0.7 else 0.35
			outline.Color = if focus then C.Yellow else C.White
			outline.Thickness = if focus then 2 else 1
			outline.Transparency = if focus then 0 else HudTheme.OutlineTransparency
			local ink = if selected then C.MenuSelectText elseif lock then C.TextDim else C.Text
			title.TextColor3 = ink
			title.TextStrokeTransparency = if selected then 1 else 0.55
			sub.TextColor3 = if selected then C.MenuSelectText else C.TextDim
			sub.TextStrokeTransparency = if selected then 1 else 0.55
			badge.TextStrokeTransparency = if selected then 1 else 0.55
			if shape then
				shape.ImageColor3 = ink
				shape.ImageTransparency = if lock then 0.45 else 0
			end
			if lock then
				badge.Text = lock
				badge.TextColor3 = C.Yellow
				sub.Text = entry.subtitle
			else
				local key = slot and callInKeys[slot]
				badge.Text = if key then `[{keyLabel(key)}]` else ""
				badge.TextColor3 = if selected then C.MenuSelectText else C.Yellow
				-- "+SUP" for each attachment fitted to this gun.
				local fitted: { [string]: string } = pick.attachments and pick.attachments[entry.id]
					or {}
				local marks = ""
				for _, option in fitted do
					local row = Config.Attachments.Options[option]
					marks ..= if row then ` +{string.upper(string.sub(row.Name, 1, 3))}` else ""
				end
				sub.Text = entry.subtitle .. marks
			end
		end)
	end

	-- A section: its header and its rows, stacked in a list.
	local function section(holder: Instance, order: number, headerText: string): Frame
		local frame_ = Instance.new("Frame")
		frame_.BackgroundTransparency = 1
		frame_.Size = UDim2.fromScale(1, 0)
		frame_.AutomaticSize = Enum.AutomaticSize.Y
		frame_.LayoutOrder = order
		frame_.Parent = holder
		list(frame_, 6)
		local title = HudTheme.label(frame_, { text = headerText, size = 14, color = C.TextDim })
		title.LayoutOrder = 0
		title.Visible = not L.compact
		return frame_
	end

	local bodyH = H - L.footer - L.bodyTop
	local holders: { ScrollingFrame } = {}
	if L.compact then
		table.insert(
			holders,
			scroller(frame, Vector2.new(L.pad, L.bodyTop), Vector2.new(L.column, bodyH), 6)
		)
	else
		for index = 1, 3 do
			table.insert(
				holders,
				scroller(
					frame,
					Vector2.new(L.pad + (index - 1) * (L.column + L.gap), L.bodyTop),
					Vector2.new(L.column + 8, bodyH),
					4
				)
			)
		end
	end
	for _, holder in holders do
		list(holder, 18)
	end
	local function holder(index: number): ScrollingFrame
		return holders[math.min(index, #holders)]
	end

	local callInHeader = `CALL-INS  (KEYS {keyLabel(callInKeys[1])}-{keyLabel(
		callInKeys[catalog.slots] or callInKeys[#callInKeys]
	)})`
	local primaries = section(holder(1), 1, "PRIMARY")
	local sidearms = section(holder(2), 2, "SIDEARM")
	local grenades = section(holder(2), 3, "GRENADE")
	local callIns = section(holder(3), 4, callInHeader)
	local sections = { primaries, sidearms, grenades, callIns }

	local entries: { [string]: Entry } = {}
	for index, id in catalog.primaries do
		local entry = weaponEntry(id, "PRIMARY")
		entries[id] = entry
		addItem(primaries, index, entry, function()
			pick.primary = id
		end)
	end
	for index, id in catalog.secondaries do
		local entry = weaponEntry(id, "SIDEARM")
		entries[id] = entry
		addItem(sidearms, index, entry, function()
			pick.secondary = id
		end)
	end
	for index, id in catalog.grenades do
		local entry = grenadeEntry(id)
		entries[id] = entry
		addItem(grenades, index, entry, function()
			pick.grenade = id
		end)
	end
	for index, id in catalog.callIns do
		local entry = callInEntry(id)
		entries[id] = entry
		addItem(callIns, index, entry, function()
			local slot = table.find(pick.callIns, id)
			if slot then
				table.remove(pick.callIns, slot)
			elseif #pick.callIns < catalog.slots then
				table.insert(pick.callIns, id)
			end
		end)
	end

	-- Compact: one list at a time behind four tabs (gamepad shoulders step through them).
	local tab = 1
	local tabButtons: { TextButton } = {}
	local function showTab(index: number)
		tab = index
		for i, sectionFrame in sections do
			sectionFrame.Visible = i == index
		end
		holders[1].CanvasPosition = Vector2.zero
		for i, button in tabButtons do
			local on = i == index
			button.BackgroundColor3 = if on then C.MenuSelect else C.Track
			button.BackgroundTransparency = if on then 0 else 0.35
			button.TextColor3 = if on then C.MenuSelectText else C.Text
		end
	end
	if L.compact then
		local labels = { "PRIMARY", "SIDEARM", "GRENADE", "CALL-INS" }
		local width = math.floor((L.column - 3 * 6) / 4)
		for index, text in labels do
			local button = Instance.new("TextButton")
			button.AutoButtonColor = false
			button.BorderSizePixel = 0
			button.Position = UDim2.fromOffset(L.pad + (index - 1) * (width + 6), 52)
			button.Size = UDim2.fromOffset(width, 50)
			button.Font = HudTheme.Font.Line
			button.TextSize = 15
			button.Text = text
			button.SelectionImageObject = selector
			button.Parent = frame
			button.Activated:Connect(function()
				showTab(index)
			end)
			table.insert(tabButtons, button)
		end
		showTab(1)
		ContextActionService:BindAction(ACTION_TAB, function(_, state, input)
			if state == Enum.UserInputState.Begin then
				local step = if input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1
				showTab((tab - 1 + step) % #sections + 1)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	end

	-- --------------------------------------------------------------- confirm
	local function confirm()
		if deploy.Active then
			onConfirm(Loadout.copy(pick))
		end
	end
	deploy.Activated:Connect(confirm)
	ContextActionService:BindAction(ACTION_CONFIRM, function(_, state)
		if state == Enum.UserInputState.Begin and not parent:FindFirstChild("Gunsmith") then
			confirm()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonY)

	-- The inspected model turns while the screen shows (not under the EDIT screen, which has
	-- its own turning gun); the one ViewportFrame redraws only then.
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			if not shown or not frame.Visible or parent:FindFirstChild("Gunsmith") then
				return
			end
			yaw += dt * SCREEN.SpinSpeed
			aim(viewCamera, centre, distance, yaw, ELEVATION)
		end)
	)
	-- Models that load after the screen opened replace their stand-ins.
	local arrived = Showcase.onArrived(function(id)
		local refill = shapes[id]
		if refill then
			refill()
		end
		local entry = inspected
		if entry and entry.id == id then
			showModel(id)
		end
	end)
	if arrived then
		table.insert(connections, arrived)
	end

	repaint()
	setInspected(entries[pick.primary] or weaponEntry(pick.primary, "PRIMARY"))
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = rowsById[pick.primary]
	end

	local handle: Handle = {
		frame = frame,
		set = function(loadout: Loadout.Loadout)
			pick = Loadout.copy(loadout)
			pick.attachments = pick.attachments or {}
			repaint()
			local entry = entries[pick.primary]
			if entry then
				inspected = nil
				setInspected(entry)
				if UserInputService.GamepadEnabled then
					GuiService.SelectedObject = rowsById[pick.primary]
				end
			end
		end,
		refresh = repaint,
		status = function(text: string, good: boolean?)
			statusLabel.Text = text
			statusLabel.TextColor3 = if good == true
				then C.Yellow
				elseif good == false then C.RedLight
				else C.TextDim
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			ContextActionService:UnbindAction(ACTION_CONFIRM)
			ContextActionService:UnbindAction(ACTION_TAB)
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(frame) then
				GuiService.SelectedObject = nil
			end
			selector:Destroy()
			frame:Destroy()
		end,
	}
	return handle
end

return LoadoutMenu
