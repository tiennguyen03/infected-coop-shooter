--!strict
-- Server-side 3D voices (sound day 2026-11-07): a Sound on a body part, played from a
-- SoundBanks group, replicated to every player with distance rolloff. One "Voice" Sound per
-- part is reused, so a new line interrupts the previous one (an attack snarl cuts an idle
-- groan). Used for Infected vocals (EnemyService) and the player's pain grunts
-- (EnemyProjectileService.damagePlayer), both heard by the whole squad in co-op.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundBanks = require(ReplicatedStorage.Shared.SoundBanks)

local VOICE_NAME = "Voice"

local WorldSounds = {}

local function voiceOf(part: BasePart, rollOffMin: number, rollOffMax: number): Sound
	local existing = part:FindFirstChild(VOICE_NAME)
	if existing and existing:IsA("Sound") then
		return existing
	end
	local sound = SoundBanks.create(VOICE_NAME, rollOffMin, rollOffMax)
	sound.Parent = part
	return sound
end

-- Plays a random variant of `group` from `bank` on `part`. Returns the clip length or nil
-- when the bank is not uploaded yet (silent, no error).
function WorldSounds.voice(part: BasePart, bank: string, group: string): number?
	if not SoundBanks.has(bank) then
		return nil
	end
	local rolloff = Config.Audio.Voice
	local sound = voiceOf(part, rolloff.RollOffMin, rolloff.RollOffMax)
	return SoundBanks.play(sound, bank, group)
end

function WorldSounds.init()
	SoundBanks.preload(SoundService)
end

return WorldSounds
