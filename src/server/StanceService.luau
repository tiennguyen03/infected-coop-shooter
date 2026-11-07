--!strict
-- Crawl spaces (2026-11-07): the client owns its stance (StanceController) and tells the
-- server through the Stance remote. Prone drops the Humanoid's HipHeight to
-- Config.Player.Stances.ProneHipHeight so the root part (the only collider) fits under a
-- 2.8 gap (the Scrapes), and lifts the rig by the same amount on the Root Motor6D so the
-- prone clip still lies on the ground; the character's RootDrop attribute carries the lift
-- for the camera pivot. Standing up under a ceiling is refused: the server keeps the body
-- low and bounces "prone" back so the client re-syncs. Players only; the Infected and the
-- bots never go prone. No per-player state: everything lives on the character.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local StanceService = {}

local STAND_HIP_ATTRIBUTE = "StandHipHeight"
local ROOT_DROP_ATTRIBUTE = "RootDrop"

local function rootMotor(character: Model): Motor6D?
	local lowerTorso = character:FindFirstChild("LowerTorso")
	local motor = lowerTorso and lowerTorso:FindFirstChild("Root")
	return if motor and motor:IsA("Motor6D") then motor else nil
end

-- Clear studs above the prone root needed to stand (the standing body's height above the
-- crawl height); anything closer is a ceiling.
function StanceService.headroomClear(character: Model, root: BasePart): boolean
	-- Only the world counts as a ceiling: bodies (the Infected, other characters) standing
	-- over a prone player must not pin them down.
	local exclude: { Instance } = { character }
	for _, enemy in CollectionService:GetTagged("Enemy") do
		table.insert(exclude, enemy)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local needed = Config.Player.Stances.ProneHeadroom
	local size = Vector3.new(root.Size.X, 0.2, root.Size.Z)
	local hit = workspace:Blockcast(root.CFrame, size, Vector3.new(0, needed, 0), params)
	return hit == nil
end

local function setProne(character: Model, humanoid: Humanoid, prone: boolean)
	local drop = character:GetAttribute(ROOT_DROP_ATTRIBUTE)
	local isProne = typeof(drop) == "number" and drop > 0
	if prone == isProne then
		return
	end
	local motor = rootMotor(character)
	if prone then
		local standHip = humanoid.HipHeight
		local proneHip = Config.Player.Stances.ProneHipHeight
		local lift = math.max(standHip - proneHip, 0)
		character:SetAttribute(STAND_HIP_ATTRIBUTE, standHip)
		character:SetAttribute(ROOT_DROP_ATTRIBUTE, lift)
		humanoid.HipHeight = proneHip
		if motor then
			motor.C0 = motor.C0 * CFrame.new(0, lift, 0)
		end
	else
		local standHip = character:GetAttribute(STAND_HIP_ATTRIBUTE)
		local lift = if typeof(drop) == "number" then drop else 0
		if typeof(standHip) == "number" then
			humanoid.HipHeight = standHip
		end
		if motor then
			motor.C0 = motor.C0 * CFrame.new(0, -lift, 0)
		end
		character:SetAttribute(ROOT_DROP_ATTRIBUTE, 0)
	end
end

function StanceService.init()
	local remote = Remotes.get("Stance")
	remote.OnServerEvent:Connect(function(player: Player, stance: unknown)
		if stance ~= "stand" and stance ~= "crouch" and stance ~= "prone" then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not humanoid or not root or not root:IsA("BasePart") then
			return
		end
		if humanoid.Health <= 0 then
			return
		end
		if stance == "prone" then
			setProne(character, humanoid, true)
			return
		end
		local drop = character:GetAttribute(ROOT_DROP_ATTRIBUTE)
		local isProne = typeof(drop) == "number" and drop > 0
		if isProne and not StanceService.headroomClear(character, root) then
			remote:FireClient(player, "prone") -- under a ceiling: stays down
			return
		end
		setProne(character, humanoid, false)
	end)
	-- A new body starts standing; the attributes die with the old one.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character:SetAttribute(ROOT_DROP_ATTRIBUTE, 0)
		end)
	end)
end

return StanceService
