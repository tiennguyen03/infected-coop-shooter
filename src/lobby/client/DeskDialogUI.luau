--!strict
-- Talking to Fires or the Engineers (DeskService, LobbyDesks; the Quartermaster and the
-- Loadmaster have their own screens, ArmsRackUI and LoadmasterUI). F on the desk's prompt opens
-- the same talk as every desk: a greeting picked at random, then 1 their kit (the DeskShop with
-- what the desk sells, KitPrices.soldAt: the call-in rows' `Desk`), 2 a question, 3 leave; by
-- click or the keys 1-3. It stays up while you stand there (Config.Lobby.DialogSeconds x3 after
-- the last choice, unless the shop is open) and closes when you walk out of reach.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local KitPrices = require(ReplicatedStorage.Shared.KitPrices)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)
local DeskShop = require(script.Parent.DeskShop)
local HoldStill = require(script.Parent.HoldStill)
local HudTheme = require(script.Parent.HudTheme)

local DeskDialogUI = {}

local ACTION_CHOOSE = "DeskDialogChoose"
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

function DeskDialogUI.init()
	local byId: { [string]: LobbyDesks.Desk } = {}
	for _, desk in LobbyDesks do
		byId[desk.id] = desk
	end

	local gui = HudTheme.gui("DeskDialogUI", 6)
	local panel = HudTheme.rect(
		gui,
		UDim2.fromOffset(560, 0),
		HudTheme.Color.Track,
		HudTheme.TrackTransparency,
		true
	)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -200)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = panel

	local title = HudTheme.label(
		panel,
		{ size = 22, font = HudTheme.Font.Headline, color = HudTheme.Color.Yellow, rich = true }
	)
	title.LayoutOrder = 1
	local line = HudTheme.label(panel, { size = 18, font = HudTheme.Font.Body })
	line.LayoutOrder = 2
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Size = UDim2.fromScale(1, 0)
	line.TextWrapped = true
	local choices = { button(panel, 528), button(panel, 528), button(panel, 528) }
	for index, choice in choices do
		choice.LayoutOrder = 2 + index
	end
	HudTheme.parent(gui)

	-- The Plot's map view: the camera looks down on the paper map (WorldMap's sheet) from the
	-- door side while the watch officer talks; leaving gives the camera back.
	local viewing = false
	local function viewMap()
		local sheet = Workspace:FindFirstChild("WorldMapSheet", true)
		local camera = Workspace.CurrentCamera
		if viewing or not (sheet and sheet:IsA("BasePart")) or not camera then
			return
		end
		viewing = true
		HoldStill.set(true)
		camera.CameraType = Enum.CameraType.Scriptable
		local goal = CFrame.lookAt(sheet.Position + Vector3.new(-4.5, 12.5, 0), sheet.Position)
		TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { CFrame = goal })
			:Play()
	end
	local function leaveMap()
		if not viewing then
			return
		end
		viewing = false
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
		HoldStill.set(false)
	end

	local desk: LobbyDesks.Desk? = nil
	local openPrompt: ProximityPrompt? = nil
	local closeAt = 0

	local function say(text: string)
		line.Text = `"{text}"`
		closeAt = os.clock() + Config.Lobby.DialogSeconds * 3
	end

	local function close()
		ContextActionService:UnbindAction(ACTION_CHOOSE)
		panel.Visible = false
		choices[3].Modal = false
		desk = nil
		openPrompt = nil
		DeskShop.hide()
		leaveMap()
	end

	local function choose(index: number)
		local current = desk
		if not current or not panel.Visible then
			return
		end
		if index == 1 then
			say(current.talk.openLine)
			if current.id == "plot" then
				viewMap()
				closeAt = math.huge -- stays up while you read the map
			end
			local sells = KitPrices.soldAt(current.id)
			if #sells > 0 then
				DeskShop.show(current.title, sells, current.talk)
				closeAt = math.huge -- stays up while you shop; walking off still closes it
			end
		elseif index == 2 then
			say(current.talk.answer)
		elseif index == 3 then
			close()
		end
	end

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

	for index, choice in choices do
		choice.Activated:Connect(function()
			choose(index)
		end)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= Players.LocalPlayer then
			return
		end
		local id = prompt:GetAttribute(Attributes.DeskId)
		local chosen = if type(id) == "string" then byId[id] else nil
		-- One dialog at a time: any desk closes this one; a desk with a rack or a kit talks
		-- through its own screen (ArmsRackUI, LoadmasterUI).
		close()
		if not chosen or chosen.rack or chosen.kit then
			return
		end
		desk = chosen
		openPrompt = prompt
		local talk = chosen.talk
		title.Text = `{chosen.title}  {HudTheme.tint(chosen.who, HudTheme.Color.TextDim)}`
		choices[1].Text = `1.  {talk.open}`
		choices[2].Text = `2.  {talk.ask}`
		choices[3].Text = `3.  {talk.leave}`
		say(talk.greetings[math.random(1, #talk.greetings)])
		panel.Visible = true
		choices[3].Modal = true -- frees the mouse even zoomed into first person
		ContextActionService:BindAction(
			ACTION_CHOOSE,
			chooseAction,
			false,
			table.unpack(choiceKeyList)
		)
	end)

	RunService.Heartbeat:Connect(function()
		if not panel.Visible then
			return
		end
		local tooFar = false
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local anchor = openPrompt and openPrompt.Parent
		if root and anchor and anchor:IsA("BasePart") then
			tooFar = (root.Position - anchor.Position).Magnitude
				> Config.Lobby.DeskPromptDistance * 1.5
		end
		if tooFar or os.clock() >= closeAt then
			close()
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(close)
end

return DeskDialogUI
