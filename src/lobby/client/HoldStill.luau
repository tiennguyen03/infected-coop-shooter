--!strict
-- Stops the soldier walking off while a desk screen has the camera or the mouse (the rack,
-- the Loadout). Never yields: the lobby runs without a PlayerModule in PlayerScripts, and
-- waiting for one hung the Quartermaster's rack for good (2026-11-09). With a PlayerModule
-- its controls are switched off; without one the Humanoid is held still and given back.

local Players = game:GetService("Players")

local HoldStill = {}

local player = Players.LocalPlayer
local frozen: { humanoid: Humanoid, walk: number, jump: number }? = nil

local function controls(): any
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(function()
		return (require :: any)(module):GetControls()
	end)
	return if ok then result else nil
end

function HoldStill.set(still: boolean)
	local c = controls()
	if c then
		if still then
			c:Disable()
		else
			c:Enable()
		end
		return
	end
	if not still then
		if frozen and frozen.humanoid.Parent then
			frozen.humanoid.WalkSpeed = frozen.walk
			frozen.humanoid.JumpHeight = frozen.jump
		end
		frozen = nil
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and not frozen then
		frozen = { humanoid = humanoid, walk = humanoid.WalkSpeed, jump = humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	end
end

return HoldStill
