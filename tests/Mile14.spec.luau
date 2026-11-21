--!strict
-- Mile 14's v2 layout and its objective pool (src/server/Missions/Mile14Data.luau,
-- ObjectiveDefinitions.Maps.mile14): every place a squad is sent is inside the 640 x 900
-- frame, the trip is one way, and the convoy is Control's 24 buses.

local Data = require("../src/server/Missions/Mile14Data")
local Definitions = require("../src/shared/ObjectiveDefinitions")

local HALF_X, HALF_Z = 320, 450

local function check(ok: boolean, message: string)
	if not ok then
		error(message, 2)
	end
end

local function inside(point: { number }, what: string)
	check(
		math.abs(point[1]) <= HALF_X and math.abs(point[3]) <= HALF_Z,
		`{what} ({point[1]}, {point[3]}) is outside the frame`
	)
end

return {
	["frame is 640 x 900"] = function()
		check(Data.Size[1] == 640 and Data.Size[2] == 900, "frame size")
	end,

	["every Maps.mile14 site, To and BossFrom is inside the frame"] = function()
		local map = Definitions.Maps.mile14
		check(map ~= nil, "no Maps.mile14")
		for id, sites in map.Sites do
			for _, site in sites do
				inside(site.Position, `{id} at {site.Name}`)
				for _, point in site.Points or {} do
					inside(point, `{id} point`)
				end
				for _, point in site.Spawns or {} do
					inside(point, `{id} spawn`)
				end
				if site.To then
					inside(site.To, `{id} To`)
				end
				if site.BossFrom then
					inside(site.BossFrom, `{id} BossFrom`)
				end
			end
		end
	end,

	["Landing, Extract and every Boss point are inside the frame"] = function()
		inside(Data.Landing, "Landing")
		inside(Data.Extract, "Extract")
		inside(Data.Boss.Spawn, "Boss spawn")
		for _, point in Data.Boss.Waypoints do
			inside(point, "Boss waypoint")
		end
		inside(Data.Hold, "Hold")
	end,

	["Landing and Extract are at least 400 studs apart (one way)"] = function()
		local dx, dz = Data.Landing[1] - Data.Extract[1], Data.Landing[3] - Data.Extract[3]
		check(math.sqrt(dx * dx + dz * dz) >= 400, "the pads are too close for a one-way trip")
	end,

	["24 buses"] = function()
		local buses = 0
		for _, piece in Data.Dressing do
			if piece.name == "env_bus" then
				buses += 1
			end
		end
		check(buses == 24, `{buses} buses`)
	end,

	["a part named Horn exists (Kill the Horn's noise)"] = function()
		local found = false
		for _, part in Data.Parts do
			found = found or part.name == "Horn"
		end
		check(found, "no Horn part")
		check(
			Definitions.Rows.kill_horn ~= nil and Definitions.Rows.kill_horn.Target == "Horn",
			"kill_horn targets the Horn"
		)
	end,

	["no hill pokes outside the frame"] = function()
		for _, hill in Data.Hills do
			check(
				math.abs(hill.x) + hill.top[1] / 2 <= HALF_X + 0.01
					and math.abs(hill.z) + hill.top[2] / 2 <= HALF_Z + 0.01,
				`{hill.name} pokes outside the frame`
			)
		end
	end,

	["every part's kind has a look"] = function()
		local kinds = {
			grass = true,
			slope = true,
			road = true,
			concrete = true,
			building = true,
			steel = true,
			glass = true,
			red = true,
			pad = true,
			patch = true,
			line = true,
			sign = true,
		}
		for _, part in Data.Parts do
			check(kinds[part.kind] == true, `{part.name}: unknown kind {part.kind}`)
		end
	end,

	-- A bus (env_bus, 42.9 x 10.9) facing south covers x +-5.45 and z +-21.45 round its spot.
	["no objective prop or switch is inside a bus"] = function()
		local function insideBus(point: { number }): string?
			for _, piece in Data.Dressing do
				if piece.name == "env_bus" and math.abs(piece.yaw + 90) < 10 then
					if
						math.abs(point[1] - piece.x) < 5.45 + 1.5
						and math.abs(point[3] - piece.z) < 21.45 + 1.5
					then
						return `bus at ({piece.x}, {piece.z})`
					end
				end
			end
			return nil
		end
		local map = Definitions.Maps.mile14
		for _, id in { "burn_buses", "kill_horn" } do
			for _, site in map.Sites[id] do
				for _, point in site.Points or { site.Position } do
					local hit = insideBus(point)
					check(hit == nil, `{id} point ({point[1]}, {point[3]}) is inside the {hit}`)
				end
			end
		end
	end,

	["buses on the deck stand on the road, not on a roof above them"] = function()
		for _, piece in Data.Dressing do
			if piece.name == "env_bus" and math.abs(piece.x) < 56 then
				check(piece.floor ~= nil, `bus at ({piece.x}, {piece.z}) has no floor`)
			end
		end
	end,
}
