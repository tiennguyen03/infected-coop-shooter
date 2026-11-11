--!strict
-- Turns the Fallow's air-search radar (owner, 2026-11-09: the one motion on a still ship).
-- The server places the mesh once (FallowArt); each client turns its own copy about the
-- part's vertical axis, so nothing replicates. No radar (the mesh not uploaded yet): nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local RadarSpin = {}

local RADAR = "env_fallow_radar"

local function spin(radar: BasePart)
	local base = radar.CFrame
	local perSecond = Config.Lobby.Ship.RadarRpm * math.pi * 2 / 60
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not radar.Parent then
			connection:Disconnect()
			return
		end
		radar.CFrame = base * CFrame.Angles(0, os.clock() * perSecond, 0)
	end)
end

local function watch(art: Instance)
	art.ChildAdded:Connect(function(child)
		if child.Name == RADAR and child:IsA("BasePart") then
			spin(child)
		end
	end)
	local radar = art:FindFirstChild(RADAR)
	if radar and radar:IsA("BasePart") then
		spin(radar)
	end
end

function RadarSpin.init()
	task.spawn(function()
		local ship = Workspace:WaitForChild("Fallow", 30)
		local art = ship and ship:WaitForChild("ShipArt", 30)
		if art then
			watch(art)
		end
	end)
end

return RadarSpin
