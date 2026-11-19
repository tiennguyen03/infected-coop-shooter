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
local DeskTalk = require(script.Parent.DeskTalk)
local GunsmithUI = require(script.Parent.GunsmithUI)
local KitModsTab = require(script.Parent.KitModsTab)
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
local kitTab: KitModsTab.Tab? = nil -- the KIT MODS tab over the Loadout (KitModsTab)
local remote: RemoteEvent

-- --------------------------------------------------------------- the talk panel
local gui = HudTheme.gui("LoadmasterUI", 7)

-- Talk: the same panel at every desk (DeskTalk).
local talkPanel = DeskTalk.new(gui)
local talk = talkPanel.frame
local choices = talkPanel.choices
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
	talkPanel.say(line)
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
	local said = chosen.talk
	talkPanel.show(chosen)
	showTalk(line or said.greetings[math.random(1, #said.greetings)])
	talk.Visible = true
	choices[3].Modal = true -- frees the mouse even zoomed into first person
	ContextActionService:BindAction(ACTION_CHOOSE, chooseAction, false, table.unpack(choiceKeyList))
end

local function closeLoadout(line: string?)
	ContextActionService:UnbindAction(ACTION_BACK)
	if kitTab then
		kitTab.destroy()
		kitTab = nil
	end
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
		hint = "POINT TO LOOK, CLICK TO PICK   ·   CALL-INS FILL KEYS 1-4 IN ORDER   ·   [ENTER] SIGN   ·   [BACKSPACE] STEP AWAY",
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
	back.Size = UDim2.fromOffset(120, 36) -- design pixels: LoadoutMenu scales its frame to the screen
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

	-- LOADOUT | KIT MODS: the Loadout screen's own tab buttons, left of BACK (design pixels).
	local frameSize = handle.frame.Size
	local W, H = frameSize.X.Offset, frameSize.Y.Offset
	local tab = KitModsTab.mount(handle.frame, W, H, if W >= 1200 then 28 else 18)
	kitTab = tab
	local tabButtons: { TextButton } = {}
	local function showTab(index: number)
		tab.show(index == 2)
		for i, button in tabButtons do
			local on = i == index
			button.BackgroundColor3 = if on then HudTheme.Color.MenuSelect else HudTheme.Color.Track
			button.BackgroundTransparency = if on then 0 else 0.35
			button.TextColor3 = if on then HudTheme.Color.MenuSelectText else HudTheme.Color.Text
		end
	end
	local TAB_W = 150
	for index, label in { "LOADOUT", "KIT MODS" } do
		local button = Instance.new("TextButton")
		button.Name = `Tab{index}`
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Size = UDim2.fromOffset(TAB_W, 36)
		button.Position = UDim2.fromOffset(W - 24 - 120 - 12 - (3 - index) * (TAB_W + 6), 16)
		button.Font = HudTheme.Font.Line
		button.TextSize = 15
		button.Text = label
		button.Parent = handle.frame
		button.Activated:Connect(function()
			showTab(index)
		end)
		table.insert(tabButtons, button)
	end
	showTab(1)

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
