--!strict
-- Soft pause: there is no engine pause, so gameplay systems check this flag
-- and freeze themselves (enemies stop, projectiles/orbs hold, spawns wait,
-- the client unlocks the cursor and stops firing). Published as a workspace
-- attribute so both server systems and clients read the same state.
local Lifecycle = require(script.Parent.Lifecycle)

local PauseService = {}

function PauseService.init()
	Lifecycle.register("PauseService", {
		onRunStart = function()
			PauseService.setPaused(false)
		end,
	})
	workspace:SetAttribute("GamePaused", false)
end

function PauseService.setPaused(paused: boolean)
	workspace:SetAttribute("GamePaused", paused)
end

function PauseService.isPaused(): boolean
	return workspace:GetAttribute("GamePaused") == true
end

return PauseService
