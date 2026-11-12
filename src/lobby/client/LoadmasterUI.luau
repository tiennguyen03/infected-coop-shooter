--!strict
-- The Loadmaster's desk (docs/sprints/LOBBY_V1_FALLOW.md > Loadmaster and Loadout): talk to
-- him (F) and choose, by click or the keys 1-3. "Make up my Loadout." opens the Loadout
-- (LoadoutMenu, the match's menu with the lobby's words): primary, sidearm, grenade and up
-- to four call-ins. SIGN FOR IT sends it to LoadmasterService, which checks it with the
-- match's rules; once signed it rides the Lantern into the match (Rules/Handoff). The
-- soldier is held still while the Loadout is open; Back or Backspace steps out.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)
local KitPrices = require(ReplicatedStorage.Shared.KitPrices)
local DeskShop = require(script.Parent.DeskShop)
local GunsmithUI = require(script.Parent.GunsmithUI)
local HoldStill = require(script.Parent.HoldStill)
local HudTheme = require(script.Parent.HudTheme)
local LoadoutMenu = require(script.Parent.LoadoutMenu)
local RecordClient = require(script.Parent.RecordClient)

local LoadmasterUI = {}

local ACTION_CHOOSE = "LoadmasterChoose"
local ACTION_BACK = "LoadmasterBack"
local CHOICE_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
}
local choiceKeyList: { Enum.KeyCode } = {}
for key in CHOICE_KEYS do
	table.insert(choiceKeyList, key)
end

type Mode = "closed" | "talk" | "loadout"

local player = Players.LocalPlayer
local mode: Mode = "closed"
local desk: LobbyDesks.Desk? = nil
local prompt: ProximityPrompt? = nil
local talkCloseAt = 0
local signed: Loadout.Loadout? = nil -- the last Loadout the server accepted
local pending: Loadout.Loadout? = nil -- sent, waiting for the answer
local menu: LoadoutMenu.Handle? = nil
local remote: RemoteEvent

-- --------------------------------------------------------------- the talk panel
local gui = HudTheme.gui("LoadmasterUI", 7)

local function button(parent: Instance, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 40)
	b.BackgroundColor3 = HudTheme.Color.Track
	b.BackgroundTransparency = HudTheme.TrackTransparency
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = HudTheme.Font.Line
	b.TextSize = 18
	b.TextColor3 = HudTheme.Color.Text
	b.TextXAlignment = Enum.TextXAlignment.Left
	local stroke = Instance.new("UIStroke")
	stroke.Color = HudTheme.Color.White
	stroke.Transparency = HudTheme.OutlineTransparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 14)
	inset.Parent = b
	b.Parent = parent
	return b
end

local talk = HudTheme.rect(
	gui,
	UDim2.fromOffset(560, 0),
	HudTheme.Color.Track,
	HudTheme.TrackTransparency,
	true
)
talk.AnchorPoint = Vector2.new(0.5, 1)
talk.Position = UDim2.new(0.5, 0, 1, -200)
talk.AutomaticSize = Enum.AutomaticSize.Y
talk.Visible = false
do
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = talk
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = talk
end
local talkTitle = HudTheme.label(
	talk,
	{ size = 22, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow, rich = true }
)
talkTitle.LayoutOrder = 1
local talkLine = HudTheme.label(talk, { size = 18, font = HudTheme.Font.Body })
talkLine.LayoutOrder = 2
talkLine.AutomaticSize = Enum.AutomaticSize.Y
talkLine.Size = UDim2.fromScale(1, 0)
talkLine.TextWrapped = true
local choices = { button(talk, 528), button(talk, 528), button(talk, 528) }
for index, choice in choices do
	choice.LayoutOrder = 2 + index
end
HudTheme.parent(gui)

-- The Loadout sits in its own layer above the talk panel.
local menuGui = HudTheme.gui("LoadmasterLoadout", 8)
HudTheme.parent(menuGui)

-- --------------------------------------------------------------- modes
local choose: (number) -> ()

local function chooseAction(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		choose(CHOICE_KEYS[input.KeyCode] or 0)
	end
	return Enum.ContextActionResult.Sink
end

local function showTalk(line: string)
	talkLine.Text = `"{line}"`
	talkCloseAt = os.clock() + Config.Lobby.DialogSeconds * 3
end

local function closeTalk()
	ContextActionService:UnbindAction(ACTION_CHOOSE)
	DeskShop.hide()
	if mode == "talk" then
		mode = "closed"
		talk.Visible = false
		choices[3].Modal = false
	end
end

local function openTalk(chosen: LobbyDesks.Desk, from: ProximityPrompt, line: string?)
	local kit = chosen.kit
	if not kit then
		return
	end
	desk = chosen
	prompt = from
	mode = "talk"
	talkTitle.Text = `{chosen.title}  {HudTheme.tint(chosen.who, HudTheme.Color.TextDim)}`
	local said = chosen.talk
	choices[1].Text = `1.  {said.open}`
	choices[2].Text = `2.  {said.ask}`
	choices[3].Text = `3.  {said.leave}`
	showTalk(line or said.greetings[math.random(1, #said.greetings)])
	talk.Visible = true
	choices[3].Modal = true -- frees the mouse even zoomed into first person
	ContextActionService:BindAction(ACTION_CHOOSE, chooseAction, false, table.unpack(choiceKeyList))
end

local function closeLoadout(line: string?)
	ContextActionService:UnbindAction(ACTION_BACK)
	if menu then
		menu.destroy()
		menu = nil
	end
	pending = nil
	HoldStill.set(false)
	if prompt then
		prompt.Enabled = true
	end
	mode = "closed"
	local chosen, from = desk, prompt
	if chosen and from then
		openTalk(chosen, from, line)
	end
end

local function backAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and mode == "loadout" then
		closeLoadout(nil)
	end
	return Enum.ContextActionResult.Sink
end

local function openLoadout()
	local kit = desk and desk.kit
	if not kit then
		return
	end
	closeTalk()
	mode = "loadout"
	HoldStill.set(true)
	if prompt then
		prompt.Enabled = false
	end
	local handle = LoadoutMenu.mount(menuGui, function(loadout: Loadout.Loadout)
		pending = loadout
		remote:FireServer(Messages.Loadout.Request, loadout)
	end, {
		title = kit.header,
		hint = "CLICK TO PICK   ·   CALL-INS FILL KEYS 1-4 IN ORDER   ·   [BACKSPACE] STEP AWAY",
		confirm = kit.confirm,
		-- Only guns on the record (bought at the Quartermaster's rack, or issued free).
		locked = function(id: string): string?
			if RecordClient.owns(id) then
				return nil
			end
			local price = RecordClient.priceOf(id)
			return if price then `{price} MERITS` else "NOT FOR ISSUE"
		end,
		-- EDIT on a gun: what goes on it (GunsmithUI), signed with the rest.
		edit = function(gunId, fitted, done)
			GunsmithUI.open(menuGui, gunId, fitted, done)
		end,
	})
	if signed then
		handle.set(signed)
	end
	handle.status((desk :: LobbyDesks.Desk).talk.openLine, nil)
	local back = Instance.new("TextButton")
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(1, 0)
	back.Position = UDim2.new(1, -24, 0, 16)
	back.Size = UDim2.fromOffset(120, 36)
	back.BackgroundColor3 = HudTheme.Color.Track
	back.BorderSizePixel = 0
	back.Font = HudTheme.Font.Headline
	back.TextSize = 16
	back.TextColor3 = HudTheme.Color.Text
	back.Text = "BACK"
	back.Modal = true -- frees the mouse while the Loadout is open
	back.Parent = handle.frame
	back.Activated:Connect(function()
		if mode == "loadout" then
			closeLoadout(nil)
		end
	end)
	menu = handle
	ContextActionService:BindAction(
		ACTION_BACK,
		backAction,
		false,
		Enum.KeyCode.Backspace,
		Enum.KeyCode.ButtonB
	)
end

function choose(index: number)
	if mode ~= "talk" then
		return
	end
	if index == 1 then
		openLoadout()
	elseif index == 2 and desk then
		showTalk(desk.talk.answer)
		-- What Lantern kicks is sold here (the call-in rows' `Desk` = "loadmaster").
		local sells = KitPrices.soldAt("loadmaster")
		if #sells > 0 then
			DeskShop.show(desk.title, sells, desk.talk)
			talkCloseAt = math.huge -- stays up while you shop; walking off still closes it
		end
	elseif index == 3 then
		closeTalk()
	end
end

-- --------------------------------------------------------------- wiring
function LoadmasterUI.init()
	remote = Remotes.get("Loadout")
	local byId: { [string]: LobbyDesks.Desk } = {}
	for _, entry in LobbyDesks do
		byId[entry.id] = entry
	end

	ProximityPromptService.PromptTriggered:Connect(function(triggered: ProximityPrompt, who: Player)
		if who ~= player or mode == "loadout" then
			return
		end
		-- One dialog at a time: another desk closes this one.
		closeTalk()
		local id = triggered:GetAttribute(Attributes.DeskId)
		local chosen = if type(id) == "string" then byId[id] else nil
		if chosen and chosen.kit then
			openTalk(chosen, triggered, nil)
		end
	end)

	for index, choice in choices do
		choice.Activated:Connect(function()
			choose(index)
		end)
	end

	remote.OnClientEvent:Connect(function(kind: string, ok: any, reason: string?)
		-- The Loadout kept from a past visit (LoadmasterService): the screen opens on it.
		if kind == Messages.Loadout.Signed and typeof(ok) == "table" then
			signed = ok :: Loadout.Loadout
			return
		end
		if kind ~= Messages.Loadout.Result or mode ~= "loadout" or not pending then
			return
		end
		local kit = desk and desk.kit
		if ok then
			signed = pending
			closeLoadout(if kit then kit.confirmLine else nil)
		elseif menu and kit then
			pending = nil
			local line = if reason == "not on record" then kit.notOnRecord else kit.reject
			menu.status(`{line} ({reason or "refused"})`, false)
		end
	end)

	RecordClient.Changed:Connect(function()
		if menu then
			menu.refresh()
		end
	end)

	-- The talk panel closes when you walk off or wait; a respawn leaves the Loadout.
	RunService.Heartbeat:Connect(function()
		if mode ~= "talk" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local anchor = prompt and prompt.Parent
		local tooFar = root ~= nil
			and anchor ~= nil
			and anchor:IsA("BasePart")
			and (root.Position - anchor.Position).Magnitude
				> Config.Lobby.DeskPromptDistance * 1.5
		if tooFar or os.clock() >= talkCloseAt then
			closeTalk()
		end
	end)
	player.CharacterRemoving:Connect(function()
		if mode == "loadout" then
			closeLoadout(nil)
		end
		closeTalk()
	end)
end

return LoadmasterUI
