--!strict
-- Lantern turning (owner, 2026-11-09: "Lantern on spot three, turning"). The birds sit still
-- with their blades drooped and the lamp off. When a spot starts counting down, LaunchService
-- sets Attributes.LiftAt on its bird (server time); every client then lights the amber lamp,
-- spools the rotor up over the first part of the countdown, builds the blur over the last
-- seconds (Rules/RotorBlur: the blades fade part way as the discs thicken) and lifts the bird a few studs, nose down, before the teleport. Cleared (a failed
-- lift, the box emptied): everything goes back where the server put it. All local: nothing
-- replicates per frame. Tuning: Config.Lobby.Lantern.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local RotorBlur = require(ReplicatedStorage.Shared.Rules.RotorBlur)

local LanternSpool = {}

local TUNING = Config.Lobby.Lantern
local BLUR: RotorBlur.Settings = {
	start = TUNING.BlurStart,
	full = TUNING.BlurFull,
	bladeFade = TUNING.BladeFade,
	disc = TUNING.BlurTransparency,
}
local BIRD = "Lantern"

type Spin = {
	connection: RBXScriptConnection,
	bases: { [BasePart]: CFrame },
}

local active: { [Model]: Spin } = {}

local function setLamp(bird: Model, on: boolean)
	local lamp = bird:FindFirstChild("Lamp")
	if not (lamp and lamp:IsA("BasePart")) then
		return
	end
	lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	lamp.Color = if on then TUNING.LampColor else Color3.fromRGB(132, 95, 32)
	local light = lamp:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = on
	end
end

-- `blade`: the blades' LocalTransparencyModifier; `disc`: the blur discs' Transparency.
local function setBlur(bird: Model, blade: number, disc: number)
	for _, name in { "Rotor", "TailRotor" } do
		local blades = bird:FindFirstChild(name)
		if blades and blades:IsA("BasePart") then
			blades.LocalTransparencyModifier = blade
		end
	end
	for _, name in { "RotorDisc", "TailDisc" } do
		local part = bird:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Transparency = disc
		end
	end
end

local function stop(bird: Model)
	local spin = active[bird]
	if not spin then
		return
	end
	active[bird] = nil
	spin.connection:Disconnect()
	for part, cframe in spin.bases do
		if part.Parent then
			part.CFrame = cframe
		end
	end
	setLamp(bird, false)
	setBlur(bird, 0, 1)
end

local function start(bird: Model)
	if active[bird] then
		return
	end
	local bases: { [BasePart]: CFrame } = {}
	for _, part in bird:GetDescendants() do
		if part:IsA("BasePart") then
			bases[part] = part.CFrame
		end
	end
	local pivot = bird:GetPivot()
	local rotor = bird:FindFirstChild("Rotor")
	local tail = bird:FindFirstChild("TailRotor")
	local began = Workspace:GetServerTimeNow()
	local angle = 0
	setLamp(bird, true)
	local connection = RunService.RenderStepped:Connect(function(deltaTime)
		local liftAt = bird:GetAttribute(Attributes.LiftAt)
		if typeof(liftAt) ~= "number" then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local remaining = liftAt - now
		local spool =
			math.clamp((now - began) / math.max((liftAt - began) * TUNING.SpoolShare, 0.1), 0, 1)
		angle += spool * TUNING.RotorRpm * math.pi * 2 / 60 * deltaTime
		setBlur(bird, RotorBlur.at(remaining, BLUR))
		local rise = math.clamp((TUNING.LiftSeconds - remaining) / TUNING.LiftSeconds, 0, 1)
		local lift = pivot
			* CFrame.new(0, TUNING.Rise * rise, 0)
			* CFrame.Angles(math.rad(TUNING.Dip) * rise, 0, 0)
			* pivot:Inverse()
		for part, cframe in bases do
			local placed = lift * cframe
			if part == rotor then
				placed *= CFrame.Angles(0, angle, 0)
			elseif part == tail then
				placed *= CFrame.Angles(angle * TUNING.TailRatio, 0, 0)
			end
			part.CFrame = placed
		end
	end)
	active[bird] = { connection = connection, bases = bases }
end

local function watch(bird: Instance)
	if not (bird:IsA("Model") and bird.Name == BIRD) then
		return
	end
	local function changed()
		if typeof(bird:GetAttribute(Attributes.LiftAt)) == "number" then
			start(bird)
		else
			stop(bird)
		end
	end
	bird:GetAttributeChangedSignal(Attributes.LiftAt):Connect(changed)
	-- The meshes replace the blocks after boot: a spin running then restarts on the new parts.
	bird.ChildAdded:Connect(function()
		if active[bird] then
			stop(bird)
			task.defer(changed)
		end
	end)
	changed()
end

function LanternSpool.init()
	task.spawn(function()
		local spots = Workspace:WaitForChild("Spots", 30)
		if not spots then
			return
		end
		spots.ChildAdded:Connect(watch)
		for _, child in spots:GetChildren() do
			watch(child)
		end
	end)
end

return LanternSpool
