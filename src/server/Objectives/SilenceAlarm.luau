--!strict
-- Silence the Alarm (Checkpoint Delta's signature side objective): the Gate's siren loops
-- until a player holds E on its switch box. Once it is off, roaming Infected appear near the
-- Gate far less often (EnemyService.setQuiet) for the rest of the mission. Bots guard the
-- player at the box.

local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local Server = script.Parent.Parent
local EnemyService = require(Server.EnemyService)
local WorldSounds = require(Server.WorldSounds)

local SilenceAlarm = {}

local BOX_SIZE = Vector3.new(1.2, 1.6, 0.6)
local BOX_COLOR = Color3.fromRGB(99, 109, 119)

function SilenceAlarm.new(context: Types.Context): Types.Objective
	local row = context.row
	local box =
		Kit.block(context.folder, "SirenSwitch", BOX_SIZE, CFrame.new(context.position), BOX_COLOR)
	Kit.marker(box, context, nil, 5)

	-- The siren head on the Gate's lamp post (ArenaService landmarks) carries the loop.
	local head = workspace:FindFirstChild("Siren", true)
	local lamp = head and head:FindFirstChildOfClass("PointLight")
	local loop: Sound? = nil
	if head and head:IsA("BasePart") then
		loop = WorldSounds.loopOn(head, "ambience", "amb_siren")
	end

	local function quietSiren()
		if loop then
			loop:Destroy()
			loop = nil
		end
	end

	Kit.prompt(box, "Shut off the siren", "Siren switch", row.Hold or 4, function()
		quietSiren()
		if lamp then
			lamp.Enabled = false
		end
		for _, child in box:GetChildren() do
			child:Destroy()
		end
		EnemyService.setQuiet(context.position, row.Radius or 140, row.SpawnFactor or 0.4)
		context.complete()
	end)

	return {
		begin = function() end,
		step = function() end,
		progress = function(): Types.Progress
			return {
				step = `Hold {Kit.InteractLabel} on the siren switch`,
				done = 0,
				total = 0,
				unit = "",
			}
		end,
		position = function()
			return context.position
		end,
		cleanup = function()
			quietSiren()
			if lamp then
				lamp.Enabled = true
			end
			EnemyService.setQuiet(nil)
		end,
	}
end

return SilenceAlarm
