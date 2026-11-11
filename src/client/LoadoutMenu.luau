--!strict
-- The Loadout menu (docs/PROGRESSION.md > Loadout; titled "Arms Room" in the match): UI only,
-- hosted by the match (LoadoutUI) and the lobby's Loadmaster (LoadmasterUI, via `options`).
-- `mount(parent, onConfirm)` builds the panel in the menu style (HudTheme: near-black red
-- field, "//" header, cream selection) inside `parent` and returns a handle. The soldier
-- picks one primary, one sidearm, one grenade and up to Config.CallIns.Slots different
-- call-ins (click to add in slot order, click again to take out); DEPLOY hands the table to
-- `onConfirm`. Whether the change is allowed is the server's call (LoadoutService.apply);
-- the host (LoadoutUI) shows the answer with `handle.status`. The picks are checked with the
-- same pure rules the server uses (Rules/Loadout) so DEPLOY greys out on a short pick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmsRoom = require(Shared:WaitForChild("ArmsRoom"))
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Config = require(Shared:WaitForChild("Config"))
local KeyBindings = require(Shared:WaitForChild("Rules"):WaitForChild("KeyBindings"))
local Loadout = require(Shared:WaitForChild("Rules"):WaitForChild("Loadout"))
local WeaponDefinitions = require(Shared:WaitForChild("WeaponDefinitions"))
local HudTheme = require(script.Parent.HudTheme)

local LoadoutMenu = {}

local callInKeys = Config.Keys.CallIns
local function keyLabel(key: Enum.KeyCode): string
	return KeyBindings.label(key.Name)
end

local C = HudTheme.Color
local WIDTH = 760

local COLUMN = 230
local ROW = 30

-- What a host may change; left out, the match's Arms Room text is used.
export type Options = {
	title: string?, -- the header, after the "//"
	hint: string?,
	confirm: string?, -- the confirm button
	-- A gun the soldier may not carry: returns the badge shown in its place (e.g. its price),
	-- or nil when it may be picked. Locked items cannot be picked and keep confirm greyed.
	locked: ((id: string) -> string?)?,
}

export type Handle = {
	frame: Frame,
	set: (loadout: Loadout.Loadout) -> (),
	status: (text: string, good: boolean?) -> (),
	refresh: () -> (), -- repaint after what `locked` answers has changed
	destroy: () -> (),
}

type Entry = {
	id: string,
	title: string, -- "SERVICE RIFLE"
	subtitle: string, -- "M16A4"
	description: string,
}

local function weaponEntry(id: string): Entry
	local row = WeaponDefinitions.get(id)
	return {
		id = id,
		title = string.upper(row.Name),
		subtitle = row.Designation,
		description = row.Description,
	}
end

local function grenadeEntry(id: string): Entry
	local row = WeaponDefinitions.grenade(id)
	return {
		id = id,
		title = string.upper(row.Name),
		subtitle = row.Designation,
		description = row.Description,
	}
end

local function callInEntry(id: string): Entry
	local row = CallInDefinitions.get(id)
	return {
		id = id,
		title = string.upper(if row then row.Name else id),
		subtitle = if row then row.Codename else "",
		description = if row then row.Description else "",
	}
end

local function button(parent: Instance, y: number, width: number): TextButton
	local item = Instance.new("TextButton")
	item.AutoButtonColor = false
	item.Size = UDim2.fromOffset(width, ROW - 4)
	item.Position = UDim2.fromOffset(0, y)
	item.BorderSizePixel = 0
	item.Text = ""
	item.Parent = parent
	return item
end

-- A column: a header and a list of buttons; `paint(button, entry)` restyles one.
local function column(parent: Instance, x: number, y: number, header: string): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(COLUMN, 300)
	frame.Parent = parent
	HudTheme.label(frame, { text = header, size = 13, color = C.TextDim })
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
	-- Tall enough for the longest list (the call-ins grow with the roster).
	local rows =
		math.max(#catalog.primaries, #catalog.callIns, #catalog.secondaries + #catalog.grenades + 2)
	local height = 86 + 22 + rows * ROW + 110

	local frame = HudTheme.rect(parent, UDim2.fromOffset(WIDTH, height), C.MenuBack, 0.08)
	frame.Name = "ArmsRoom"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Red
	stroke.Thickness = 1
	stroke.Parent = frame

	local header = HudTheme.label(frame, {
		text = `//{opts.title or "ARMS ROOM"}`,
		font = HudTheme.Font.Headline,
		size = 30,
		color = C.Text,
	})
	header.Position = UDim2.fromOffset(24, 16)
	local hint = HudTheme.label(frame, {
		text = opts.hint
			or `[{keyLabel(Config.Keys.Loadout)}] CLOSE   ·   CHANGES AT INSERT, READY-UP, OR AT THE LZ WHEN CALM`,
		size = 12,
		color = C.TextDim,
	})
	hint.Position = UDim2.fromOffset(26, 54)

	local describe = HudTheme.label(frame, { text = "", size = 14, color = C.Text })
	describe.AutomaticSize = Enum.AutomaticSize.Y
	describe.Size = UDim2.fromOffset(WIDTH - 300, 0)
	describe.TextWrapped = true
	describe.Position = UDim2.fromOffset(24, height - 72)

	local statusLabel = HudTheme.label(frame, { text = "", size = 14, color = C.TextDim })
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -24, 1, -96)

	local deploy = Instance.new("TextButton")
	deploy.AnchorPoint = Vector2.new(1, 1)
	deploy.Position = UDim2.new(1, -24, 1, -20)
	deploy.Size = UDim2.fromOffset(220, 44)
	deploy.BackgroundColor3 = C.MenuSelect
	deploy.BorderSizePixel = 0
	deploy.Text = opts.confirm or "DEPLOY LOADOUT"
	deploy.TextColor3 = C.MenuSelectText
	deploy.TextSize = 18
	deploy.Font = HudTheme.Font.Headline
	deploy.Parent = frame

	-- Every button with how to repaint it from the current pick.
	local painters: { () -> () } = {}

	local function paintItem(item: TextButton, entry: Entry, selected: boolean, badge: string?)
		item.BackgroundColor3 = if selected then C.MenuSelect else C.Track
		item.BackgroundTransparency = if selected then 0 else 0.35
		local title = item:FindFirstChild("Title") :: TextLabel?
		local sub = item:FindFirstChild("Sub") :: TextLabel?
		if title and sub then
			local text = if selected then C.MenuSelectText else C.Text
			title.Text = if badge then `{badge}  {entry.title}` else entry.title
			title.TextColor3 = text
			title.TextStrokeTransparency = if selected then 1 else 0.55
			sub.TextColor3 = if selected then C.MenuSelectText else C.TextDim
			sub.TextStrokeTransparency = if selected then 1 else 0.55
		end
	end

	local function isLocked(id: string): string?
		local locked = opts.locked
		return if locked then locked(id) else nil
	end

	local function repaint()
		for _, paint in painters do
			paint()
		end
		local ok = Loadout.validate(pick, catalog)
			and not isLocked(pick.primary)
			and not isLocked(pick.secondary)
			and not isLocked(pick.grenade)
		for _, id in pick.callIns do
			ok = ok and not isLocked(id)
		end
		deploy.Active = ok
		deploy.BackgroundTransparency = if ok then 0 else 0.5
	end

	local function addItem(
		parentColumn: Frame,
		index: number,
		entry: Entry,
		isSelected: () -> (boolean, string?),
		onPick: () -> ()
	)
		local item = button(parentColumn, 22 + (index - 1) * ROW, COLUMN)
		local title = HudTheme.label(item, { text = entry.title, size = 14 })
		title.Name = "Title"
		title.Position = UDim2.fromOffset(10, 5)
		local sub = HudTheme.label(item, {
			text = entry.subtitle,
			font = HudTheme.Font.Body,
			size = 11,
			align = Enum.TextXAlignment.Right,
		})
		sub.Name = "Sub"
		sub.AnchorPoint = Vector2.new(1, 0)
		sub.Position = UDim2.new(1, -10, 0, 7)
		local function describeIt()
			local lock = isLocked(entry.id)
			describe.Text = if lock
				then `{entry.title}  ·  NOT ON YOUR RECORD ({lock}): buy it at the Quartermaster`
				else `{entry.title}  ·  {entry.description}`
		end
		item.MouseEnter:Connect(describeIt)
		item.Activated:Connect(function()
			if not isLocked(entry.id) then
				onPick()
			end
			describeIt()
			repaint()
		end)
		table.insert(painters, function()
			local selected, badge = isSelected()
			local lock = isLocked(entry.id)
			paintItem(item, entry, selected, badge)
			if lock then
				item.BackgroundTransparency = 0.7
				sub.Text = lock
				sub.TextColor3 = C.Yellow
			else
				sub.Text = entry.subtitle
			end
		end)
	end

	local top = 86
	local primaries = column(frame, 24, top, "PRIMARY")
	for index, id in catalog.primaries do
		addItem(primaries, index, weaponEntry(id), function()
			return pick.primary == id, nil
		end, function()
			pick.primary = id
		end)
	end

	local sidearms = column(frame, 24 + COLUMN + 16, top, "SIDEARM")
	for index, id in catalog.secondaries do
		addItem(sidearms, index, weaponEntry(id), function()
			return pick.secondary == id, nil
		end, function()
			pick.secondary = id
		end)
	end
	local grenadeTop = top + 22 + #catalog.secondaries * ROW + 20
	local grenades = column(frame, 24 + COLUMN + 16, grenadeTop, "GRENADE")
	for index, id in catalog.grenades do
		addItem(grenades, index, grenadeEntry(id), function()
			return pick.grenade == id, nil
		end, function()
			pick.grenade = id
		end)
	end

	local callIns = column(
		frame,
		24 + 2 * (COLUMN + 16),
		top,
		`CALL-INS (KEYS {keyLabel(callInKeys[1])}-{keyLabel(
			callInKeys[catalog.slots] or callInKeys[#callInKeys]
		)})`
	)
	for index, id in catalog.callIns do
		addItem(callIns, index, callInEntry(id), function()
			local slot = table.find(pick.callIns, id)
			local key = slot and callInKeys[slot]
			return slot ~= nil, if key then `[{keyLabel(key)}]` else nil
		end, function()
			local slot = table.find(pick.callIns, id)
			if slot then
				table.remove(pick.callIns, slot)
			elseif #pick.callIns < catalog.slots then
				table.insert(pick.callIns, id)
			end
		end)
	end

	deploy.Activated:Connect(function()
		if deploy.Active then
			onConfirm({
				primary = pick.primary,
				secondary = pick.secondary,
				grenade = pick.grenade,
				callIns = table.clone(pick.callIns),
			})
		end
	end)

	repaint()

	local handle: Handle = {
		frame = frame,
		set = function(loadout: Loadout.Loadout)
			pick = {
				primary = loadout.primary,
				secondary = loadout.secondary,
				grenade = loadout.grenade,
				callIns = table.clone(loadout.callIns),
			}
			repaint()
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
			frame:Destroy()
		end,
	}
	return handle
end

return LoadoutMenu
