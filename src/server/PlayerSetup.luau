--!strict
-- Applies configured stats to every player character on spawn.
-- Death/respawn is handled by the default Humanoid lifecycle for now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)

local PlayerSetup = {}

-- Rifle as a real held Tool. Equipping a Tool welds its Handle into the right
-- hand AND triggers the default hold pose (the arm is raised), so it reads as a
-- weapon the character is holding rather than a part stuck to a lowered hand.
-- The invisible Handle is the grip; the visible parts are welded to it, laid
-- out so the trigger/grip sits in the palm and the barrel points forward (-Z).
-- WeaponController fires from the part named "Muzzle" (a child of the Tool).
local function clearExistingRifles(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child.Name == "Rifle" then
			child:Destroy()
		end
	end
	local player = Players:GetPlayerFromCharacter(character)
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child.Name == "Rifle" then
				child:Destroy()
			end
		end
	end
end

local function attachRifle(character: Model, humanoid: Humanoid)
	-- Never leave a stray rifle behind (avoids duplicates across respawns).
	clearExistingRifles(character)

	local tool = Instance.new("Tool")
	tool.Name = "Rifle"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool

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
		part.CFrame = handle.CFrame * offset
		part.Color = color
		part.Material = material or Enum.Material.Metal
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = tool
		return part
	end

	-- Handle-local layout: grip at the origin (the palm), barrel along -Z.
	-- waitFor: the first character spawns before the boot-time template build finishes.
	local body = MeshAssets.waitFor("wpn_rifle", 5)
	if body then
		-- Low-poly rifle mesh (assets/3d wpn_rifle, 0.65x). The mesh pivot is the grip; the
		-- MeshPart is centred on its bounding box, so offset by the mesh's centre-from-grip.
		body.Name = "Body"
		body.Anchored = false
		body.Massless = true
		body.CFrame = handle.CFrame * CFrame.new(0, 0.185, -0.54)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = body
		weld.Parent = body
		body.Parent = tool
		-- Invisible muzzle marker at the barrel tip (WeaponController fires from it).
		local muzzle = riflePart(
			"Muzzle",
			Vector3.new(0.2, 0.2, 0.14),
			CFrame.new(0, 0.42, -1.95),
			Color3.new()
		)
		muzzle.Transparency = 1
	else
		-- Placeholder rifle from Parts when the mesh template is missing.
		riflePart(
			"Body",
			Vector3.new(0.34, 0.46, 1.5),
			CFrame.new(0, 0.2, -0.1),
			Color3.fromRGB(62, 66, 70)
		)
		riflePart(
			"Barrel",
			Vector3.new(0.16, 0.16, 1),
			CFrame.new(0, 0.28, -1.05),
			Color3.fromRGB(40, 42, 45)
		)
		riflePart(
			"Muzzle",
			Vector3.new(0.2, 0.2, 0.14),
			CFrame.new(0, 0.28, -1.6),
			Color3.fromRGB(28, 28, 28)
		)
		riflePart(
			"Stock",
			Vector3.new(0.28, 0.4, 0.7),
			CFrame.new(0, 0.06, 0.78),
			Color3.fromRGB(82, 64, 42),
			Enum.Material.Wood
		)
		riflePart(
			"TriggerGrip",
			Vector3.new(0.2, 0.42, 0.24),
			CFrame.new(0, -0.18, 0.1),
			Color3.fromRGB(40, 42, 45)
		)
		riflePart(
			"Foregrip",
			Vector3.new(0.16, 0.34, 0.2),
			CFrame.new(0, -0.06, -0.6),
			Color3.fromRGB(40, 42, 45)
		)
	end

	-- Seat the rifle in the hand. Tilt the grip so the barrel rides level/up
	-- against the default hold pose. (First-pass — tune in Studio if needed.)
	tool.Grip = CFrame.Angles(math.rad(-12), 0, 0)

	-- Parenting the Tool to the character equips it.
	tool.Parent = character

	-- Keep it equipped: re-equip if the player unequips via hotbar / number key.
	tool.Unequipped:Connect(function()
		if tool.Parent and character.Parent and humanoid.Health > 0 then
			tool.Parent = character
		end
	end)
	-- Destroy it on death so it can't linger in the backpack and duplicate.
	humanoid.Died:Connect(function()
		tool:Destroy()
	end)
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = Config.Player.WalkSpeed

	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("RightHand")
	attachRifle(character, humanoid)
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
