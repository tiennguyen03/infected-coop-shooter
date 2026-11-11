--!strict
-- Single source of truth for RemoteEvents. The server creates them on first
-- require; clients wait for them to replicate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Each remote's message kinds (the first argument) are constants in Messages.luau; the
-- comments below document the payloads.
local REMOTE_NAMES = {
	"FireWeapon", -- client -> server: (origin: Vector3, direction: Vector3, aiming: boolean, pellets: { Vector3 }?) a shotgun sends the pellets it drew
	"Reload", -- client -> server: start a reload (LoadoutService; Mag/Reserve/ReloadUntil are player attributes)
	"CallIn", -- client -> server: (slot: 1..Config.CallIns.Slots, landingPoint: Vector3?) use the call-in in that slot
	"ShotTracer", -- server -> other clients: (origin: Vector3, endPoint: Vector3, sound: string?) draw a tracer, play that gun's shot
	"ObjectiveUpdate", -- server -> client: (kind: "started"|"progress"|"completed", progress: number, playersIn: number?, playersLiving: number?)
	"DamageDealt", -- server -> client (hits: the attacker only; kills: everyone): (position: Vector3, amount: number, kind: "hit"|"headshot"|"fire"|"breach"|"death"|..., attacker: Player?)
	"Resupply", -- client -> server: ("flare", target) | ("pick", crateId, cardId); server -> client: ("called", thrower) | ("cards", crateId, kind, choices, positions) | ("picked", crateId) | ("closed", crateId)
	"BuffNotice", -- server -> client: (text: string, kind: Messages.Notice) a radio line (subtitle) or a pickup / pick notice (card)
	"RestartRun", -- client -> server: READY for the next run (only once the run has Ended)
	"DevCommand", -- client -> server: (command: string, ...) Studio/creator-only dev tools
	"ExtractionUpdate", -- server -> client: (kind: "available"|"progress"|"waiting"|"returning"|"complete"|"hide", progress, playersIn?, playersLiving?)
	"UseAbility", -- client -> server: (kind: "swap"|"grenade"|"shove"|"stim", target: Vector3?) the soldier's kit (KitService)
	"AbilityUsed", -- server -> client: (kind: string, cooldown: number) for the UI countdown | ("callin", slot, id)
	"Loadout", -- client -> server: ("request", {primary, secondary, grenade, callIns}); server -> client: ("result", ok: boolean, reason: string?) the Arms Room | ("signed", loadout) the lobby's saved Loadout
	"CoverMove", -- client -> server: (kind: "vault"|"climb"|"roll"|"slide") the body started going over cover, rolling or sliding
	"BossUpdate", -- server -> client: ("show", name, plateNames) | ("state", body, plates, phase) | ("tell", kind) | ("hide"); client -> server: () resend the state
	"Impact", -- server -> client: ("knockdown", seconds) the body is knocked down (Squad.knock) | ("push", velocity: Vector3) a shove the client applies to its root
	"Stance", -- client -> server: (stance: "stand"|"crouch"|"prone"); server -> client: ("prone") stand-up refused under a ceiling
	"Record", -- lobby place, client -> server: ("buy", gunId); server -> client: ("state", merits, ownedIds) | ("refused", gunId, reason)
	"EnemySpit", -- server -> client (Messages.EnemySpit; client SpitFX draws it): ("windup", model, seconds) | ("launch", id, origin: Vector3, velocity: Vector3, size) | ("impact", id, position, normal, splashRadius, poolGround: CFrame?, poolRadius?, poolSeconds?) | ("gone", id) | ("reset")
	"Launch", -- lobby place, server -> client: ("manifest", spot, names, secondsLeft, squad, isLead) | ("lifting", spot) | ("failed", reason) | ("cleared"); client -> server: ("squad", size)
}

if RunService:IsServer() and not ReplicatedStorage:FindFirstChild("Remotes") then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in REMOTE_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
