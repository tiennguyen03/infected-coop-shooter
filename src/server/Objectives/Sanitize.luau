--!strict
-- Sanitize the Pens (Checkpoint Delta's signature main objective): a fuel can at each of
-- the three screening tents; hold F at one to burn it, in any order. Each fire flushes a
-- wave out of the tents. The fires burn for the rest of the mission. Bots guard the player
-- at each can; only a player lights one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectiveDefinitions = require(ReplicatedStorage.Shared.ObjectiveDefinitions)
local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local Sanitize = {}

local CAN_SIZE = Vector3.new(1.2, 1.6, 0.8)
local CAN_COLOR = Color3.fromRGB(185, 52, 52)
local CHARRED = Color3.fromRGB(30, 28, 26)
local FIRE_COLOR = Color3.fromRGB(255, 140, 40)

function Sanitize.new(context: Types.Context): Types.Objective
	local row = context.row
	local points: { Vector3 } = {}
	local tents: { ObjectiveDefinitions.Vec } = context.site.Points or {}
	for _, vec in tents do
		table.insert(points, Kit.v3(vec))
	end
	local total = #points
	local burnt = 0
	-- The cans not yet lit, by point index.
	local cans: { [number]: Part } = {}

	local function burn(index: number)
		local can = cans[index]
		if not can then
			return
		end
		cans[index] = nil
		burnt += 1
		for _, child in can:GetChildren() do
			child:Destroy() -- its prompt and its marker
		end
		can.Color = CHARRED
		local fire = Instance.new("Fire")
		fire.Size = 14
		fire.Heat = 12
		fire.Color = FIRE_COLOR
		fire.SecondaryColor = Color3.fromRGB(120, 40, 20)
		fire.Parent = can
		local light = Instance.new("PointLight")
		light.Color = FIRE_COLOR
		light.Range = 28
		light.Brightness = 1.5
		light.Shadows = false
		light.Parent = can
		Kit.wave(row.BurnWave, points[index])
		if burnt >= total then
			context.complete()
		end
	end

	for index, point in points do
		local can = Kit.block(context.folder, "FuelCan", CAN_SIZE, CFrame.new(point), CAN_COLOR)
		cans[index] = can
		Kit.marker(can, context, "Burn the tent", 4)
		Kit.prompt(can, "Burn the tent", "Fuel can", row.Hold or 3, function()
			burn(index)
		end)
	end

	return {
		begin = function() end,
		step = function()
			if total == 0 then
				context.complete() -- a site with no tents cannot hold the run up
			end
		end,
		progress = function(): Types.Progress
			return {
				step = "Hold F at each fuel can to burn the tents",
				done = burnt,
				total = total,
				unit = "count",
			}
		end,
		position = function()
			for index, point in points do
				if cans[index] then
					return point
				end
			end
			return context.position
		end,
		cleanup = function() end,
	}
end

return Sanitize
