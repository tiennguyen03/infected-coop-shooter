--!strict
-- The squad panel on the Carrier (loop sprint 2; server: PartyService, rules: Rules/Party).
-- Config.Keys.Party (P) opens it: your squad (leader, READY marks), INVITE (soldiers on the
-- Carrier, or friends anywhere through Roblox's invite), LEAVE, and KICK for the leader. A
-- small line under it always says the squad's size. An invite arrives as a card with
-- ACCEPT / DECLINE; a friend's invite to another Carrier offers the flight there. Other
-- screens read the squad through `PartyUI.view()` and `PartyUI.onChange`.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage.Shared.Config)
local HudTheme = require(script.Parent.HudTheme)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Party = require(ReplicatedStorage.Shared.Rules.Party)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PartyUI = {}

local C = HudTheme.Color
local WIDTH = 300
local ACTION = "PartyPanel"

export type MemberView = { id: number, name: string, ready: boolean, leader: boolean }
export type View = {
	leader: number,
	members: { MemberView },
	mission: string?,
	deployIn: number?,
	isLeader: boolean,
	flying: boolean,
}

local current: View? = nil
local listeners: { (View) -> () } = {}
local remote: RemoteEvent

function PartyUI.view(): View?
	return current
end

function PartyUI.onChange(listener: (View) -> ())
	table.insert(listeners, listener)
end

local function button(parent: Instance, text: string, width: number, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 30)
	b.BackgroundColor3 = C.Track
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.Font = HudTheme.Font.Line
	b.TextSize = 15
	b.TextColor3 = C.Text
	b.Text = text
	b.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.White
	stroke.Transparency = HudTheme.OutlineTransparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	b.Parent = parent
	return b
end

local function panelFrame(gui: ScreenGui, anchor: Vector2, position: UDim2): Frame
	local frame = HudTheme.rect(gui, UDim2.fromOffset(WIDTH, 0), C.MenuBack, 0.06)
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Red
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = frame
	return frame
end

local function clear(frame: Instance, keep: { Instance })
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") and not table.find(keep, child) then
			child:Destroy()
		end
	end
end

function PartyUI.init()
	remote = Remotes.get("Party")
	local gui = HudTheme.gui("PartyUI", 5)
	local me = Players.LocalPlayer

	-- The one line that is always there.
	local strip = HudTheme.label(gui, { size = 15, font = HudTheme.Font.Line, color = C.TextDim })
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.Position = UDim2.new(0, 16, 1, -16)

	local panel = panelFrame(gui, Vector2.new(0, 1), UDim2.new(0, 16, 1, -44))
	panel.Visible = false
	local title =
		HudTheme.label(panel, { size = 20, font = HudTheme.Font.Headline, text = "//SQUAD" })
	title.LayoutOrder = 1
	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.fromOffset(WIDTH - 24, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.LayoutOrder = 2
	rows.Parent = panel
	local rowList = Instance.new("UIListLayout")
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0, 4)
	rowList.Parent = rows
	local status =
		HudTheme.label(panel, { size = 14, font = HudTheme.Font.Body, color = C.TextDim })
	status.LayoutOrder = 3
	status.AutomaticSize = Enum.AutomaticSize.Y
	status.Size = UDim2.fromScale(1, 0)
	status.TextWrapped = true
	local invite = button(panel, "INVITE", WIDTH - 24, 4)
	local leave = button(panel, "LEAVE SQUAD", WIDTH - 24, 5)

	-- The invite list: soldiers on the Carrier, and friends through Roblox.
	local picker = panelFrame(gui, Vector2.new(0, 1), UDim2.new(0, WIDTH + 28, 1, -44))
	picker.Visible = false
	local pickerTitle =
		HudTheme.label(picker, { size = 18, font = HudTheme.Font.Headline, text = "//INVITE" })
	pickerTitle.LayoutOrder = 1
	local friends = button(picker, "INVITE FRIENDS", WIDTH - 24, 2)
	local close = button(picker, "CLOSE", WIDTH - 24, 1000)

	-- A card for an incoming invite or an offer to fly to a friend's Carrier.
	local card = panelFrame(gui, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 90))
	card.Visible = false
	local cardLine = HudTheme.label(card, { size = 17, font = HudTheme.Font.Line })
	cardLine.LayoutOrder = 1
	cardLine.AutomaticSize = Enum.AutomaticSize.Y
	cardLine.Size = UDim2.fromScale(1, 0)
	cardLine.TextWrapped = true
	local yes = button(card, "ACCEPT", WIDTH - 24, 2)
	local no = button(card, "DECLINE", WIDTH - 24, 3)
	local cardKind: string? = nil
	local cardUntil = 0

	local function say(text: string)
		status.Text = text
	end

	local function members(): { [number]: boolean }
		local ids: { [number]: boolean } = {}
		for _, member in (if current then current.members else {}) :: { MemberView } do
			ids[member.id] = true
		end
		return ids
	end

	local function fillPicker()
		clear(picker, { pickerTitle, friends, close })
		local inSquad = members()
		local order = 10
		for _, player in Players:GetPlayers() do
			if player ~= me and not inSquad[player.UserId] then
				order += 1
				local b = button(picker, player.DisplayName, WIDTH - 24, order)
				b.Activated:Connect(function()
					remote:FireServer(Messages.Party.Invite, player.UserId)
				end)
			end
		end
		if order == 10 then
			local none = HudTheme.label(picker, {
				size = 14,
				font = HudTheme.Font.Body,
				color = C.TextDim,
				text = "Nobody else on the Carrier.",
			})
			none.LayoutOrder = 11
		end
	end

	local function render()
		local view = current
		if not view then
			return
		end
		local size = #view.members
		strip.Text = `SQUAD {size}/{Config.Lobby.Launch.Capacity}  ·  [{Config.Keys.Party.Name}]`
		clear(rows, {})
		for index, member in view.members do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.fromOffset(WIDTH - 24, 26)
			row.LayoutOrder = index
			row.Parent = rows
			local tag = if member.leader then "  LEAD" elseif member.ready then "  READY" else ""
			local name = HudTheme.label(row, {
				size = 16,
				font = HudTheme.Font.Line,
				rich = true,
				text = `{member.name}{HudTheme.tint(
					tag,
					if member.ready or member.leader then C.Yellow else C.TextDim
				)}`,
			})
			name.Position = UDim2.fromOffset(0, 3)
			if view.isLeader and member.id ~= me.UserId then
				local kick = button(row, "KICK", 56, 1)
				kick.AnchorPoint = Vector2.new(1, 0)
				kick.Position = UDim2.fromScale(1, 0)
				kick.Size = UDim2.fromOffset(56, 24)
				kick.Activated:Connect(function()
					remote:FireServer(Messages.Party.Kick, member.id)
				end)
			end
		end
		invite.Visible = view.isLeader and size < Config.Lobby.Launch.Capacity
		leave.Visible = size > 1
		if view.flying then
			say("Lifting...")
		elseif view.deployIn then
			say(
				`Leaving in {math.ceil(view.deployIn)} s. Press DEPLOY on the Mission Board to say READY.`
			)
		elseif view.isLeader then
			say(
				if size > 1
					then "Pick a mission in the map room."
					else "Invite your squad, or go alone with bots."
			)
		else
			say("Your leader picks the mission in the map room.")
		end
		if picker.Visible then
			fillPicker()
		end
	end

	local function showCard(
		kind: string,
		text: string,
		yesText: string,
		noText: string,
		seconds: number
	)
		cardKind = kind
		cardLine.Text = text
		yes.Text = yesText
		no.Text = noText
		cardUntil = os.clock() + seconds
		card.Visible = true
		task.delay(seconds, function()
			if os.clock() >= cardUntil then
				card.Visible = false
			end
		end)
	end

	invite.Activated:Connect(function()
		picker.Visible = not picker.Visible
		if picker.Visible then
			fillPicker()
		end
	end)
	close.Activated:Connect(function()
		picker.Visible = false
	end)
	leave.Activated:Connect(function()
		remote:FireServer(Messages.Party.Leave)
	end)
	friends.Activated:Connect(function()
		local view = current
		if not view then
			return
		end
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(me)
		end)
		if not ok or not can then
			say("Roblox won't send invites from here (Studio, or invites are off).")
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		options.LaunchData = Party.launchText(view.leader, game.JobId)
		options.PromptMessage = "Join my squad on the Carrier"
		pcall(function()
			SocialService:PromptGameInvite(me, options)
		end)
	end)
	yes.Activated:Connect(function()
		card.Visible = false
		if cardKind == "invite" then
			remote:FireServer(Messages.Party.Accept)
		elseif cardKind == "follow" then
			remote:FireServer(Messages.Party.Follow)
		end
	end)
	no.Activated:Connect(function()
		card.Visible = false
		if cardKind == "invite" then
			remote:FireServer(Messages.Party.Decline)
		end
	end)

	ContextActionService:BindAction(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			panel.Visible = not panel.Visible
			if not panel.Visible then
				picker.Visible = false
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Config.Keys.Party)

	remote.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if kind == Messages.Party.State then
			current = a :: View
			render()
			for _, listener in listeners do
				task.spawn(listener, a)
			end
		elseif kind == Messages.Party.Invited then
			showCard(
				"invite",
				`{b} invited you to their squad.`,
				"ACCEPT",
				"DECLINE",
				tonumber(c) or 60
			)
		elseif kind == Messages.Party.Follow then
			showCard(
				"follow",
				`{a} invited you. They're on another Carrier: fly over?`,
				"FLY OVER",
				"STAY",
				60
			)
		elseif kind == Messages.Party.Notice then
			panel.Visible = true
			say(tostring(a))
		end
	end)
	Players.PlayerAdded:Connect(function()
		if picker.Visible then
			fillPicker()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if picker.Visible then
			task.defer(fillPicker)
		end
	end)

	HudTheme.parent(gui)
end

return PartyUI
