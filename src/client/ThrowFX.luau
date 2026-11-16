--!strict
-- A grenade or the flare in the air (docs/PROGRESSION.md > Throwing): the server says it
-- left a soldier's hand (remote Thrown, at the throw clip's release) and this flies a ball
-- from that soldier's hand, where the clip has it on this client, along the aim arc to the
-- mark. The real grenade or flare appears on the mark when it lands (KitService,
-- RequisitionService). Thrown call-ins fly in CallInArrivalFX.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arrival = require(Shared:WaitForChild("Rules"):WaitForChild("Arrival"))
local Attributes = require(Shared:WaitForChild("Attributes"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ThrowUtil = require(Shared:WaitForChild("ThrowUtil"))

local UP = Vector3.yAxis
local MAX_FLIGHT = 3 -- seconds; a longer flight is not a throw

local ThrowFX = {}

local function onThrown(thrower: unknown, landing: unknown, flight: unknown, color: unknown)
	if typeof(landing) ~= "Vector3" or typeof(flight) ~= "number" or typeof(color) ~= "Color3" then
		return
	end
	if flight <= 0 or flight > MAX_FLIGHT then
		return
	end
	-- The hand it left: the thrower's body when it is here, else a short lob onto the mark.
	local from = landing + UP * 2
	if typeof(thrower) == "Instance" and thrower:IsA("Player") then
		local character = thrower.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			from = ThrowUtil.hand(character, root.Position + UP * 1.5)
		end
	end
	local arc = Config.CallIns.AimArc
	local reach = Vector3.new(landing.X - from.X, 0, landing.Z - from.Z).Magnitude
	local rise = math.max(reach * arc.Rise, arc.MinRise)

	local ball = Instance.new("Part")
	ball.Name = "Thrown"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.8, 0.8, 0.8)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Position = from
	ball.Parent = workspace

	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		if workspace:GetAttribute(Attributes.GamePaused) == true then
			return
		end
		elapsed += dt
		if elapsed >= flight then
			connection:Disconnect()
			ball:Destroy()
			return
		end
		local u = elapsed / flight
		ball.Position = from:Lerp(landing, u) + UP * Arrival.hop(elapsed, 0, flight, rise)
	end)
end

function ThrowFX.init()
	Remotes.get("Thrown").OnClientEvent:Connect(onThrown)
end

return ThrowFX
