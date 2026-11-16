--!strict
-- The sounds of a working ship (Nova, 2026-11-11: "noises that one would hear on a boat. people
-- moving around, crew mumbling, give some life to it"). Config.Lobby.Ambience lists them:
--   * a bed per area, heard everywhere in it: the hangar's carrier hallway, the flight deck's
--     wind and water. Roblox has no walls for sound, so the two cross-fade by the soldier's
--     height (above DeckHeight: the deck);
--   * spots: loops at the ship's anchors (FallowLayout.Ambience, built by FallowBuilder): the
--     Plot's radio, crew talking low; each only in its area;
--   * one-shots now and then from a random anchor of their area: doors, lockers, a horn, the
--     deck's loudspeaker.
-- All local (nothing replicates), in one SoundGroup that fades in on arrival and out when the
-- Lantern lifts, like LobbyMusic. The walking crew's footsteps are CrewWalk's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ShipAmbience = {}

local AMB = Config.Lobby.Ambience

type Area = "Hangar" | "Deck"
type Bed = { Id: string, Volume: number }
type Spot = { Id: string, Volume: number, Near: number, Far: number, Area: string }

local BEDS = AMB.Beds :: { [string]: Bed }
local SPOTS = AMB.Spots :: { [string]: Spot }
type Voice = { sound: Sound, volume: number, area: Area }

local group: SoundGroup
local voices: { Voice } = {} -- every loop, scaled by its area's weight
local weight: { [string]: number } = { Hangar = 1, Deck = 0 }
local random = Random.new()

local function fade(volume: number, seconds: number)
	TweenService:Create(
		group,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = volume }
	):Play()
end

local function newSound(id: string, parent: Instance, near: number?, far: number?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.SoundGroup = group
	if near and far then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = near
		sound.RollOffMaxDistance = far
	end
	sound.Parent = parent
	return sound
end

local function anchors(folder: Instance, key: string): { BasePart }
	local list = {}
	for _, child in folder:GetChildren() do
		if child.Name == key and child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

local function loop(sound: Sound, volume: number, area: Area)
	sound.Looped = true
	sound.Volume = volume * weight[area]
	-- Start somewhere inside the clip, so two anchors of one loop never play in step.
	sound.Loaded:Once(function()
		sound.TimePosition = random:NextNumber(0, math.max(sound.TimeLength - 1, 0))
	end)
	sound:Play()
	table.insert(voices, { sound = sound, volume = volume, area = area })
end

-- Now and then a one-shot from a random anchor of its area (the area you are not in is
-- quiet, so its one-shots are skipped).
local function oneShots(folder: Instance)
	if #AMB.OneShots == 0 then
		return
	end
	task.spawn(function()
		while true do
			task.wait(random:NextNumber(AMB.OneShotGap[1], AMB.OneShotGap[2]))
			local shot = AMB.OneShots[random:NextInteger(1, #AMB.OneShots)]
			local scale = weight[shot.Area] or 0
			local points = anchors(folder, shot.Area)
			if scale > 0.1 and #points > 0 then
				local at = points[random:NextInteger(1, #points)]
				local sound = newSound(shot.Id, at, AMB.OneShotNear, AMB.OneShotFar)
				sound.Volume = shot.Volume * scale
				sound.PlaybackSpeed = random:NextNumber(0.94, 1.04)
				sound.Ended:Once(function()
					sound:Destroy()
				end)
				sound:Play()
				task.delay(30, function() -- in case the clip never loads
					if sound.Parent then
						sound:Destroy()
					end
				end)
			end
		end
	end)
end

-- Cross-fades the areas' weights toward where the soldier stands.
local function follow(dt: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local onDeck = root.Position.Y > AMB.DeckHeight
	local step = dt / math.max(AMB.CrossFadeSeconds, 0.05)
	local deck = math.clamp(weight.Deck + (if onDeck then step else -step), 0, 1)
	if deck == weight.Deck then
		return
	end
	weight.Deck = deck
	weight.Hangar = 1 - deck
	for _, voice in voices do
		voice.sound.Volume = voice.volume * weight[voice.area]
	end
end

function ShipAmbience.init()
	group = Instance.new("SoundGroup")
	group.Name = "Ambience"
	group.Volume = 0
	group.Parent = SoundService

	for area, bed in BEDS do
		loop(newSound(bed.Id, SoundService), bed.Volume, area :: Area)
	end

	task.spawn(function()
		local ship = Workspace:WaitForChild("Fallow", 60)
		local folder = ship and ship:WaitForChild("Ambience", 60)
		if not folder then
			return
		end
		if not game:IsLoaded() then
			game.Loaded:Wait() -- every anchor has arrived (the lobby does not stream)
		end
		for key, spot in SPOTS do
			for _, at in anchors(folder, key) do
				loop(newSound(spot.Id, at, spot.Near, spot.Far), spot.Volume, spot.Area :: Area)
			end
		end
		oneShots(folder)
	end)

	RunService.Heartbeat:Connect(follow)

	local lifting = false
	Remotes.get("Launch").OnClientEvent:Connect(function(kind: string)
		if kind == Messages.Launch.Lifting then
			lifting = true
			fade(0, AMB.FadeOutSeconds)
		elseif lifting and (kind == Messages.Launch.Failed or kind == Messages.Launch.Cleared) then
			lifting = false
			fade(AMB.Volume, AMB.FadeInSeconds)
		end
	end)
	fade(AMB.Volume, AMB.FadeInSeconds)
end

return ShipAmbience
