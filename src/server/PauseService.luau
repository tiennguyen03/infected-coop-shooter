--!strict
-- Soft pause: there is no engine pause, so gameplay systems check this flag
-- and freeze themselves (enemies stop, projectiles/orbs hold, spawns wait,
-- the client unlocks the cursor and stops firing). Published as a workspace
-- attribute so both server systems and clients read the same state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Lifecycle = require(script.Parent.Lifecycle)

local PauseService = {}

function PauseService.init()
	Lifecycle.register("PauseService", {
		onRunStart = function()
			PauseService.setPaused(false)
		end,
	})
	workspace:SetAttribute(Attributes.GamePaused, false)
end

function PauseService.setPaused(paused: boolean)
	workspace:SetAttribute(Attributes.GamePaused, paused)
end

function PauseService.isPaused(): boolean
	return workspace:GetAttribute(Attributes.GamePaused) == true
end

-- Yields for `seconds` of unpaused time (a shell in the air, a case on its chute hold
-- while the field is frozen).
function PauseService.wait(seconds: number)
	local remaining = seconds
	while remaining > 0 do
		local dt = task.wait()
		if not PauseService.isPaused() then
			remaining -= dt
		end
	end
end

return PauseService
