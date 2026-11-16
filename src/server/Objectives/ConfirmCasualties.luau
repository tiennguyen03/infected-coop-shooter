--!strict
-- Confirm Casualties (shared main objective): when the squad reaches the site, row.Count
-- heavy Infected (plus row.PerExtraPlayer per living player beyond the first) stand at the
-- site's Spawns, each outlined. Kill them all. Bots shoot them like any other Infected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectiveDefinitions = require(ReplicatedStorage.Shared.ObjectiveDefinitions)
local Rules = require(ReplicatedStorage.Shared.Rules.Objectives)
local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local Server = script.Parent.Parent
local DifficultyService = require(Server.DifficultyService)

local ConfirmCasualties = {}

function ConfirmCasualties.new(context: Types.Context): Types.Objective
	local row = context.row
	local anchor = Kit.point(context.folder, "CasualtiesPoint", context.position)
	local marker = Kit.marker(anchor, context, nil, 8)
	local hunt: Kit.Hunt? = nil

	return {
		begin = function()
			local points: { Vector3 } = {}
			local spawns: { ObjectiveDefinitions.Vec } = context.site.Spawns or {}
			for _, vec in spawns do
				table.insert(points, Kit.v3(vec))
			end
			-- A different set of aisles each time.
			for index = #points, 2, -1 do
				local other = math.random(index)
				points[index], points[other] = points[other], points[index]
			end
			if #points == 0 then
				points = { context.position }
			end
			local count = Rules.scaled(
				row.Count or 3,
				row.PerExtraPlayer,
				DifficultyService.getExtraPlayers()
			)
			hunt = Kit.hunt(row.Form or "Brute", points, count)
		end,
		step = function()
			local current = hunt
			if current and current.left() <= 0 then
				marker:Destroy()
				context.complete()
			end
		end,
		progress = function(): Types.Progress
			local current = hunt
			if not current then
				return { step = "Find the heavy Infected", done = 0, total = 0, unit = "" }
			end
			return {
				step = "Kill the outlined heavy Infected",
				done = current.total - current.left(),
				total = current.total,
				unit = "count",
			}
		end,
		position = function()
			return context.position
		end,
		cleanup = function() end,
	}
end

return ConfirmCasualties
