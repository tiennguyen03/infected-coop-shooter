--!strict
-- Talking to the Call-ins, Vehicles and Plot desks (DeskService, LobbyDesks; the Quartermaster
-- and the Loadmaster have their own hosts, ArmsRackUI and LoadmasterUI). F on the desk's prompt
-- opens the same talk as every desk (DeskTalk): a greeting picked at random, then 1 their kit
-- (the desk screen, DeskScreen, with what the desk sells, KitPrices: each row's `Desk` or the
-- default; Back returns here), 2 a question, 3 leave; by click or the keys 1-3. With
-- Config.Lobby.DeskScreen off, 1 opens the old views (CallInDisplayUI, DeskShop). It stays up while you stand there (Config.Lobby.DialogSeconds x3 after
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
local CallInDisplayUI = require(script.Parent.CallInDisplayUI)
local DeskScreen = require(script.Parent.DeskScreen)
local DeskShop = require(script.Parent.DeskShop)
local DeskTalk = require(script.Parent.DeskTalk)
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

function DeskDialogUI.init()
	local byId: { [string]: LobbyDesks.Desk } = {}
	for _, desk in LobbyDesks do
		byId[desk.id] = desk
	end

	local gui = HudTheme.gui("DeskDialogUI", 6)
	local talk = DeskTalk.new(gui)
	local panel = talk.frame
	local choices = talk.choices
	HudTheme.parent(gui)

	-- The Plot's map view: the camera looks down on the paper map (WorldMap's sheet) from the
	-- door side while the watch officer talks; leaving gives the camera back. The talk panel
	-- moves to the left edge and the map to the right of the screen, so neither covers the
	-- other (Nova, 2026-11-10: the dialog was in the way of the map).
	local PANEL_ANCHOR, PANEL_AT = panel.AnchorPoint, panel.Position
	local MAP_SHIFT = 5 -- studs the camera slides left so the map sits right of the panel
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
		goal -= goal.RightVector * MAP_SHIFT
		panel.AnchorPoint = Vector2.new(0, 0.5)
		panel.Position = UDim2.new(0, HudTheme.Margin * 2, 0.5, 0)
		TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { CFrame = goal })
			:Play()
	end
	local function leaveMap()
		if not viewing then
			return
		end
		viewing = false
		panel.AnchorPoint = PANEL_ANCHOR
		panel.Position = PANEL_AT
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
		talk.say(text)
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

	local openTalk: (chosen: LobbyDesks.Desk, prompt: ProximityPrompt) -> ()

	local function choose(index: number)
		local current = desk
		if not current or not panel.Visible then
			return
		end
		if index == 1 then
			-- A desk that hands out kit opens its screen (Back comes back to this talk).
			local from = openPrompt
			if
				DeskScreen.open(current, from, function()
					if from then
						openTalk(current, from)
					end
				end)
			then
				close()
				return
			end
			-- A desk with a display (Call-ins) shows its kit laid out behind it; the list is the
			-- fallback while the display is not built.
			if current.display and from and CallInDisplayUI.open(current, from) then
				close()
				return
			end
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

	function openTalk(chosen: LobbyDesks.Desk, prompt: ProximityPrompt)
		desk = chosen
		openPrompt = prompt
		local said = chosen.talk
		talk.show(chosen)
		say(said.greetings[math.random(1, #said.greetings)])
		panel.Visible = true
		choices[3].Modal = true -- frees the mouse even zoomed into first person
		ContextActionService:BindAction(
			ACTION_CHOOSE,
			chooseAction,
			false,
			table.unpack(choiceKeyList)
		)
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
		-- One dialog at a time: any desk closes this one (and its screen); a desk with a rack or a kit talks
		-- through its own screen (ArmsRackUI, LoadmasterUI).
		close()
		DeskScreen.close()
		if not chosen or chosen.rack or chosen.kit then
			return
		end
		openTalk(chosen, prompt)
	end)

	RunService.Heartbeat:Connect(function()
		if not panel.Visible then
			return
		end
		local tooFar = false
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local anchor = openPrompt and openPrompt.Parent
		if root and anchor and anchor:IsA("BasePart") and openPrompt then
			-- Each desk's own reach (the watch officer's spans her map table).
			tooFar = (root.Position - anchor.Position).Magnitude
				> openPrompt.MaxActivationDistance * 1.5
		end
		if tooFar or os.clock() >= closeAt then
			close()
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(close)
end

return DeskDialogUI
