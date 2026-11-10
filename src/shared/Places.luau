--!strict
-- Which place a trip goes to (docs/LOBBY_MATCH_HANDOFF.md): the real lobby and match ids live
-- in Config.Places; Config.Places.Dev pairs test lobbies with test matches (lobby place id ->
-- match place id), so a launch from a test lobby lands in its own test match and that match
-- flies the squad home to the same test lobby. Nothing else ever needs a test id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Places = {}

-- Where a Lantern launch from this lobby place goes.
function Places.match(): number
	return Config.Places.Dev[game.PlaceId] or Config.Places.Match
end

-- Where this match place sends the squad home (0: no lobby published yet).
function Places.lobby(): number
	for lobby, match in Config.Places.Dev do
		if match == game.PlaceId then
			return lobby
		end
	end
	return Config.Places.Lobby
end

return Places
