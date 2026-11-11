--!strict
-- Soldiers on the Fallow wear the match's Pike body, so the lobby and the game look like one
-- thing: the same limb swap the match's PlayerSetup does (MeshAssets.dressModel with
-- PlayerSetup.BODY, mapped into the lobby by lobby.project.json, so the body is named in one
-- place). Unarmed: nobody carries a rifle on the ship, and nothing else of PlayerSetup runs.
-- Follows the match's current body (Config.Player.SkinnedBody is off: the tapered rigid
-- limbs); if the skinned body comes back, mirror PlayerSetup's installSkinnedBody here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local PlayerSetup = require(script.Parent.PlayerSetup)

local PikeBody = {}

local TEMPLATE_WAIT = 10 -- seconds a character waits for the body meshes at boot

-- What every Pike on the ship wears over the body (Nova, 2026-11-10: "personality"; the lore
-- developer, docs/CHARACTERS.md > Pike): the screening band on the left wrist (white, a yellow
-- stripe: passed the lane), a chemlight on the left shoulder strap, the tourniquet high on the
-- right arm. Lobby only for now; the match body is PlayerSetup's.
local function wear(
	character: Model,
	limbName: string,
	name: string,
	size: Vector3,
	offset: (BasePart) -> CFrame,
	color: Color3,
	neon: boolean?
)
	local limb = character:FindFirstChild(limbName)
	if not (limb and limb:IsA("BasePart")) then
		return
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = limb.CFrame * offset(limb)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
end

local function pikeKit(character: Model)
	local wrist = function(limb: BasePart, grow: number)
		return Vector3.new(limb.Size.X + grow, 0, limb.Size.Z + grow)
	end
	wear(
		character,
		"LeftLowerArm",
		"ScreeningBand",
		wrist(character:FindFirstChild("LeftLowerArm") :: BasePart, 0.08) + Vector3.new(0, 0.26, 0),
		function(limb)
			return CFrame.new(0, -limb.Size.Y / 2 + 0.25, 0)
		end,
		Color3.fromRGB(236, 236, 230)
	)
	wear(
		character,
		"LeftLowerArm",
		"ScreeningStripe",
		wrist(character:FindFirstChild("LeftLowerArm") :: BasePart, 0.1) + Vector3.new(0, 0.08, 0),
		function(limb)
			return CFrame.new(0, -limb.Size.Y / 2 + 0.25, 0)
		end,
		Color3.fromRGB(230, 190, 40)
	)
	wear(
		character,
		"RightUpperArm",
		"Tourniquet",
		wrist(character:FindFirstChild("RightUpperArm") :: BasePart, 0.08) + Vector3.new(0, 0.2, 0),
		function(limb)
			return CFrame.new(0, limb.Size.Y / 2 - 0.3, 0)
		end,
		Color3.fromRGB(28, 28, 30)
	)
	wear(character, "RightUpperArm", "TourniquetTab", Vector3.new(0.12, 0.22, 0.22), function(limb)
		return CFrame.new(limb.Size.X / 2 + 0.08, limb.Size.Y / 2 - 0.3, 0)
	end, Color3.fromRGB(200, 40, 34))
	wear(character, "UpperTorso", "Chemlight", Vector3.new(0.12, 0.45, 0.12), function(limb)
		return CFrame.new(-limb.Size.X * 0.28, limb.Size.Y * 0.28, -limb.Size.Z / 2 - 0.08)
	end, Color3.fromRGB(120, 255, 120), true)
end

local function onCharacterAdded(character: Model)
	character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	-- Templates build asynchronously at boot; a character that beats them keeps the stock body.
	if MeshAssets.waitFor(PlayerSetup.BODY .. "head", TEMPLATE_WAIT) then
		MeshAssets.dressModel(character, PlayerSetup.BODY)
		if
			character:FindFirstChild("LeftLowerArm") and character:FindFirstChild("RightUpperArm")
		then
			pikeKit(character)
		end
	else
		warn("[PikeBody] body meshes did not load; this soldier keeps the stock body")
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function PikeBody.init()
	-- Bare R15 rigs (no avatar clothing or accessories): the Pike body is the whole look.
	StarterPlayer.LoadCharacterAppearance = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PikeBody
