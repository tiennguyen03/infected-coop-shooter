--!strict
-- Applies configured stats to every player character on spawn.
-- Death/respawn is handled by the default Humanoid lifecycle for now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local AvatarLook = require(ReplicatedStorage.Shared.AvatarLook)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

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

function PlayerSetup.attachRifle(character: Model, humanoid: Humanoid)
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

	-- Handle-local layout: grip at the origin (the palm), barrel along -Z. The gun in hand
	-- names its mesh (Config.Weapons.<id>.Model); the placeholder Parts stand in until the
	-- mesh loads (waitFor: the first character spawns before the boot-time template build).
	local function placeholder()
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
	end
	-- Swaps the visible gun for `model`'s mesh, the Muzzle at its barrel tip (WeaponController
	-- fires from it). Keeps whatever is there when the mesh never loads.
	local function dress(wanted: string)
		-- A gun whose mesh is not uploaded yet wears the rifle.
		local model = if MeshAssets.isUploaded(wanted) then wanted else "wpn_rifle"
		local body = MeshAssets.waitFor(model, 5)
		if not body or not tool.Parent and not handle.Parent then
			return
		end
		for _, child in tool:GetChildren() do
			if child ~= handle and child:IsA("BasePart") then
				child:Destroy()
			end
		end
		body.Name = "Body"
		body.Anchored = false
		body.Massless = true
		body.CFrame = handle.CFrame * CFrame.new(MeshAssets.getOffset(model))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = body
		weld.Parent = body
		body.Parent = tool
		local size = MeshAssets.getSize(model) or Vector3.zero
		local muzzleAt = MeshAssets.getMuzzle(model) or Vector3.new(0, 0, -size.Z)
		local muzzle =
			riflePart("Muzzle", Vector3.new(0.2, 0.2, 0.14), CFrame.new(muzzleAt), Color3.new())
		muzzle.Transparency = 1
	end
	placeholder()
	local player = Players:GetPlayerFromCharacter(character)
	local function current(): string
		local id = player and player:GetAttribute(Attributes.Weapon)
		return WeaponDefinitions.get(if typeof(id) == "string" then id else nil).Model
	end
	task.spawn(dress, current())
	if player then
		-- A swap (Q), the Arms Room or the dev panel changes the gun in hand: change the mesh.
		local changed = player:GetAttributeChangedSignal(Attributes.Weapon):Connect(function()
			task.spawn(dress, current())
		end)
		tool.Destroying:Once(function()
			changed:Disconnect()
		end)
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

-- The soldier's look as catalog items (Config.Player.Look), for AvatarLook; `player` (nil for a
-- bot) wears their own face when Look.PlayerFace is on.
function PlayerSetup.look(player: Player?): AvatarLook.Look
	local look = Config.Player.Look
	return {
		items = look.Items,
		skin = look.Skin,
		shirt = look.Shirt,
		trousers = look.Trousers,
		faceOf = if player and look.PlayerFace then player.UserId else nil,
	}
end

-- No floating health bar or name over a squad body (players and bots): squadmates' status
-- is the squad panel (Config.SquadPanel, whose switches bring Roblox's own back).
function PlayerSetup.hideOverhead(humanoid: Humanoid)
	if not Config.SquadPanel.OverheadBars then
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	if not Config.SquadPanel.OverheadNames then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- The playable class body (assets/3d pc_<class>_*). One class for now.
local PLAYER_BODY = "pc_assault_"
PlayerSetup.BODY = PLAYER_BODY

-- Skinned body (Config.Player.SkinnedBody): the whole body is one skinned mesh
-- (assets/3d pc_assault_skinned) assembled at boot by MeshAssets.buildSkinnedBody from its
-- two uploaded assets and installed as StarterPlayer.StarterCharacter, so every character
-- spawns as that rig (R15 part names, Humanoid, Animator) and the limb swap is skipped; the
-- helmet and carrier weld on like the rifle does. The install yields on the asset fetch
-- (about a second) so the first body of the run already spawns skinned (RunManager loads
-- the characters after this init). Bots (BotService) keep the limb-swap body.
local SKIN_PART = "SkinnedBody" -- the mesh buildSkinnedBody adds; marks a skinned character

local function installSkinnedBody()
	local template = MeshAssets.buildSkinnedBody(Config.Player.SkinnedTemplate)
	if not template then
		warn("[PlayerSetup] SkinnedBody is on but the body did not load; using the limb-swap body")
		return
	end
	local existing = StarterPlayer:FindFirstChild("StarterCharacter")
	if existing then
		existing:Destroy()
	end
	template.Name = "StarterCharacter"
	template.Parent = StarterPlayer
	-- In Studio the first player is in before any script runs and already has the stock
	-- body (CharacterAutoLoads is still on at that point): give them the skinned one.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and not character:FindFirstChild(SKIN_PART) then
			player:LoadCharacter()
		end
	end
end

-- Welds the rigid gear meshes (Config.Player.SkinnedGear) onto the skinned body's limbs.
-- A gear mesh that is not registered or not uploaded yet is skipped.
local function attachGear(character: Model)
	for _, gear in Config.Player.SkinnedGear do
		local part = character:FindFirstChild(gear.part)
		local offset = MeshAssets.offsetOf(gear.mesh)
		if not part or not part:IsA("BasePart") or not offset then
			continue
		end
		local template = MeshAssets.waitFor(gear.mesh, 5)
		if not template then
			continue
		end
		local mesh = template:Clone()
		mesh.Anchored = false
		mesh.Massless = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		mesh.CastShadow = true
		mesh.CFrame = part.CFrame * CFrame.new(offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = mesh
		weld.Parent = mesh
		mesh.Parent = character
	end
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	PlayerSetup.hideOverhead(humanoid)
	-- No jump: cover is vaulted or climbed instead (client MovementController).
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	-- The rig stays jointed on death so the death clip can play (AnimationController).
	humanoid.BreakJointsOnDeath = false

	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("RightHand")
	-- The soldier's look: catalog items on the default R15 body (Config.Player.Look); else
	-- swap the stock R15 limbs for the class body before the rifle welds to the hand.
	-- Templates build asynchronously at boot; a character that beats them keeps the stock body.
	-- A skinned StarterCharacter already is the body: only its gear goes on.
	if Config.Player.Look.Enabled then
		AvatarLook.apply(humanoid, PlayerSetup.look(Players:GetPlayerFromCharacter(character)))
	elseif character:FindFirstChild(SKIN_PART) then
		attachGear(character)
	elseif MeshAssets.waitFor(PLAYER_BODY .. "head", 10) then
		MeshAssets.dressModel(character, PLAYER_BODY)
	end
	PlayerSetup.attachRifle(character, humanoid)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

function PlayerSetup.init()
	-- Characters spawn as bare R15 rigs (no avatar clothing/accessories) so the class body
	-- is the whole look and every player is the same silhouette.
	StarterPlayer.LoadCharacterAppearance = false
	if Config.Player.Look.Enabled then
		AvatarLook.prefetch(Config.Player.Look.Items)
	end
	if Config.Player.SkinnedBody then
		installSkinnedBody() -- yields on the asset fetch
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerSetup
