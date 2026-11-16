--!strict
-- Clear the Spitters (shared side objective): when the squad gets close, row.Count Hockers
-- (plus row.PerExtraPlayer per living player beyond the first) stand round the site,
-- outlined, and a timer starts. Kill them all before it runs out for the Resupply burst
-- (row.Supply, paid by ObjectiveService). Out of time: the outlines go, the Hockers stay,
-- nothing else is lost. Bots shoot them like any other Infected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Rules.Objectives)
local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local Server = script.Parent.Parent
local DifficultyService = require(Server.DifficultyService)
local EnemyService = require(Server.EnemyService)

local ClearSpitters = {}

function ClearSpitters.new(context: Types.Context): Types.Objective
	local row = context.row
	local anchor = Kit.point(context.folder, "SpittersPoint", context.position)
	local marker = Kit.marker(anchor, context, nil, 8)
	local hunt: Kit.Hunt? = nil
	local timeLeft = row.Seconds or 120

	return {
		begin = function()
			local count = Rules.scaled(
				row.Count or 3,
				row.PerExtraPlayer,
				DifficultyService.getExtraPlayers()
			)
			local points: { Vector3 } = {}
			for _ = 1, count do
				table.insert(points, EnemyService.groundNear(context.position, 6, 18))
			end
			hunt = Kit.hunt(row.Form or "Hocker", points, count)
		end,
		step = function(deltaTime: number)
			local current = hunt
			if not current then
				return
			end
			if current.left() <= 0 then
				marker:Destroy()
				context.complete()
				return
			end
			timeLeft = Rules.countdown(timeLeft, deltaTime)
			if timeLeft <= 0 then
				current.release()
				marker:Destroy()
				context.fail()
			end
		end,
		progress = function(): Types.Progress
			local current = hunt
			if not current then
				return { step = "Find the Spitters", done = 0, total = 0, unit = "" }
			end
			return {
				step = "Kill the outlined Spitters",
				done = current.total - current.left(),
				total = current.total,
				unit = "count",
				timeLeft = timeLeft,
			}
		end,
		position = function()
			return context.position
		end,
		cleanup = function() end,
	}
end

return ClearSpitters
