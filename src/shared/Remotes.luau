--!strict
-- Single source of truth for RemoteEvents. The server creates them on first
-- require; clients wait for them to replicate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"FireWeapon", -- client -> server: (origin: Vector3, direction: Vector3, aiming: boolean)
	"Reload", -- client -> server: start a reload (LoadoutService; Mag/Reserve/ReloadUntil are player attributes)
	"CallIn", -- client -> server: (slot: 1|2, landingPoint: Vector3?) use the call-in in that slot
	"ShotTracer", -- server -> other clients: (origin: Vector3, endPoint: Vector3) draw a tracer
	"ObjectiveUpdate", -- server -> client: (kind: "started"|"progress"|"completed", progress: number)
	"DamageDealt", -- server -> client: (position: Vector3, amount: number, kind: "hit"|"headshot"|"fire"|"breach"|"death"|..., attacker: Player?)
	"Resupply", -- client -> server: ("flare", target) | ("pick", crateId, cardId); server -> client: ("called", thrower) | ("cards", crateId, kind, choices, positions) | ("picked", crateId) | ("closed", crateId)
	"BuffNotice", -- server -> client: (text: string) short on-screen announcement
	"RestartRun", -- client -> server: READY for the next run (only once the run has Ended)
	"DevCommand", -- client -> server: (command: string, ...) Studio/creator-only dev tools
	"ExtractionUpdate", -- server -> client: (kind: "available"|"progress"|"returning"|"complete"|"hide", progress)
	"UseAbility", -- client -> server: (abilityName: "dash"|"breach")
	"AbilityUsed", -- server -> client: (abilityName: string, cooldown: number) for UI countdown
	"CoverMove", -- client -> server: (kind: "vault"|"climb"|"roll"|"slide") the body started going over cover, rolling or sliding
	"Stance", -- client -> server: (stance: "stand"|"crouch"|"prone"); server -> client: ("prone") stand-up refused under a ceiling
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
