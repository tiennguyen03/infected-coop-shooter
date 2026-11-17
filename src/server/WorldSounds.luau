--!strict
-- Server-side 3D sounds, replicated to every player with distance rolloff (assets/audio
-- README "Where each sound plays"). Three shapes:
--   voice / on   a Sound on a part, reused per slot: a new line interrupts the previous one
--                in that slot ("Voice" for vocals, "Gear" for reloads, "Move" for rolls).
--   at           a one-shot at a world position (blasts, landings, the Warden's fists).
--   loopOn       a looping clip on a part until the part goes or `stop` (a flare, a drone).
--   global       a 2D one-shot the whole squad hears (a squad member KIA).
-- Every call is silent (returns nil) while its bank is not uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundBanks = require(ReplicatedStorage.Shared.SoundBanks)

local VOICE_NAME = "Voice"

local WorldSounds = {}

type Rolloff = { RollOffMin: number, RollOffMax: number }

-- Groups that carry across the map (blasts, the rotor, the siren) use Config.Audio.Far.
local function rolloffFor(group: string): Rolloff
	if Config.Audio.FarGroups[group] then
		return Config.Audio.Far
	end
	return Config.Audio.Voice
end

local function slotOf(part: BasePart, slot: string, rolloff: Rolloff): Sound
	local existing = part:FindFirstChild(slot)
	if existing and existing:IsA("Sound") then
		return existing
	end
	local sound = SoundBanks.create(slot, rolloff.RollOffMin, rolloff.RollOffMax)
	sound.Parent = part
	return sound
end

-- Plays a random variant of `group` from `bank` in `slot` on `part`.
function WorldSounds.on(part: BasePart, bank: string, group: string, slot: string): number?
	if not SoundBanks.has(bank) then
		return nil
	end
	return SoundBanks.play(slotOf(part, slot, rolloffFor(group)), bank, group)
end

-- Vocals: the "Voice" slot (Infected lines, the player's pain grunts).
function WorldSounds.voice(part: BasePart, bank: string, group: string): number?
	return WorldSounds.on(part, bank, group, VOICE_NAME)
end

-- Stops whatever `slot` on `part` is playing (a reload cut short by a roll).
function WorldSounds.stop(part: BasePart, slot: string)
	local sound = part:FindFirstChild(slot)
	if sound and sound:IsA("Sound") then
		sound:Stop()
	end
end

-- A one-shot at `position`; `volume` scales the group's volume, `speed` is the playback
-- speed (pitch; 1 when nil).
function WorldSounds.at(
	position: Vector3,
	bank: string,
	group: string,
	volume: number?,
	speed: number?
): number?
	if not SoundBanks.has(bank) then
		return nil
	end
	local rolloff = rolloffFor(group)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Sound_" .. group
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = SoundBanks.create(group, rolloff.RollOffMin, rolloff.RollOffMax)
	sound.PlaybackSpeed = speed or 1
	sound.Parent = attachment
	local duration = SoundBanks.play(sound, bank, group, SoundBanks.volume(group) * (volume or 1))
	task.delay((duration or 0) + 0.2, function()
		attachment:Destroy()
	end)
	return duration
end

-- A looping clip on `part` (gone with the part). Returns the Sound for `stop`, or nil.
function WorldSounds.loopOn(part: BasePart, bank: string, group: string): Sound?
	if not SoundBanks.has(bank) then
		return nil
	end
	local rolloff = rolloffFor(group)
	local sound = SoundBanks.create("Loop_" .. group, rolloff.RollOffMin, rolloff.RollOffMax)
	sound.Parent = part
	if not SoundBanks.loop(sound, bank, group) then
		sound:Destroy()
		return nil
	end
	return sound
end

-- A 2D one-shot every player hears at the same level.
function WorldSounds.global(bank: string, group: string): number?
	if not SoundBanks.has(bank) then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Global_" .. group
	sound.Parent = workspace
	local duration = SoundBanks.play(sound, bank, group)
	task.delay((duration or 0) + 0.2, function()
		sound:Destroy()
	end)
	return duration
end

function WorldSounds.init()
	SoundBanks.worldGroup() -- made now so clients find it before the first sound
	SoundBanks.preload(SoundService)
end

return WorldSounds
