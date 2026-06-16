--!strict
-- Player XP and levels. XP (progress toward next level), Level, and
-- XPRequired live as player attributes so the client UI updates through
-- replication with no remote traffic. Other systems award XP exclusively
-- through XPService.addXP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local XPService = {}

local levelUpListeners: { (player: Player, newLevel: number) -> () } = {}

-- Systems register here to react to each level gained (ItemService offers an
-- item selection; ItemEffectService grants Kevlar shield).
function XPService.addLevelUpListener(listener: (player: Player, newLevel: number) -> ())
	table.insert(levelUpListeners, listener)
end

local function requiredForLevel(level: number): number
	return math.floor(Config.XP.BaseThreshold * Config.XP.ThresholdGrowth ^ (level - 1))
end

local function setupPlayer(player: Player)
	player:SetAttribute("XP", 0)
	player:SetAttribute("Level", 1)
	player:SetAttribute("XPRequired", requiredForLevel(1))
end

function XPService.addXP(player: Player, amount: number)
	-- Field Manual: +% XP gained.
	amount *= 1 + ((player:GetAttribute("XPGainMult") :: number?) or 0)

	local xp = (player:GetAttribute("XP") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1

	local startLevel = level
	xp += amount
	local required = requiredForLevel(level)
	while xp >= required do
		xp -= required
		level += 1
		required = requiredForLevel(level)
		print(`[XPService] {player.Name} reached level {level}`)
	end

	player:SetAttribute("XP", xp)
	player:SetAttribute("Level", level)
	player:SetAttribute("XPRequired", required)

	for reached = startLevel + 1, level do
		for _, listener in levelUpListeners do
			listener(player, reached)
		end
	end
end

function XPService.resetPlayer(player: Player)
	setupPlayer(player)
end

function XPService.init()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return XPService
