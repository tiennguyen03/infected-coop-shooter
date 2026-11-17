--!strict
-- The Carrier's desk screens (owner 2026-11-17: "any NPC interaction UI should be using the
-- Prototype 2 UI... the same as the Loadmaster"; docs/STYLES.md section 5 > The desk screens).
-- Choice 1 at a desk that hands out kit opens this: the Loadout screen's frame, rows and
-- inspect panel (KitView) with what the desk sells (KitPrices: each row's own `Desk` or
-- Config.Lobby.Sellers): the Quartermaster's guns and grenades, the Call-ins sergeant's
-- call-ins, the motor sergeant's vehicles. Their line sits under the header in their own
-- voice (LobbyDesks `talk`: openLine, then bought / short / refused). Hover or a gamepad's
-- selection looks at an item, click picks it (cream), BUY (or Enter / gamepad Y) buys what is
-- looked at; the wording comes from Rules/DeskOffer. The server decides every buy
-- (RecordService), exactly as the rack and the old panel did; the screen repaints when the
-- record changes (RecordClient). Back, Backspace or gamepad B steps back to the talk.
-- Config.Lobby.DeskScreen.Enabled = false: the hosts use their old views.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local CallInDefinitions = require(ReplicatedStorage.Shared.CallInDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local DeskOffer = require(ReplicatedStorage.Shared.Rules.DeskOffer)
local KitPrices = require(ReplicatedStorage.Shared.KitPrices)
local Showcase = require(ReplicatedStorage.Shared.Showcase)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)
local HoldStill = require(script.Parent.HoldStill)
local HudTheme = require(script.Parent.HudTheme)
local KitView = require(script.Parent.KitView)
local RecordClient = require(script.Parent.RecordClient)

local DeskScreen = {}

local C = HudTheme.Color
local ACTION_BACK = "DeskScreenBack"
local ACTION_BUY = "DeskScreenBuy"
local WIDE_ONE_COLUMN = 400 -- a desk with one kind of kit gets one wider list

type Entry = KitView.Entry

local gui = HudTheme.gui("DeskScreen", 8)

-- The open screen: what closes it and what repaints it.
type Open = {
	desk: LobbyDesks.Desk,
	close: (stepBack: boolean) -> (), -- stepBack: hand back to the talk (onClose)
	repaint: () -> (),
	answer: (reason: string?) -> (),
}
local current: Open? = nil

-- The catalog's ids in the Loadout's columns, each kept to what this desk sells.
local function sectionsFor(deskId: string): { DeskOffer.Section }
	local catalog = ArmsRoom.catalog()
	local sold = KitPrices.soldAt(deskId)
	-- Call-ins that are all vehicles (a Config row with a `Vehicle` block) say so.
	local vehicles = #sold > 0
	for _, id in sold do
		local row = CallInDefinitions.get(id)
		local tuning = row and (Config.CallIns :: any)[row.ConfigKey]
		vehicles = vehicles and tuning ~= nil and tuning.Vehicle ~= nil
	end
	return {
		{ title = "PRIMARY", ids = KitPrices.only(deskId, catalog.primaries), column = 1 },
		{ title = "SIDEARM", ids = KitPrices.only(deskId, catalog.secondaries), column = 2 },
		{ title = "GRENADE", ids = KitPrices.only(deskId, catalog.grenades), column = 2 },
		{ title = if vehicles then "VEHICLES" else "CALL-INS", ids = sold, column = 3 },
	}
end

local function entryFor(section: string, id: string): Entry
	if section == "PRIMARY" or section == "SIDEARM" then
		return KitView.weaponEntry(id, section)
	elseif section == "GRENADE" then
		return KitView.grenadeEntry(id)
	end
	return KitView.callInEntry(id, section)
end

local function offerOf(id: string): DeskOffer.Offer
	return DeskOffer.offer(RecordClient.owns(id), RecordClient.priceOf(id), RecordClient.merits())
end

function DeskScreen.isOpen(): boolean
	return current ~= nil
end

-- Closes the screen without stepping back to the talk (a respawn, another desk).
function DeskScreen.close()
	local open = current
	if open then
		open.close(false)
	end
end

-- Whether this desk has a screen: it sells something (the Plot and the Loadmaster do not).
function DeskScreen.sells(desk: LobbyDesks.Desk): boolean
	return Config.Lobby.DeskScreen.Enabled and #DeskOffer.columns(sectionsFor(desk.id)) > 0
end

-- Opens desk `desk`'s screen (`from` is its prompt, off while the screen is up); `onClose`
-- runs when the soldier steps back. Returns false, opening nothing, when the desk sells
-- nothing or the screen is switched off.
function DeskScreen.open(desk: LobbyDesks.Desk, from: ProximityPrompt?, onClose: () -> ()): boolean
	if not DeskScreen.sells(desk) then
		return false
	end
	DeskScreen.close()
	local columns = DeskOffer.columns(sectionsFor(desk.id))
	local catalog = ArmsRoom.catalog()
	local allGuns = table.clone(catalog.primaries)
	for _, id in catalog.secondaries do
		table.insert(allGuns, id)
	end
	local roster = KitView.roster(allGuns, catalog.grenades, catalog.callIns)

	local hintText = "POINT TO LOOK, CLICK TO PICK   ·   [ENTER] BUY   ·   [BACKSPACE] STEP AWAY"
	if UserInputService.GamepadEnabled then
		hintText = "[A] PICK   [Y] BUY   [B] BACK"
	end
	local title = (desk.rack and desk.rack.header)
		or (desk.display and desk.display.header)
		or desk.title
	local screen = KitView.screen(gui, title, hintText)
	local frame, L, W, H = screen.frame, screen.L, screen.W, screen.H
	local connections = screen.connections

	-- Their line under the header, in their own voice; the merits top right by BACK.
	local voice = HudTheme.label(frame, { size = L.body, font = HudTheme.Font.Body, rich = true })
	voice.TextWrapped = true
	voice.TextYAlignment = Enum.TextYAlignment.Top
	voice.AutomaticSize = Enum.AutomaticSize.None
	if L.compact then
		voice.Position = UDim2.fromOffset(L.pad, 50)
		voice.Size = UDim2.fromOffset(L.column, L.bodyTop - 50 - 6)
	else
		voice.Position = UDim2.fromOffset(L.pad + 2, 62)
		voice.Size = UDim2.fromOffset(W - 2 * L.pad - 420, 26)
	end
	local function say(line: string)
		voice.Text = `{HudTheme.tint(string.upper(desk.who), C.TextDim)}   "{line}"`
	end
	say(desk.talk.openLine)
	local merits = HudTheme.label(frame, {
		size = 20,
		font = HudTheme.Font.Headline,
		color = C.Yellow,
		align = Enum.TextXAlignment.Right,
	})
	merits.AnchorPoint = Vector2.new(1, 0)
	merits.Position = UDim2.new(1, -(24 + 120 + 18), 0, 22)
	-- The keys go to the footer's left; the voice has the header's second line.
	screen.hint.Position = UDim2.fromOffset(L.pad + 2, H - L.footer / 2 - 6)

	local back = KitView.backButton(frame)

	-- Lists: one per column (one list holding every section on a compact screen).
	local columnW = if #columns == 1 and not L.compact then WIDE_ONE_COLUMN else L.column
	local listCount = if L.compact then 1 else #columns
	local inspectX = L.pad + listCount * columnW + (listCount - 1) * L.gap + 24
	if L.compact then
		inspectX = L.pad + L.column + 16
	end
	local inspectY = if L.compact then 52 else L.bodyTop
	local inspectPanel = KitView.inspect(
		frame,
		L,
		Vector2.new(inspectX, inspectY),
		Vector2.new(W - L.pad - inspectX, H - L.footer - inspectY)
	)

	local buy = KitView.confirmButton(screen, "BUY")
	local buyStroke = Instance.new("UIStroke")
	buyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buyStroke.Color = C.Yellow
	buyStroke.Enabled = false
	buyStroke.Parent = buy

	local selector = KitView.selector()
	local painters: { () -> () } = {}
	local shapes: { [string]: () -> () } = {}
	local rowsById: { [string]: TextButton } = {}
	local picked: Entry? = nil -- clicked (cream)
	local hovering: Entry? = nil -- under the mouse
	local first: Entry? = nil

	local function inspected(): Entry?
		return hovering or picked
	end

	local function paintInspect()
		local entry = inspected()
		if not entry then
			return
		end
		inspectPanel.show(entry)
		local offer = offerOf(entry.id)
		local owned = offer.state == "owned"
		inspectPanel.kicker.Text = if owned
			then `{entry.section}  ·  {HudTheme.tint("ON YOUR RECORD", C.Yellow)}`
			else entry.section
		inspectPanel.name.Text = entry.title
		inspectPanel.sub.Text = entry.subtitle
		inspectPanel.status.Text = if owned
			then HudTheme.tint(offer.status, C.Yellow)
			elseif offer.state == "closed" then HudTheme.tint(offer.status, C.TextDim)
			else `{HudTheme.tint(offer.status, C.RedLight)}  {HudTheme.tint(
				offer.badge,
				C.Yellow
			)}`
		inspectPanel.line.Text = entry.description
		inspectPanel.stats(KitView.statRows(entry, roster, nil))
		-- BUY: cream when it can be bought, dimmed when short, a yellow label when owned.
		buy.Text = offer.button
		buy.Active = offer.canBuy
		buy.AutoButtonColor = false
		buy.BackgroundTransparency = if owned or offer.state == "closed"
			then 1
			elseif offer.dim then 0.5
			else 0
		buy.TextColor3 = if owned
			then C.Yellow
			elseif offer.canBuy then C.MenuSelectText
			else C.TextDim
		buyStroke.Enabled = owned
		merits.Text = RecordClient.balanceText()
	end

	local function repaint()
		for _, paint in painters do
			paint()
		end
		paintInspect()
	end

	local function addRow(holder: Frame, index: number, entry: Entry)
		local row = KitView.row(holder, index, entry, L, selector)
		local item = row.item
		rowsById[entry.id] = item
		local refill = row.refill
		if refill then
			shapes[entry.id] = refill
		end
		first = first or entry
		item.MouseEnter:Connect(function()
			hovering = entry
			repaint()
		end)
		item.MouseLeave:Connect(function()
			if hovering and hovering.id == entry.id then
				hovering = nil
				repaint()
			end
		end)
		item.SelectionGained:Connect(function()
			picked = entry
			repaint()
		end)
		item.Activated:Connect(function()
			picked = entry
			repaint()
		end)
		table.insert(painters, function()
			local offer = offerOf(entry.id)
			local look = inspected()
			row.paint({
				selected = picked ~= nil and picked.id == entry.id,
				focus = look ~= nil and look.id == entry.id,
				dim = offer.state == "closed",
				badge = offer.badge,
				badgeColor = if offer.state == "owned" then C.TextDim else C.Yellow,
				sub = entry.subtitle,
			})
		end)
	end

	local bodyH = H - L.footer - L.bodyTop
	local holders: { ScrollingFrame } = {}
	for index = 1, listCount do
		local holder = KitView.scroller(
			frame,
			Vector2.new(L.pad + (index - 1) * (columnW + L.gap), L.bodyTop),
			Vector2.new(columnW + 8, bodyH),
			if L.compact then 6 else 4
		)
		KitView.list(holder, 18)
		table.insert(holders, holder)
	end
	local order = 0
	for index, sections in columns do
		local holder = holders[math.min(index, #holders)]
		for _, section in sections do
			order += 1
			local frame_ = KitView.section(holder, order, section.title, true)
			for rowIndex, id in section.ids do
				addRow(frame_, rowIndex, entryFor(section.title, id))
			end
		end
	end

	-- Buying: what is looked at, through the server (RecordService decides).
	local function buyIt()
		local entry = inspected()
		if entry and offerOf(entry.id).canBuy then
			RecordClient.buy(entry.id)
		end
	end
	buy.Activated:Connect(buyIt)

	local open: Open
	local function close(stepBack: boolean)
		if current ~= open then
			return
		end
		current = nil
		for _, connection in connections do
			connection:Disconnect()
		end
		ContextActionService:UnbindAction(ACTION_BACK)
		ContextActionService:UnbindAction(ACTION_BUY)
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(frame) then
			GuiService.SelectedObject = nil
		end
		selector:Destroy()
		frame:Destroy()
		HoldStill.set(false)
		if from then
			from.Enabled = true
		end
		if stepBack then
			onClose()
		end
	end
	open = {
		desk = desk,
		close = close,
		repaint = repaint,
		answer = function(reason: string?)
			say(DeskOffer.answer(desk.talk, reason))
		end,
	}
	current = open

	back.Activated:Connect(function()
		close(true)
	end)
	ContextActionService:BindAction(ACTION_BACK, function(_, state)
		if state == Enum.UserInputState.Begin then
			close(true)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction(ACTION_BUY, function(_, state)
		if state == Enum.UserInputState.Begin then
			buyIt()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonY)

	-- The looked-at model turns while the screen is up; late models replace their stand-ins.
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			inspectPanel.turn(dt)
		end)
	)
	local arrived = Showcase.onArrived(function(id)
		local refill = shapes[id]
		if refill then
			refill()
		end
		inspectPanel.reshow(id)
	end)
	if arrived then
		table.insert(connections, arrived)
	end

	HoldStill.set(true)
	if from then
		from.Enabled = false
	end
	picked = first
	repaint()
	if UserInputService.GamepadEnabled and first then
		GuiService.SelectedObject = rowsById[first.id]
	end
	return true
end

function DeskScreen.init()
	HudTheme.parent(gui)
	-- The server's answer to a buy: the new record (repaint, and their "bought" line when the
	-- merits went down) or a refusal in their words.
	local meritsBefore = RecordClient.merits()
	RecordClient.Changed:Connect(function()
		local open = current
		if open then
			open.repaint()
			if RecordClient.merits() < meritsBefore then
				open.answer(nil)
			end
		end
		meritsBefore = RecordClient.merits()
	end)
	RecordClient.Refused:Connect(function(_id: unknown, reason: unknown)
		local open = current
		if open then
			open.answer(if type(reason) == "string" then reason else "refused")
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(DeskScreen.close)
end

return DeskScreen
