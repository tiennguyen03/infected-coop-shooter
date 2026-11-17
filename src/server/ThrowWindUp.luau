--!strict
-- Wind-up, then release (docs/PROGRESSION.md > Throwing): everything a soldier throws (the
-- grenade in KitService, the thrown call-ins in CallInService, the flare in
-- RequisitionService) goes through `begin`. The thrower's client starts the throw clip the
-- moment the key comes up; the server holds the real throw back until that clip's release
-- (Rules/ThrowTiming, Config.Animations.Throws), so nothing leaves the hand early and a
-- client cannot skip the wait. One throw at a time per soldier. A thrower who is downed,
-- knocked down, dead or gone at the release throws nothing, and nothing is spent: the
-- caller's `release` is where the grenade, charge or pool is taken.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ThrowTiming = require(ReplicatedStorage.Shared.Rules.ThrowTiming)
local Lifecycle = require(script.Parent.Lifecycle)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)

local ThrowWindUp = {}

local thrownRemote: RemoteEvent
-- The throw each soldier is winding up (a token; cleared at the release or a reset).
local winding: { [Player]: {} } = {}

-- Seconds from the request to the release for the soldier's throw clip.
local function windUp(player: Player): number
	local animations = Config.Animations
	local timing = ThrowTiming.resolve(animations.Throws :: any, animations.Assault.throw)
	return ThrowTiming.serverWait(
		ThrowTiming.windUp(timing),
		player:GetNetworkPing(),
		animations.ThrowMaxLag
	)
end

-- Starts `player`'s throw: `release` runs at the clip's release if the thrower can still
-- act then (unpaused time; a frozen field holds the arm back). False while another throw
-- of theirs is still winding up. The caller validates before calling and spends in `release`.
function ThrowWindUp.begin(player: Player, release: () -> ()): boolean
	if winding[player] then
		return false
	end
	local token = {}
	winding[player] = token
	task.spawn(function()
		PauseService.wait(windUp(player))
		if winding[player] ~= token then
			return -- a run start or a reset dropped it
		end
		winding[player] = nil
		local member = Squad.fromPlayer(player)
		if player.Parent and member and Squad.canAct(member) and member.root then
			release()
		end
	end)
	return true
end

-- Tells every client something left `player`'s hand for `landing` (ThrowFX draws the
-- flight; the caller puts the real thing on the mark `flight` seconds later).
function ThrowWindUp.thrown(player: Player, landing: Vector3, flight: number, color: Color3)
	thrownRemote:FireAllClients(player, landing, flight, color)
end

function ThrowWindUp.init()
	thrownRemote = Remotes.get("Thrown")
	local function forget(player: Player)
		winding[player] = nil
	end
	Lifecycle.register("ThrowWindUp", {
		onRunStart = function()
			table.clear(winding)
		end,
		onPlayerReset = forget,
		onPlayerRemoving = forget,
	})
end

return ThrowWindUp
