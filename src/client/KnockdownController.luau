--!strict
-- Knocked down: the Warden's Pound and Stomp put the body on the ground
-- (server Squad.knock sets KnockedUntil on the character and sends Impact "knockdown").
-- While it lasts SprintController holds WalkSpeed at 0, MovementController refuses vaults
-- and rolls, WeaponController refuses the trigger and the server refuses every action
-- (Squad.canAct). This controller owns the look: the fall clip over the first part, the
-- get-up over the last Config.Knockdown.GetUp seconds (AnimationController.playKnockdown),
-- and the Sweep's shove (Impact "push": MomentumController.push, the client owns its
-- physics so the server cannot throw the body itself).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local AnimationController = require(script.Parent.AnimationController)
local MomentumController = require(script.Parent.MomentumController)

local KnockdownController = {}

local function onImpact(kind: string, ...: any)
	if kind == Messages.Impact.Knockdown then
		local seconds = ... :: number
		if typeof(seconds) == "number" and seconds > 0 then
			AnimationController.playKnockdown(seconds)
		end
	elseif kind == Messages.Impact.Push then
		local shove = ... :: Vector3
		if typeof(shove) == "Vector3" then
			MomentumController.push(shove)
		end
	end
end

function KnockdownController.init()
	Remotes.get("Impact").OnClientEvent:Connect(onImpact)
end

return KnockdownController
