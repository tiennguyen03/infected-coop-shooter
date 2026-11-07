--!strict
-- XP orbs: dropped where an Infected dies, drift toward a player who comes
-- within magnet range, and grant XP on contact. Orbs are server-simulated
-- anchored parts stepped on Heartbeat, same pattern as projectiles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local PauseService = require(script.Parent.PauseService)
local XPService = require(script.Parent.XPService)
local Squad = require(script.Parent.Squad)

type Orb = {
	part: BasePart,
	xp: number,
	expiresAt: number,
}

local XPOrbService = {}

local orbFolder: Folder
local orbs: { Orb } = {}
local collectListeners: { (xp: number) -> () } = {}

-- Called once per collected orb with its base XP (RequisitionService feeds the pool).
function XPOrbService.addCollectListener(listener: (xp: number) -> ())
	table.insert(collectListeners, listener)
end

-- The nearest living squad member (player or bot) pulls an orb in and picks it up.
local function nearestAliveMember(position: Vector3): (Squad.Member?, BasePart?, number)
	local member, distance = Squad.nearestLiving(position)
	return member, member and member.root, distance
end

function XPOrbService.spawnOrb(position: Vector3, xp: number)
	-- Bigger orb for bigger rewards (Brutes) so value reads at a glance.
	local diameter = if xp >= 20 then 1.5 else 0.9
	local part: BasePart = MeshAssets.clone("pick_xp_orb") or Instance.new("Part")
	part.Name = "XPOrb"
	if part:IsA("Part") then
		-- Placeholder when the mesh template is missing.
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(85, 255, 170)
	end
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = orbFolder

	table.insert(orbs, {
		part = part :: BasePart,
		xp = xp,
		expiresAt = os.clock() + Config.XP.OrbLifetime,
	})
end

local function removeOrb(index: number)
	orbs[index].part:Destroy()
	orbs[index] = orbs[#orbs]
	orbs[#orbs] = nil
end

local function stepOrbs(deltaTime: number)
	if PauseService.isPaused() then
		return
	end
	local now = os.clock()
	for index = #orbs, 1, -1 do
		local orb = orbs[index]
		if now >= orb.expiresAt or not orb.part.Parent then
			removeOrb(index)
			continue
		end

		local member, root, distance = nearestAliveMember(orb.part.Position)
		if not member or not root then
			continue
		end

		-- Scavenger Pouch: +% magnet range (the collector's own; a bot has none).
		local magnetRadius = Config.XP.MagnetRadius
			* (1 + (Squad.ownerAttribute(member, "OrbMagnetMult", 0) :: number))
		if distance <= Config.XP.CollectRadius then
			-- XP is shared (decision #2): every living player gets the orb's full XP.
			for _, owner in Squad.livingOwners() do
				XPService.addXP(owner, orb.xp)
			end
			for _, listener in collectListeners do
				listener(orb.xp)
			end
			removeOrb(index)
		elseif distance <= magnetRadius then
			local direction = (root.Position - orb.part.Position).Unit
			orb.part.Position += direction * Config.XP.OrbFlySpeed * deltaTime
		end
	end
end

function XPOrbService.reset()
	for _, orb in orbs do
		orb.part:Destroy()
	end
	table.clear(orbs)
	if orbFolder then
		orbFolder:ClearAllChildren()
	end
end

function XPOrbService.init()
	orbFolder = Instance.new("Folder")
	orbFolder.Name = "XPOrbs"
	orbFolder.Parent = workspace

	RunService.Heartbeat:Connect(stepOrbs)
end

return XPOrbService
