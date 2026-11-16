--!strict
-- Secure the Site (shared main objective): a hold zone at the drawn site. Seconds add up
-- while any living squad member (player or bot) stands in it; stepping out pauses the hold,
-- never resets it. Bots follow their leader, so they hold it with them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Rules.Objectives)
local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local Server = script.Parent.Parent
local Squad = require(Server.Squad)

local SecureSite = {}

function SecureSite.new(context: Types.Context): Types.Objective
	local row, site = context.row, context.site
	local total = row.Seconds or 45
	local zone: Part? =
		Kit.zone(context.folder, context.position, Kit.v3(site.Size or { 46, 1, 46 }))
	Kit.marker(zone :: Part, context, nil, 10)
	local held = 0
	local playersIn, playersLiving = 0, 0

	return {
		begin = function() end,
		step = function(deltaTime: number)
			local part = zone
			if not part then
				return
			end
			local anyone, inside, living = Squad.zoneCount(part)
			playersIn, playersLiving = inside, living
			held = Rules.hold(held, deltaTime, anyone, total)
			if held >= total then
				part:Destroy()
				zone = nil
				context.complete()
			end
		end,
		progress = function(): Types.Progress
			local step = "Hold the zone"
			if playersLiving > 1 then
				step ..= `  ·  {playersIn} of {playersLiving} in`
			end
			return { step = step, done = held, total = total, unit = "s" }
		end,
		position = function()
			return context.position
		end,
		cleanup = function() end,
	}
end

return SecureSite
