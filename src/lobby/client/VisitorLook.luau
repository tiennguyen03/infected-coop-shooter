--!strict
-- The Visitor's head follows the nearest soldier (docs/sprints/CARRIER_V2.md > The Visitor: he
-- stands still, hands in his pockets; only his head turns, slowly). Each client turns his Neck on
-- top of whatever his idle clip does (Motor6D.Transform, after the Animator's step), so nothing is
-- sent over the network. Off while the local soldier is far from him; Config.Lobby.Visitor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)

local VisitorLook = {}

local TUNING = Config.Lobby.Visitor
local AWAKE = 80 -- studs: the local soldier further than this skips the work
local SEARCH_EVERY = 0.25 -- seconds between looks for the nearest soldier

local function nearest(from: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDistance = TUNING.LookRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local distance = (head.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = head.Position, distance
			end
		end
	end
	return best
end

local function follow(body: Model)
	local head = body:WaitForChild("Head", 30)
	local torso = body:WaitForChild("UpperTorso", 30)
	local neck = head and head:WaitForChild("Neck", 30)
	if
		not (head and head:IsA("BasePart"))
		or not (torso and torso:IsA("BasePart"))
		or not (neck and neck:IsA("Motor6D"))
	then
		return
	end
	local maxYaw = math.rad(TUNING.LookMaxYaw)
	local yaw = 0
	local target: Vector3? = nil
	local searchAt = 0
	-- What the Animator left this frame; if it left our own last write untouched (no clip moves
	-- the neck), the turn goes on the base from before it, so it never adds up.
	local base = neck.Transform
	local written: CFrame? = nil

	RunService.PreSimulation:Connect(function(dt: number)
		local me = Players.LocalPlayer.Character
		local root = me and me:FindFirstChild("HumanoidRootPart")
		if
			not (root and root:IsA("BasePart"))
			or (root.Position - head.Position).Magnitude > AWAKE
		then
			return
		end
		local now = os.clock()
		if now >= searchAt then
			searchAt = now + SEARCH_EVERY
			target = nearest(head.Position)
		end
		local goal = 0
		if target then
			local dir = torso.CFrame:VectorToObjectSpace(target - head.Position)
			goal = math.clamp(math.atan2(-dir.X, -dir.Z), -maxYaw, maxYaw)
		end
		yaw += (goal - yaw) * math.min(1, dt * TUNING.LookSpeed)
		if neck.Transform ~= written then
			base = neck.Transform
		end
		local turned = base * CFrame.Angles(0, yaw, 0)
		neck.Transform = turned
		written = turned
	end)
end

function VisitorLook.init()
	if not Config.Lobby.CarrierV2.Enabled then
		return -- his nook is only on the v2 ship
	end
	local title: string? = nil
	for _, desk in LobbyDesks do
		if desk.id == "visitor" then
			title = desk.title
		end
	end
	if not title then
		return
	end
	task.spawn(function()
		local desks = Workspace:WaitForChild("Desks", 60)
		local body = desks and desks:WaitForChild(title, 60)
		if body and body:IsA("Model") then
			follow(body)
		end
	end)
end

return VisitorLook
