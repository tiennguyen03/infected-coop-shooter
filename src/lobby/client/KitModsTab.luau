--!strict
-- The Loadmaster's KIT MODS tab (Nova, 2026-11-18): beside LOADOUT on his screen (the tab bar
-- LoadmasterUI puts in the Loadout screen's header, the Loadout screen's own tab buttons). One
-- row per Kit Mod (Config.KitMods, in Order): its name, what it does, its rank (RANK 1/3 and
-- three pips), the next rank's price and BUY; a maxed mod reads MAXED; a mod not switched on
-- yet (Enabled = false) is greyed with COMING SOON and cannot be bought. Merits only. The
-- server decides every buy (KitModService on the `KitMods` remote); the rows change when it
-- answers with the new ranks. Same look as the rest of the screen: the menu field, Track rows,
-- cream for what you hold, red BUY (HudTheme, docs/STYLES.md section 5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KitModRules = require(ReplicatedStorage.Shared.Rules.KitModRules)
local KitMods = require(ReplicatedStorage.Shared.KitMods)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HudTheme = require(script.Parent.HudTheme)
local RecordClient = require(script.Parent.RecordClient)

local KitModsTab = {}

local C = HudTheme.Color
local TOP = 100 -- design pixels below the frame's top: under the header and the tabs
local ROW = 92
local PIP = 14
local BUY = Vector2.new(170, 40)
local Z = 30 -- over the Loadout lists (the Loadmaster's ScreenGui sorts by global ZIndex)

-- What a refused buy says (KitModService's reasons).
local REFUSED: { [string]: string } = {
	short = "Not enough merits for that rank yet.",
	maxed = "That one is as high as it goes.",
	["not next"] = "The screen was behind: try again.",
	["beyond max"] = "That one is as high as it goes.",
	disabled = "Not issued yet.",
	loading = "Your record is still loading. Try again in a moment.",
	busy = "The Loadmaster is busy. Try again in a moment.",
}

export type Tab = {
	show: (on: boolean) -> (),
	destroy: () -> (),
}

local function text(
	parent: Instance,
	value: string,
	size: number,
	color: Color3,
	font: Enum.Font?
): TextLabel
	local label = HudTheme.label(parent, { text = value, size = size, color = color, font = font })
	return label
end

-- The tab's panel over the Loadout screen's body inside `frame` (its design size W x H).
function KitModsTab.mount(frame: Frame, W: number, H: number, pad: number): Tab
	local remote = Remotes.get("KitMods")
	local ranks: KitModRules.Ranks? = nil -- nil until the server has sent them
	local waiting = false -- a BUY sent and not yet answered
	local connections: { RBXScriptConnection } = {}

	-- A button-backed panel, so clicks stop here and never reach the lists under it.
	local panel = Instance.new("TextButton")
	panel.Name = "KitMods"
	panel.AutoButtonColor = false
	panel.Text = ""
	panel.BorderSizePixel = 0
	panel.BackgroundColor3 = C.MenuBack
	panel.BackgroundTransparency = 0
	panel.Position = UDim2.fromOffset(pad, TOP)
	panel.Size = UDim2.fromOffset(W - pad * 2, H - TOP - pad)
	panel.Visible = false
	panel.Parent = frame

	local width = W - pad * 2
	local kicker = text(
		panel,
		"KIT MODS  ·  ON THE SOLDIER, WHATEVER YOU CARRY  ·  BOUGHT ONCE A RANK, KEPT FOR GOOD",
		14,
		C.TextDim
	)
	kicker.Position = UDim2.fromOffset(0, 0)
	local wallet = text(panel, "", 16, C.Text, HudTheme.Font.Headline)
	wallet.AnchorPoint = Vector2.new(1, 0)
	wallet.Position = UDim2.new(1, 0, 0, -2)
	wallet.TextXAlignment = Enum.TextXAlignment.Right
	local status = text(panel, "", 15, C.TextDim)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)

	local painters: { () -> () } = {}
	local function repaint()
		wallet.Text = `{RecordClient.merits()} MERITS`
		for _, paint in painters do
			paint()
		end
	end

	local y = 32
	for _, id in KitMods.ordered() do
		local mod = KitMods.get(id)
		if not mod then
			continue
		end
		local row = Instance.new("Frame")
		row.Name = id
		row.BorderSizePixel = 0
		row.BackgroundColor3 = C.Track
		row.Position = UDim2.fromOffset(0, y)
		row.Size = UDim2.fromOffset(width, ROW - 10)
		row.Parent = panel
		y += ROW

		local name = text(row, string.upper(mod.displayName), 20, C.Text, HudTheme.Font.Headline)
		name.Position = UDim2.fromOffset(16, 12)
		local about = text(row, mod.description, 15, C.TextDim, HudTheme.Font.Body)
		about.Position = UDim2.fromOffset(16, 44)
		about.Size = UDim2.fromOffset(width - 520, 20)
		about.TextTruncate = Enum.TextTruncate.AtEnd

		-- The rank: RANK n/max over a pip for each rank (cream when held).
		local rankLabel = text(row, "", 14, C.Text)
		rankLabel.Position = UDim2.fromOffset(width - 470, 14)
		local pips: { Frame } = {}
		for index = 1, mod.maxRank do
			local pip = Instance.new("Frame")
			pip.BorderSizePixel = 0
			pip.Size = UDim2.fromOffset(PIP * 2, PIP)
			pip.Position = UDim2.fromOffset(width - 470 + (index - 1) * (PIP * 2 + 6), 42)
			pip.Parent = row
			table.insert(pips, pip)
		end

		local cost = text(row, "", 14, C.TextDim)
		cost.AnchorPoint = Vector2.new(1, 0.5)
		cost.Position = UDim2.new(1, -BUY.X - 32, 0.5, 0)
		cost.TextXAlignment = Enum.TextXAlignment.Right
		local buy = Instance.new("TextButton")
		buy.AutoButtonColor = false
		buy.BorderSizePixel = 0
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -16, 0.5, 0)
		buy.Size = UDim2.fromOffset(BUY.X, BUY.Y)
		buy.Font = HudTheme.Font.Headline
		buy.TextSize = 16
		buy.Parent = row

		local function held(): number
			return if ranks then math.clamp(ranks[id] or 0, 0, mod.maxRank) else 0
		end
		buy.Activated:Connect(function()
			if not ranks or not mod.enabled then
				return
			end
			local rank = held()
			local price = KitModRules.nextCost(mod, rank)
			if not price then
				return
			end
			status.Text = `Signing {mod.displayName} rank {rank + 1} to your record...`
			status.TextColor3 = C.TextDim
			waiting = true
			remote:FireServer(Messages.KitMods.Buy, id, rank + 1)
		end)

		table.insert(painters, function()
			local rank = held()
			local price = KitModRules.nextCost(mod, rank)
			local off = not mod.enabled
			row.BackgroundTransparency = if off then 0.7 else 0.35
			name.TextColor3 = if off then C.TextDim else C.Text
			rankLabel.Text = if off then "" else `RANK {rank}/{mod.maxRank}`
			for index, pip in pips do
				pip.Visible = not off
				pip.BackgroundColor3 = if index <= rank then C.MenuSelect else C.TextDim
				pip.BackgroundTransparency = if index <= rank then 0 else 0.75
			end
			local affordable = price ~= nil and RecordClient.merits() >= price
			if off then
				cost.Text = ""
				buy.Text = "COMING SOON"
				buy.BackgroundColor3 = C.Track
				buy.TextColor3 = C.TextDim
				buy.Active = false
			elseif not price then
				cost.Text = ""
				buy.Text = "MAXED"
				buy.BackgroundColor3 = C.MenuSelect
				buy.TextColor3 = C.MenuSelectText
				buy.Active = false
			else
				cost.Text = `RANK {rank + 1}: {price} MERITS`
				cost.TextColor3 = if affordable then C.Text else C.TextDim
				buy.Text = "BUY"
				buy.BackgroundColor3 = if affordable then C.Red else C.Track
				buy.TextColor3 = if affordable then C.Text else C.TextDim
				buy.Active = ranks ~= nil
			end
		end)
	end

	table.insert(
		connections,
		remote.OnClientEvent:Connect(function(kind: string, a: any, b: any)
			if kind == Messages.KitMods.State and typeof(a) == "table" then
				local fresh: KitModRules.Ranks = {}
				for id, rank in a :: { [any]: any } do
					if typeof(id) == "string" and typeof(rank) == "number" then
						fresh[id] = rank
					end
				end
				ranks = fresh
				if waiting then
					waiting = false
					status.Text = "Signed to your record."
					status.TextColor3 = C.Text
				end
				repaint()
			elseif kind == Messages.KitMods.Refused then
				waiting = false
				status.Text = REFUSED[tostring(b)] or `Refused ({tostring(b)}).`
				status.TextColor3 = C.Red
			end
		end)
	)
	table.insert(connections, RecordClient.Changed:Connect(repaint))

	-- Above the Loadout lists: every piece's ZIndex raised past theirs.
	panel.ZIndex = Z
	for _, child in panel:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex += Z
		end
	end

	repaint()
	remote:FireServer(Messages.KitMods.Get)

	return {
		show = function(on: boolean)
			panel.Visible = on
			if on then
				repaint()
			end
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			panel:Destroy()
		end,
	}
end

return KitModsTab
