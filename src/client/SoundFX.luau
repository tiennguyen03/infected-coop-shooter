--!strict
-- Tiny client sound player. Generated SFX (assets/audio, ids in assets/audio/ASSET_IDS.md)
-- are uploaded audio assets; each has a Roblox built-in (rbxasset) `fallback` that always
-- loads, used while the upload is still in moderation or if it fails. Each play clones the
-- template so rapid sounds overlap instead of restarting.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundBanks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBanks"))

export type SoundName = "shoot" | "hit"

type Definition = { id: string, fallback: string?, volume: number, speed: number?, vary: number? }

local DEFINITIONS: { [string]: Definition } = {
	-- `vary` randomizes pitch a little so rapid fire doesn't sound robotic.
	shoot = {
		id = "rbxassetid://134062568029221",
		fallback = "rbxasset://sounds/snap.mp3",
		volume = 0.5,
		vary = 0.08,
	},
	-- Built-in snap for hits while the player_hits bank is not uploaded (playAt falls
	-- back to it); body shots and headshots are bank groups once it is.
	hit = { id = "rbxasset://sounds/snap.mp3", volume = 0.3, speed = 0.85 },
}

-- Ambience beds under the whole run (2D, quiet; assets/audio README "ambience").
local BEDS = { "amb_city", "amb_wind" }

local SoundFX = {}

local templates: { [string]: Sound } = {}
local variances: { [string]: number } = {}

function SoundFX.play(name: SoundName)
	local template = templates[name]
	if not template then
		return
	end
	local sound = template:Clone()
	local vary = variances[name]
	if vary then
		sound.PlaybackSpeed += (math.random() * 2 - 1) * vary
	end
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- A random variant of a bank group as a 3D one-shot at a world position (a bullet hitting
-- a body, heard from where it hit). Plays the built-in `fallback` when the bank has no id.
function SoundFX.playAt(bank: string, group: string, position: Vector3, fallback: SoundName?)
	if not SoundBanks.has(bank) then
		if fallback then
			SoundFX.play(fallback)
		end
		return
	end
	local rolloff = Config.Audio.Voice
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = SoundBanks.create(group, rolloff.RollOffMin, rolloff.RollOffMax)
	sound.Parent = attachment
	local duration = SoundBanks.play(sound, bank, group)
	task.delay((duration or 0) + 0.1, function()
		attachment:Destroy()
	end)
end

-- One of the named sounds as a 3D one-shot at a world position: another squad member's
-- (player or bot) gunshot, heard from their muzzle. `volume` scales the template's.
function SoundFX.playWorld(name: SoundName, position: Vector3, volume: number?)
	local template = templates[name]
	if not template then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = template:Clone()
	sound.Volume *= volume or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 250
	local vary = variances[name]
	if vary then
		sound.PlaybackSpeed += (math.random() * 2 - 1) * vary
	end
	sound.Parent = attachment
	sound:Play()
	task.delay(math.max(sound.TimeLength, 1) + 0.2, function()
		attachment:Destroy()
	end)
end

-- A random variant of a bank group, 2D (the radio squelch, a menu click). Silent while the
-- bank is not uploaded.
function SoundFX.ui(bank: string, group: string)
	if not SoundBanks.has(bank) then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "UI_" .. group
	sound.Parent = SoundService
	local duration = SoundBanks.play(sound, bank, group)
	task.delay((duration or 0) + 0.1, function()
		sound:Destroy()
	end)
end

-- A 2D loop of a bank group; destroy the returned Sound to stop it.
function SoundFX.loop(bank: string, group: string): Sound?
	if not SoundBanks.has(bank) then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Loop_" .. group
	sound.Parent = SoundService
	if not SoundBanks.loop(sound, bank, group) then
		sound:Destroy()
		return nil
	end
	return sound
end

-- Ragged breathing while the local body is under Config.Audio.LowHealthFraction (and up).
local function watchLowHealth()
	local Players = game:GetService("Players")
	local breathing: Sound? = nil
	while true do
		task.wait(0.5)
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local low = humanoid ~= nil
			and humanoid.Health > 0
			and humanoid.Health / math.max(humanoid.MaxHealth, 1)
				< Config.Audio.LowHealthFraction
		if low and not breathing then
			breathing = SoundFX.loop("player_gear", "low_health")
		elseif not low and breathing then
			breathing:Destroy()
			breathing = nil
		end
	end
end

function SoundFX.init()
	SoundBanks.preload(SoundService)
	for _, bed in BEDS do
		SoundFX.loop("ambience", bed)
	end
	task.spawn(watchLowHealth)
	for name, definition in DEFINITIONS do
		local sound = Instance.new("Sound")
		sound.SoundId = definition.id
		sound.Volume = definition.volume
		sound.PlaybackSpeed = definition.speed or 1
		sound.Parent = SoundService
		templates[name] = sound
		if definition.vary then
			variances[name] = definition.vary
		end
		local fallback = definition.fallback
		if fallback then
			task.spawn(function()
				ContentProvider:PreloadAsync({ sound }, function(_, status)
					if status == Enum.AssetFetchStatus.Failure then
						warn(`SoundFX: {name} ({definition.id}) failed to load, using fallback`)
						sound.SoundId = fallback
						sound.PlaybackSpeed = 2.1
					end
				end)
			end)
		end
	end
end

return SoundFX
