--!strict
-- Soldiers' bodies in their own collision group (Config.Player.Collision): players and bots
-- collide with the world and each other as before, but not with the Infected unless
-- BlockInfected (a chasing Runner used to shove a soldier, and a pile of them lifted one into
-- the air). StanceService puts a standing body back in this group, not "Default".
--
-- The Hocker's spit (EnemyProjectileService) casts in ShotGroup: the Enemy group's rules
-- copied (other Infected, gore, ladders and prone limbs never stop it) but soldiers hit.
-- Boots after every service that registers a group the spit must copy (Arena, Stance, Gore,
-- Vehicle).

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SETTINGS = Config.Player.Collision
local ENEMY_GROUP = "Enemy"
local PRONE_GROUP = "ProneBody" -- StanceService's: collides with nothing

local SoldierCollision = {}

SoldierCollision.Group = SETTINGS.Group
SoldierCollision.ShotGroup = SETTINGS.ShotGroup

local function register(group: string)
	if not PhysicsService:IsCollisionGroupRegistered(group) then
		PhysicsService:RegisterCollisionGroup(group)
	end
end

local function claim(part: Instance)
	if part:IsA("BasePart") and part.CollisionGroup == "Default" then
		part.CollisionGroup = SETTINGS.Group
	end
end

-- Puts `character`'s body (and anything added to it later: the rifle, kit) in the group.
function SoldierCollision.apply(character: Model)
	for _, part in character:GetDescendants() do
		claim(part)
	end
	character.DescendantAdded:Connect(claim)
end

local function setupGroups()
	register(ENEMY_GROUP)
	register(SETTINGS.Group)
	register(SETTINGS.ShotGroup)
	PhysicsService:CollisionGroupSetCollidable(SETTINGS.Group, ENEMY_GROUP, SETTINGS.BlockInfected)
	if PhysicsService:IsCollisionGroupRegistered(PRONE_GROUP) then
		PhysicsService:CollisionGroupSetCollidable(SETTINGS.Group, PRONE_GROUP, false)
	end
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		local name = group.name
		if name ~= SETTINGS.ShotGroup and name ~= SETTINGS.Group then
			PhysicsService:CollisionGroupSetCollidable(
				SETTINGS.ShotGroup,
				name,
				PhysicsService:CollisionGroupsAreCollidable(ENEMY_GROUP, name)
			)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(SETTINGS.ShotGroup, SETTINGS.ShotGroup, false)
	PhysicsService:CollisionGroupSetCollidable(SETTINGS.ShotGroup, SETTINGS.Group, true)
end

function SoldierCollision.init()
	setupGroups()
	local function watch(player: Player)
		player.CharacterAdded:Connect(SoldierCollision.apply)
		if player.Character then
			SoldierCollision.apply(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- Squad bots (BotService tags each rig as it spawns).
	CollectionService:GetInstanceAddedSignal("SquadBot"):Connect(function(rig: Instance)
		if rig:IsA("Model") then
			SoldierCollision.apply(rig)
		end
	end)
	for _, rig in CollectionService:GetTagged("SquadBot") do
		if rig:IsA("Model") then
			SoldierCollision.apply(rig)
		end
	end
end

return SoldierCollision
