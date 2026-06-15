--!strict
-- Applies configured stats to every player character on spawn.
-- Death/respawn is handled by the default Humanoid lifecycle for now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerSetup = {}

-- Simple part-built rifle held at the right hip, pointing forward. The
-- character's yaw always follows the camera, so the barrel tracks the aim
-- direction. WeaponController fires from the part named "Muzzle".
local function attachRifle(character: Model, root: BasePart)
	local rifle = Instance.new("Model")
	rifle.Name = "Rifle"

	local function riflePart(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?
	): BasePart
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = root.CFrame * offset
		part.Color = color
		part.Material = material or Enum.Material.Metal
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = rifle
		return part
	end

	local grip = CFrame.new(1.05, -0.35, -0.4)
	riflePart("Body", Vector3.new(0.32, 0.45, 1.5), grip, Color3.fromRGB(62, 66, 70))
	riflePart(
		"Barrel",
		Vector3.new(0.16, 0.16, 1.1),
		grip * CFrame.new(0, 0.1, -1.25),
		Color3.fromRGB(40, 42, 45)
	)
	riflePart(
		"Stock",
		Vector3.new(0.28, 0.38, 0.7),
		grip * CFrame.new(0, -0.05, 1.05),
		Color3.fromRGB(82, 64, 42),
		Enum.Material.Wood
	)
	riflePart(
		"Grip",
		Vector3.new(0.22, 0.4, 0.24),
		grip * CFrame.new(0, -0.4, 0.25),
		Color3.fromRGB(40, 42, 45)
	)
	riflePart(
		"Muzzle",
		Vector3.new(0.2, 0.2, 0.14),
		grip * CFrame.new(0, 0.1, -1.85),
		Color3.fromRGB(28, 28, 28)
	)

	rifle.Parent = character
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = Config.Player.WalkSpeed

	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	attachRifle(character, root)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

function PlayerSetup.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerSetup
