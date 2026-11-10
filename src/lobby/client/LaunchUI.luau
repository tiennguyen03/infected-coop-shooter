--!strict
-- Your seat on a Lantern spot (LaunchService): while you stand in a boarding box, the lower
-- middle of the screen shows the spot, who is aboard and the countdown to lift; "LIFTING"
-- when it goes, and the reason when a teleport does not happen. HUD style per HudTheme.
-- The first soldier aboard also gets the squad-size buttons (1-4): once that many are
-- aboard the countdown drops to Config.Lobby.Launch.FullCountdown (Rules/Manifest), so a
-- solo soldier does not wait out the full countdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HudTheme = require(script.Parent.HudTheme)

local LaunchUI = {}

local FAILED_SECONDS = 6
local CAPACITY = Config.Lobby.Launch.Capacity

local function sizeLabel(size: number): string
	if size == 1 then
		return "SOLO"
	elseif size == CAPACITY then
		return `FULL ({size})`
	end
	return tostring(size)
end

function LaunchUI.init()
	local remote = Remotes.get("Launch")
	local gui = HudTheme.gui("LaunchUI", 5)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -120)
	holder.Size = UDim2.fromOffset(520, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Visible = false
	holder.Parent = gui
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = holder

	local title = HudTheme.label(
		holder,
		{ size = 26, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow }
	)
	title.LayoutOrder = 1
	local crew = HudTheme.label(holder, { size = 18 })
	crew.LayoutOrder = 2
	local status = HudTheme.label(holder, { size = 22, font = HudTheme.Font.Headline })
	status.LayoutOrder = 3

	-- The squad-size picker: only the first soldier aboard sees it.
	local picker = HudTheme.rect(
		holder,
		UDim2.fromOffset(440, 0),
		HudTheme.Color.Track,
		HudTheme.TrackTransparency,
		true
	)
	picker.LayoutOrder = 4
	picker.AutomaticSize = Enum.AutomaticSize.Y
	picker.Visible = false
	do
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 10)
		padding.Parent = picker
		local column = Instance.new("UIListLayout")
		column.HorizontalAlignment = Enum.HorizontalAlignment.Center
		column.SortOrder = Enum.SortOrder.LayoutOrder
		column.Padding = UDim.new(0, 6)
		column.Parent = picker
	end
	local ask = HudTheme.label(picker, {
		text = "SQUAD SIZE · lifts in "
			.. Config.Lobby.Launch.FullCountdown
			.. " s once everyone's aboard",
		size = 14,
		color = HudTheme.Color.TextDim,
	})
	ask.LayoutOrder = 1
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(420, 36)
	row.LayoutOrder = 2
	row.Parent = picker
	do
		local across = Instance.new("UIListLayout")
		across.FillDirection = Enum.FillDirection.Horizontal
		across.HorizontalAlignment = Enum.HorizontalAlignment.Center
		across.Padding = UDim.new(0, 8)
		across.Parent = row
	end
	local buttons: { TextButton } = {}
	for size = 1, CAPACITY do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(96, 36)
		b.BorderSizePixel = 0
		b.AutoButtonColor = true
		b.Font = HudTheme.Font.Headline
		b.TextSize = 16
		b.Text = sizeLabel(size)
		b.LayoutOrder = size
		b.Parent = row
		b.Activated:Connect(function()
			remote:FireServer(Messages.Launch.Squad, size)
		end)
		table.insert(buttons, b)
	end
	HudTheme.parent(gui)

	local function paint(squad: number)
		for size, b in buttons do
			local chosen = size == squad
			b.BackgroundColor3 = if chosen then HudTheme.Color.Yellow else HudTheme.Color.Track
			b.BackgroundTransparency = if chosen then 0 else 0.35
			b.TextColor3 = if chosen then HudTheme.Color.Track else HudTheme.Color.Text
		end
	end

	local function showPicker(visible: boolean)
		picker.Visible = visible
		buttons[1].Modal = visible -- frees the mouse even zoomed into first person
	end

	local liftAt: number? = nil -- os.clock on this client
	local hideAt: number? = nil

	remote.OnClientEvent:Connect(function(kind: string, ...)
		if kind == Messages.Launch.Manifest then
			local spot, names, secondsLeft, squad, isLead = ...
			local wanted = if typeof(squad) == "number" and squad > 0 then squad else CAPACITY
			title.Text = `LANTERN · SPOT {spot}`
			crew.Text = `Aboard {#names}/{wanted}: {table.concat(names, ", ")}`
			status.TextColor3 = HudTheme.Color.Text
			liftAt = os.clock() + (secondsLeft :: number)
			hideAt = nil
			holder.Visible = true
			paint(if typeof(squad) == "number" then squad else 0)
			showPicker(isLead == true)
		elseif kind == Messages.Launch.Lifting then
			liftAt = nil
			status.Text = "LIFTING"
			status.TextColor3 = HudTheme.Color.Yellow
			showPicker(false)
		elseif kind == Messages.Launch.Failed then
			local reason = ...
			liftAt = nil
			status.Text = reason
			status.TextColor3 = HudTheme.Color.RedLight
			hideAt = os.clock() + FAILED_SECONDS
			holder.Visible = true
			showPicker(false)
		elseif kind == Messages.Launch.Cleared then
			liftAt = nil
			holder.Visible = false
			showPicker(false)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if liftAt then
			status.Text = `Lifts in {math.ceil(math.max(0, liftAt - os.clock()))}`
		end
		if hideAt and os.clock() >= hideAt then
			hideAt = nil
			holder.Visible = false
		end
	end)
end

return LaunchUI
