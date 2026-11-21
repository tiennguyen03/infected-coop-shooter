--!strict
-- Silence the Alarm and its kin (a signature side objective on a map with a noise to stop:
-- Checkpoint Delta's Gate siren, Mile 14's stuck bus horn). The noise loops on the map's
-- part named by the row's Target until a player holds E on the switch at the site. With a
-- Noise row the sound also wakes the Infected: a noise every Noise.Every seconds, Noise.Reach
-- studs round it (EnemyService.noise), until it is off. Once off, roaming Infected appear
-- near it far less often (EnemyService.setQuiet) for the rest of the mission. Bots guard the
-- player at the switch. The row's words fall back to the Gate siren's.

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
	local target = row.Target or "Siren"
	local sound = row.Sound or "amb_siren"
	local prompt = row.Prompt or "Shut off the siren"
	local object = row.Object or "Siren switch"
	local stepText = row.Step or "on the siren switch"

	local box =
		Kit.block(context.folder, "SirenSwitch", BOX_SIZE, CFrame.new(context.position), BOX_COLOR)
	Kit.marker(box, context, nil, 5)

	-- The noise's source on the map (Delta: the siren head on the Gate's lamp post).
	local head = workspace:FindFirstChild(target, true)
	local lamp = head and head:FindFirstChildOfClass("PointLight")
	local loop: Sound? = nil
	if head and head:IsA("BasePart") then
		loop = WorldSounds.loopOn(head, "ambience", sound)
	end
	local source = if head and head:IsA("BasePart") then head.Position else context.position

	-- The noise it makes for the Infected until it is off.
	local live = true
	local noise = row.Noise
	if noise then
		task.spawn(function()
			while live do
				EnemyService.noise(source, noise.Reach)
				task.wait(noise.Every)
			end
		end)
	end

	local function quiet()
		live = false
		if loop then
			loop:Destroy()
			loop = nil
		end
	end

	Kit.prompt(box, prompt, object, row.Hold or 4, function()
		quiet()
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
				step = `Hold {Kit.InteractLabel} {stepText}`,
				done = 0,
				total = 0,
				unit = "",
			}
		end,
		position = function()
			return context.position
		end,
		cleanup = function()
			quiet()
			if lamp then
				lamp.Enabled = true
			end
			EnemyService.setQuiet(nil)
		end,
	}
end

return SilenceAlarm
