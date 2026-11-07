--!strict
-- Single source of truth for RemoteEvents. The server creates them on first
-- require; clients wait for them to replicate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"FireWeapon", -- client -> server: (origin: Vector3, direction: Vector3)
	"ObjectiveUpdate", -- server -> client: (kind: "started"|"progress"|"completed", progress: number)
	"DamageDealt", -- server -> client: (position: Vector3, amount: number, kind: "hit"|"bleed")
	"Resupply", -- client -> server: ("flare", target) | ("pick", crateId, itemId); server -> client: ("called", thrower) | ("cards", crateId, choices, positions, inventory) | ("picked", crateId) | ("closed", crateId)
	"ItemsUpdate", -- server -> client: (inventory: { [itemId]: stacks })
	"BuffNotice", -- server -> client: (text: string) short on-screen buff announcement
	"RestartRun", -- client -> server: request a fresh run after dying
	"DevCommand", -- client -> server: (command: string, ...) Studio/creator-only dev tools
	"ExtractionUpdate", -- server -> client: (kind: "available"|"progress"|"returning"|"complete"|"hide", progress)
	"MissionSuccess", -- server -> client: () show the operation-complete results screen
	"UseAbility", -- client -> server: (abilityName: "dash"|"breach")
	"AbilityUsed", -- server -> client: (abilityName: string, cooldown: number) for UI countdown
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
