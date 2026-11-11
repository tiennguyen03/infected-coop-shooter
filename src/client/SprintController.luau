--!strict
-- Hold LeftShift to sprint. WalkSpeed is set locally; the character is
-- client-owned so this takes effect immediately without replication. Aiming down sights
-- (WeaponController) overrides sprint and slows the walk by the gun's AdsMoveFactor;
-- a stance (StanceController) scales the walk and may forbid sprinting.
--
-- Stamina lives here too (Rules/Stamina, Config.Stamina): sprinting while moving drains it,
-- a roll or slide spends a cost (MovementController), and a winded body cannot sprint until
-- it recovers. Client-owned and client-trusted, like the WalkSpeed itself. StaminaUI reads it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RunStates = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RunStates"))
local Stamina =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Stamina"))
local WeaponDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))

local SprintController = {}

local isSprinting = false
local isAiming = false
local stanceFactor = 1
local sprintAllowed = true
local overrideSpeed: number? = nil -- a roll or slide (MovementController) owns the speed
local stamina = Stamina.new(Config.Stamina)

local function getHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- The speed sprint, stance and ADS give the body when no roll or slide owns it.
function SprintController.getBaseSpeed(): number
	local base = if SprintController.isSprinting()
		then Config.Player.SprintSpeed
		else Config.Player.WalkSpeed
	local mult = (Players.LocalPlayer:GetAttribute(Attributes.MoveSpeedMult) :: number?) or 1
	if isAiming then
		mult *= WeaponDefinitions.get(
			Players.LocalPlayer:GetAttribute(Attributes.Weapon) :: string?
		).AdsMoveFactor
	end
	return base * mult * stanceFactor
end

local function applySpeed()
	local humanoid = getHumanoid()
	local character = Players.LocalPlayer.Character
	if humanoid and character and character:GetAttribute(Attributes.KnockedUntil) ~= nil then
		humanoid.WalkSpeed = 0 -- knocked down (Squad.knock): on the ground until the get-up
	elseif humanoid and character and character:GetAttribute(Attributes.SquadState) == "Downed" then
		humanoid.WalkSpeed = Config.Downed.CrawlSpeed -- downed (Squad): crawl toward help
	elseif humanoid and overrideSpeed then
		humanoid.WalkSpeed = overrideSpeed
	elseif humanoid then
		humanoid.WalkSpeed = SprintController.getBaseSpeed()
	end
end

local function setSprinting(sprinting: boolean)
	isSprinting = sprinting
	applySpeed()
end

function SprintController.setAiming(aiming: boolean)
	isAiming = aiming
	applySpeed()
end

-- A stance scales the walk; sprint is only possible standing.
function SprintController.setStanceFactor(factor: number, canSprint: boolean)
	stanceFactor = factor
	sprintAllowed = canSprint
	applySpeed()
end

-- A roll or slide sets the body's speed outright; nil hands it back to sprint/stance/ADS.
function SprintController.setOverrideSpeed(speed: number?)
	if speed == overrideSpeed then
		return
	end
	overrideSpeed = speed
	applySpeed()
end

function SprintController.isSprinting(): boolean
	return isSprinting
		and sprintAllowed
		and not isAiming
		and Players.LocalPlayer:GetAttribute(Attributes.Carrying) ~= true
		and Stamina.canSprint(stamina)
end

-- A roll or slide pays its cost here. False (and nothing taken) when the body is winded.
function SprintController.spendStamina(cost: number): boolean
	local spent = Stamina.spend(stamina, cost)
	if spent and stamina.winded then
		applySpeed()
	end
	return spent
end

-- For the bar: how full (0..1) and whether the body is winded.
function SprintController.getStamina(): (number, boolean)
	return Stamina.fraction(stamina, Config.Stamina), stamina.winded
end

-- Sprint drains only while it is really carrying the body: moving, on its feet, and not in
-- a roll or slide (those paid on entry).
local function stepStamina(dt: number)
	local draining = false
	if overrideSpeed == nil and SprintController.isSprinting() then
		local character = Players.LocalPlayer.Character
		local humanoid = getHumanoid()
		draining = character ~= nil
			and humanoid ~= nil
			and humanoid.MoveDirection.Magnitude > 0.1
			and humanoid.RootPart ~= nil
			and not humanoid.RootPart.Anchored -- a vault or climb carries the body: free
			and character:GetAttribute(Attributes.KnockedUntil) == nil
			and character:GetAttribute(Attributes.SquadState) ~= "Downed"
	end
	local wasWinded = stamina.winded
	Stamina.step(stamina, dt, draining, Config.Stamina)
	if stamina.winded ~= wasWinded then
		applySpeed() -- winded drops to a walk; recovered picks the sprint back up if held
	end
end

function SprintController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftShift then
			setSprinting(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			setSprinting(false)
		end
	end)

	-- A respawned character starts at base speed even if Shift is held. The body that
	-- already exists at boot gets the downed hook too.
	local player = Players.LocalPlayer
	if player.Character then
		player.Character:GetAttributeChangedSignal(Attributes.SquadState):Connect(applySpeed)
		player.Character:GetAttributeChangedSignal(Attributes.KnockedUntil):Connect(applySpeed)
	end
	player.CharacterAdded:Connect(function(character)
		character:GetAttributeChangedSignal(Attributes.SquadState):Connect(applySpeed)
		character:GetAttributeChangedSignal(Attributes.KnockedUntil):Connect(applySpeed)
		isAiming = false
		overrideSpeed = nil
		stanceFactor = 1
		sprintAllowed = true
		Stamina.refill(stamina, Config.Stamina)
		setSprinting(false)
	end)

	-- A new run (the ready-up or the insert) starts on a full bar.
	workspace:GetAttributeChangedSignal(Attributes.RunState):Connect(function()
		local state = RunStates.current()
		if state == "Lobby" or state == "Insert" then
			Stamina.refill(stamina, Config.Stamina)
			applySpeed()
		end
	end)
	RunService.Heartbeat:Connect(stepStamina)

	-- Items/buffs can change the multiplier mid-run; reapply immediately.
	Players.LocalPlayer:GetAttributeChangedSignal(Attributes.MoveSpeedMult):Connect(applySpeed)
	Players.LocalPlayer:GetAttributeChangedSignal(Attributes.Weapon):Connect(applySpeed)
	-- Carrying an objective item (the screening record): the carrier walks.
	Players.LocalPlayer:GetAttributeChangedSignal(Attributes.Carrying):Connect(applySpeed)
end

return SprintController
