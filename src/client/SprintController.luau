--!strict
-- Hold LeftShift to sprint. WalkSpeed is set locally; the character is
-- client-owned so this takes effect immediately without replication. Aiming down sights
-- (WeaponController) overrides sprint and slows the walk by the gun's AdsMoveFactor;
-- a stance (StanceController) scales the walk and may forbid sprinting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WeaponDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))

local SprintController = {}

local isSprinting = false
local isAiming = false
local stanceFactor = 1
local sprintAllowed = true
local overrideSpeed: number? = nil -- a roll or slide (MovementController) owns the speed

local function getHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
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
		local base = if isSprinting
				and sprintAllowed
				and not isAiming
			then Config.Player.SprintSpeed
			else Config.Player.WalkSpeed
		local mult = (Players.LocalPlayer:GetAttribute(Attributes.MoveSpeedMult) :: number?) or 1
		if isAiming then
			mult *= WeaponDefinitions.get(
				Players.LocalPlayer:GetAttribute(Attributes.Weapon) :: string?
			).AdsMoveFactor
		end
		mult *= stanceFactor
		humanoid.WalkSpeed = base * mult
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
	overrideSpeed = speed
	applySpeed()
end

function SprintController.isSprinting(): boolean
	return isSprinting and sprintAllowed and not isAiming
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
		setSprinting(false)
	end)

	-- Items/buffs can change the multiplier mid-run; reapply immediately.
	Players.LocalPlayer:GetAttributeChangedSignal(Attributes.MoveSpeedMult):Connect(applySpeed)
	Players.LocalPlayer:GetAttributeChangedSignal(Attributes.Weapon):Connect(applySpeed)
end

return SprintController
