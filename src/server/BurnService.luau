--!strict
-- Burning Infected (Rules/DoT; Config.DoT): an incendiary round's projectile that lands lights
-- its target (ProjectileServer: the Mossberg's Dragon's Breath, its ammo row's Burn). Each hit
-- is a stack on its own clock, so pellets that land together burn together; every Tick the
-- owed damage goes through DamageService as "fire", credited to whoever lit it last. A
-- burning Infected wears one small Fire (Config.DoT.Flame, at most MaxShown at once: one lit
-- while the cap is full burns unseen to the end, even if a flame frees up), put out the moment
-- it dies. The
-- Cauterizer and the Leech reuse this rule, not a second one. Nothing burns across runs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DoT = require(ReplicatedStorage.Shared.Rules.DoT)
local DamageService = require(script.Parent.DamageService)
local Lifecycle = require(script.Parent.Lifecycle)
local PauseService = require(script.Parent.PauseService)

local BurnService = {}

export type Burn = { damage: number, seconds: number }

type Target = { state: DoT.State, owner: Player?, fire: Fire?, died: RBXScriptConnection? }

local burning: { [Humanoid]: Target } = {}
local shown = 0
local sinceTick = 0

local function stop(humanoid: Humanoid)
	local target = burning[humanoid]
	if not target then
		return
	end
	if target.fire then
		target.fire:Destroy()
		shown -= 1
	end
	if target.died then
		target.died:Disconnect()
	end
	burning[humanoid] = nil
end

local function flame(humanoid: Humanoid): Fire?
	local flameRow = Config.DoT.Flame
	local root = humanoid.RootPart
	if not root or shown >= flameRow.MaxShown then
		return nil
	end
	local fire = Instance.new("Fire")
	fire.Size = flameRow.Size
	fire.Heat = flameRow.Heat
	fire.Color = flameRow.Color
	fire.SecondaryColor = flameRow.SecondaryColor
	fire.Parent = root
	shown += 1
	return fire
end

-- `owner`'s round lit `humanoid` with `burn` (its ammo row's Burn).
function BurnService.ignite(owner: Player?, humanoid: Humanoid, burn: Burn)
	if humanoid.Health <= 0 then
		return
	end
	local target: Target = burning[humanoid]
	if not burning[humanoid] then
		local fresh: Target = { state = DoT.new(), owner = owner, fire = flame(humanoid) }
		if fresh.fire then
			fresh.died = humanoid.Died:Connect(function()
				stop(humanoid)
			end)
		end
		burning[humanoid] = fresh
		target = fresh
	end
	target.owner = owner or target.owner
	DoT.add(target.state, os.clock(), burn.damage, burn.seconds, Config.DoT.MaxStacks)
end

local function step(dt: number)
	sinceTick += dt
	if sinceTick < Config.DoT.Tick or next(burning) == nil or PauseService.isPaused() then
		return
	end
	sinceTick = 0
	local now = os.clock()
	local done: { Humanoid } = {}
	for humanoid, target in burning do
		if humanoid.Health <= 0 or not humanoid.Parent then
			table.insert(done, humanoid)
			continue
		end
		local amount = DoT.tick(target.state, now)
		if amount > 0 then
			local root = humanoid.RootPart
			DamageService.dealDamage(target.owner, humanoid, amount, root and root.Position, "fire")
		end
		if humanoid.Health <= 0 or not DoT.active(target.state, now) then
			table.insert(done, humanoid)
		end
	end
	for _, humanoid in done do
		stop(humanoid)
	end
end

function BurnService.reset()
	local all: { Humanoid } = {}
	for humanoid in burning do
		table.insert(all, humanoid)
	end
	for _, humanoid in all do
		stop(humanoid)
	end
end

function BurnService.init()
	Lifecycle.register("BurnService", {
		onRunStart = BurnService.reset,
		onPlayerRemoving = function(player: Player)
			for _, target in burning do
				if target.owner == player then
					target.owner = nil
				end
			end
		end,
	})
	RunService.Heartbeat:Connect(step)
end

return BurnService
