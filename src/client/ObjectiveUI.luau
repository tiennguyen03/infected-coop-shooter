--!strict
-- The mission's objectives on the HUD (docs/STYLES.md section 5; ObjectiveService).
--
-- The pools (ObjectiveUpdate "board" / "brief"):
-- - the main objective's card at insert, upper centre: its name, why, and where;
-- - the main objective on the mission line (MissionLine, lower centre): "MAIN OBJECTIVE
--   NAME", the reason under it the whole time, then what to do now with its progress, any
--   timer and the distance, over the thin bar;
-- - the objective list, top left under the Resupply line: one row per known objective with
--   a needle that turns toward it and the distance; a side objective also shows its reason
--   and what to do. Side objectives appear when the squad finds them.
-- The single hold (Config.Objectives.Enabled = false): "SECURE the AREA" on the mission
-- line, driven by "started" / "progress" / "completed".
-- Nothing here runs per frame: the list and the distances refresh at REFRESH_HZ.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Rules = require(ReplicatedStorage.Shared.Rules.Objectives)
local HudTheme = require(script.Parent.HudTheme)
local MissionLine = require(script.Parent.MissionLine)
local SoundFX = require(script.Parent.SoundFX)

local ObjectiveUI = {}

local C = HudTheme.Color
local OWNER = "objective"
local DONE_SECONDS = 2.5
local REFRESH_HZ = 4
local LIST_TOP = 150 -- under the Resupply line (16, 108)
local ROW_GAP = 8

-- The single hold.
local active = false
local doneToken = 0

-- The pools.
type Row = {
	frame: Frame,
	needle: Frame,
	head: TextLabel,
	why: TextLabel,
	step: TextLabel,
}

local board: { Rules.Entry } = {}
local rows: { [string]: Row } = {}
local seenState: { [string]: string } = {}
local list: Frame = nil :: any
local card: Frame = nil :: any
local cardName: TextLabel = nil :: any
local cardWhy: TextLabel = nil :: any
local cardPlace: TextLabel = nil :: any
local cardToken = 0

local function holdTitle(): string
	return `SECURE the {HudTheme.tint("AREA", C.Yellow)}`
end

local function onHold(kind: string, progress: number, playersIn: number?, playersLiving: number?)
	local required = Config.Objective.RequiredSeconds
	if kind == Messages.ObjectiveUpdate.Started then
		active = true
		doneToken += 1
		MissionLine.set(OWNER, holdTitle(), `0 of {required}s`, 0)
	elseif kind == Messages.ObjectiveUpdate.Progress and active then
		local sub = `{math.floor(progress)} of {required}s`
		if playersLiving and playersLiving > 1 then
			sub ..= `  ·  {playersIn or 0} of {playersLiving} in`
		end
		MissionLine.set(OWNER, holdTitle(), sub, progress / math.max(required, 1))
	elseif kind == Messages.ObjectiveUpdate.Completed then
		if not active then
			if #board == 0 then
				MissionLine.clear(OWNER)
			end
			return
		end
		active = false
		doneToken += 1
		SoundFX.ui("ui_radio", "objective_complete")
		local token = doneToken
		MissionLine.set(OWNER, `AREA {HudTheme.tint("SECURED", C.Yellow)}`, "", nil)
		task.delay(DONE_SECONDS, function()
			if token == doneToken then
				MissionLine.clear(OWNER)
			end
		end)
	end
end

-- Where the player is and which way the camera looks, for distances and needles.
local function viewpoint(): (Vector3?, Vector3)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart")
		then root.Position
		elseif camera then camera.CFrame.Position
		else nil
	return from, if camera then camera.CFrame.LookVector else Vector3.zAxis
end

local function distanceText(entry: Rules.Entry, from: Vector3?): string
	if not from then
		return ""
	end
	local metres = Rules.metres((entry.position - from).Magnitude, Config.Objectives.MetresPerStud)
	return `{metres} m`
end

-- "what to do  ·  2 of 3  ·  1:32 left", leaving out what there is none of.
local function detailText(entry: Rules.Entry): string
	local parts = { entry.step }
	local progress = Rules.progressText(entry.done, entry.total, entry.unit)
	if progress ~= "" then
		table.insert(parts, progress)
	end
	if entry.timeLeft then
		table.insert(parts, `{Rules.clock(entry.timeLeft)} left`)
	end
	return table.concat(parts, "  ·  ")
end

local function stateTag(entry: Rules.Entry): string
	if entry.state == "done" then
		return "  " .. HudTheme.tint("DONE", C.Yellow)
	elseif entry.state == "failed" then
		return "  " .. HudTheme.tint("FAILED", C.RedLight)
	end
	return ""
end

local function buildRow(order: number): Row
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	frame.LayoutOrder = order
	frame.Parent = list

	-- The needle: a thin bar with a cross-piece at its tip, turned toward the objective
	-- (up = straight ahead).
	local needle = Instance.new("Frame")
	needle.BackgroundTransparency = 1
	needle.Size = UDim2.fromOffset(14, 14)
	needle.Position = UDim2.fromOffset(0, 1)
	needle.Parent = frame
	local shaft = HudTheme.rect(needle, UDim2.fromOffset(2, 12), C.White)
	shaft.Position = UDim2.fromOffset(6, 1)
	local tip = HudTheme.rect(needle, UDim2.fromOffset(8, 2), C.White)
	tip.Position = UDim2.fromOffset(3, 1)

	local text = Instance.new("Frame")
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.XY
	text.Position = UDim2.fromOffset(20, 0)
	text.Size = UDim2.fromOffset(0, 0)
	text.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 1)
	layout.Parent = text

	local head = HudTheme.label(text, { size = 14, rich = true })
	head.LayoutOrder = 1
	local why = HudTheme.label(text, { font = HudTheme.Font.Body, size = 12, color = C.TextDim })
	why.LayoutOrder = 2
	local step = HudTheme.label(text, { font = HudTheme.Font.Body, size = 12, rich = true })
	step.LayoutOrder = 3
	return { frame = frame, needle = needle, head = head, why = why, step = step }
end

-- Draws the board: the mission line for the main objective, a list row for each one.
local function render()
	local from, look = viewpoint()
	local main: Rules.Entry? = nil
	local shown: { [string]: boolean } = {}
	for order, entry in board do
		shown[entry.slot] = true
		local isMain = entry.role == "main"
		if isMain then
			main = entry
		end
		local row = rows[entry.slot]
		if not row then
			row = buildRow(order)
			rows[entry.slot] = row
		end
		local open = Rules.isOpen(entry.state)
		local label = if isMain then "MAIN OBJECTIVE" else "SIDE OBJECTIVE"
		local distance = if open then distanceText(entry, from) else ""
		row.head.Text = `{HudTheme.tint(label, C.TextDim)}  {HudTheme.tint(
			string.upper(entry.name),
			C.Yellow
		)}{stateTag(entry)}{if distance ~= "" then "  " .. distance else ""}`
		-- The main objective's reason and step are on the mission line; a side one's are here.
		row.why.Text = entry.why
		row.why.Visible = not isMain
		row.step.Text = detailText(entry)
		row.step.Visible = not isMain and open
		row.needle.Visible = open and from ~= nil
		if from then
			local to = entry.position - from
			row.needle.Rotation = Rules.bearing(look.X, look.Z, to.X, to.Z)
		end
		-- A finished or failed objective says so once.
		if seenState[entry.slot] ~= entry.state then
			if entry.state == "done" and seenState[entry.slot] ~= nil then
				SoundFX.ui("ui_radio", "objective_complete")
			end
			seenState[entry.slot] = entry.state
		end
	end
	for slot, row in rows do
		if not shown[slot] then
			row.frame:Destroy()
			rows[slot] = nil
			seenState[slot] = nil
		end
	end
	list.Visible = next(rows) ~= nil

	if main then
		local name = HudTheme.tint(string.upper(main.name), C.Yellow)
		if Rules.isOpen(main.state) then
			local detail = detailText(main)
			local distance = distanceText(main, from)
			if distance ~= "" then
				detail ..= `  ·  {distance}`
			end
			MissionLine.set(
				OWNER,
				`MAIN OBJECTIVE  {name}`,
				main.why,
				Rules.fraction(main.done, main.total),
				nil,
				detail
			)
		else
			MissionLine.set(OWNER, `{name}{stateTag(main)}`, "", nil)
		end
	elseif not active then
		MissionLine.clear(OWNER)
	end
end

-- The main objective's card at insert: what, why, where, before the squad moves.
local function showBrief(name: string, why: string, place: string)
	cardToken += 1
	local token = cardToken
	cardName.Text = string.upper(name)
	cardWhy.Text = why
	cardPlace.Text = `at {place}`
	card.Visible = true
	for _, label in { cardName, cardWhy, cardPlace } do
		label.TextTransparency = 1
		TweenService:Create(
			label,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		):Play()
	end
	task.delay(Config.Objectives.BriefSeconds, function()
		if token ~= cardToken then
			return
		end
		for _, label in { cardName, cardWhy, cardPlace } do
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
		task.delay(0.3, function()
			if token == cardToken then
				card.Visible = false
			end
		end)
	end)
end

local function build()
	local gui = HudTheme.gui("ObjectiveUI", 9)
	list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(HudTheme.Margin, LIST_TOP)
	list.AutomaticSize = Enum.AutomaticSize.XY
	list.Size = UDim2.fromOffset(0, 0)
	list.Visible = false
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = list

	-- No panel (HUD language): three centred lines high on the screen, clear of the centre.
	card = Instance.new("Frame")
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, if HudTheme.isTouch() then 150 else 120)
	card.Size = UDim2.fromOffset(900, 110)
	card.Visible = false
	card.Parent = gui
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, 4)
	cardLayout.Parent = card
	local kicker = HudTheme.label(card, { text = "MAIN OBJECTIVE", size = 14, color = C.TextDim })
	kicker.LayoutOrder = 1
	cardName = HudTheme.label(card, { font = HudTheme.Font.Headline, size = 36, color = C.Yellow })
	cardName.LayoutOrder = 2
	cardWhy = HudTheme.label(card, { font = HudTheme.Font.Body, size = 18 })
	cardWhy.LayoutOrder = 3
	cardPlace = HudTheme.label(card, { size = 16, color = C.TextDim })
	cardPlace.LayoutOrder = 4

	HudTheme.parent(gui)
end

local function onObjectiveUpdate(kind: string, ...: any)
	if kind == Messages.ObjectiveUpdate.Board then
		board = (...) :: { Rules.Entry }
		render()
	elseif kind == Messages.ObjectiveUpdate.Brief then
		local name, why, place = ...
		showBrief(tostring(name), tostring(why), tostring(place))
	else
		onHold(kind, ...)
	end
end

function ObjectiveUI.init()
	MissionLine.init()
	build()
	local remote = Remotes.get("ObjectiveUpdate")
	remote.OnClientEvent:Connect(onObjectiveUpdate)
	-- Distances and needles follow the player between the server's updates.
	task.spawn(function()
		while true do
			task.wait(1 / REFRESH_HZ)
			if #board > 0 then
				render()
			end
		end
	end)
	-- This client may have loaded after the objectives were drawn: ask for them.
	remote:FireServer(Messages.ObjectiveUpdate.Request)
end

return ObjectiveUI
