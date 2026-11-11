--!strict
-- The Loadmaster's book (docs/sprints/LOBBY_V1_FALLOW.md > Loadmaster and Loadout): each
-- soldier signs for a Loadout at his desk (LoadmasterUI, the Loadout remote) and it rides
-- the Lantern into the match as teleport data (LaunchService, Rules/Handoff). The server
-- checks every request with the same rules and catalog the match uses (Rules/Loadout,
-- ArmsRoom) and against the soldier's record (RecordService: only guns bought at the
-- Quartermaster's rack, or issued free).
--
-- Kept between visits (owner, 2026-11-10): the signed Loadout is saved per soldier
-- (SaveSlot, DataStore Config.Lobby.Save.Store, key "u_<UserId>", Rules/LoadoutSave) and
-- loaded when they join, so it rides the Lantern even if they never stop at the desk, and the
-- Loadout screen opens on it. A saved Loadout naming a gun no longer on the record (signed
-- before buying existed) falls back to the default.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local LoadoutSave = require(ReplicatedStorage.Shared.Rules.LoadoutSave)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RecordService = require(script.Parent.RecordService)
local SaveSlot = require(script.Parent.SaveSlot)

local LoadmasterService = {}

local signed: { [Player]: Loadout.Loadout } = {}
local remote: RemoteEvent
local slot: SaveSlot.Slot

local function isValid(entry: unknown): boolean
	return (Loadout.validate(entry, ArmsRoom.catalog()))
end

local function copy(source: Loadout.Loadout): Loadout.Loadout
	return {
		primary = source.primary,
		secondary = source.secondary,
		grenade = source.grenade,
		callIns = table.clone(source.callIns),
	}
end

-- Signs `loadout` for `player`. Its primary is the gun they carry on the ship: the Weapon
-- attribute is what the match's PlayerSetup.attachRifle (PikeBody) reads and follows.
local function sign(player: Player, loadout: Loadout.Loadout)
	signed[player] = loadout
	player:SetAttribute(Attributes.Weapon, loadout.primary)
end

local function load(player: Player)
	local loadout = LoadoutSave.decode(slot:load(player), isValid)
	if not loadout or not RecordService.allows(player, loadout) then
		return
	end
	-- A pick signed while the load was in flight is newer: keep it.
	if player.Parent and not signed[player] then
		sign(player, loadout)
		remote:FireClient(player, Messages.Loadout.Signed, loadout)
	end
end

-- Every signed Loadout among `players`, keyed by UserId (unsigned soldiers are left out and
-- fly the default).
function LoadmasterService.loadoutsFor(players: { Player }): { [number]: Loadout.Loadout }
	local out: { [number]: Loadout.Loadout } = {}
	for _, player in players do
		local loadout = signed[player]
		if loadout then
			out[player.UserId] = loadout
		end
	end
	return out
end

function LoadmasterService.init()
	remote = Remotes.get("Loadout")
	slot = SaveSlot.new(Config.Lobby.Save.Store, "u_")

	remote.OnServerEvent:Connect(function(player: Player, kind: unknown, requested: unknown)
		if kind ~= Messages.Loadout.Request then
			return
		end
		local valid, reason = Loadout.validate(requested, ArmsRoom.catalog())
		if valid then
			valid, reason = RecordService.allows(player, requested :: Loadout.Loadout)
		end
		if valid then
			local pick = copy(requested :: Loadout.Loadout)
			sign(player, pick)
			slot:save(player, LoadoutSave.encode(pick))
		end
		remote:FireClient(player, Messages.Loadout.Result, valid, reason)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		signed[player] = nil
	end)
end

return LoadmasterService
