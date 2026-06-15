--!strict
-- Tiny client sound player using Roblox built-in (rbxasset) sounds, which
-- always load — no uploads or moderation involved. Each play clones the
-- template so rapid sounds overlap instead of restarting.

local SoundService = game:GetService("SoundService")

export type SoundName = "shoot" | "hit" | "death" | "levelup"

local DEFINITIONS: { [string]: { id: string, volume: number, speed: number?, vary: number? } } = {
	-- High-pitched snap = a light rifle crack instead of a boom; `vary`
	-- randomizes pitch a little so rapid fire doesn't sound robotic.
	shoot = { id = "rbxasset://sounds/snap.mp3", volume = 0.2, speed = 2.1, vary = 0.15 },
	hit = { id = "rbxasset://sounds/snap.mp3", volume = 0.3, speed = 0.85 },
	death = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.5 },
	levelup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
}

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

function SoundFX.init()
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
	end
end

return SoundFX
