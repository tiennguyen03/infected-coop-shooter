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

local function onCharacterAdded(character: Model)
	character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	-- Templates build asynchronously at boot; a character that beats them keeps the stock body.
	if MeshAssets.waitFor(PlayerSetup.BODY .. "head", TEMPLATE_WAIT) then
		MeshAssets.dressModel(character, PlayerSetup.BODY)
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
