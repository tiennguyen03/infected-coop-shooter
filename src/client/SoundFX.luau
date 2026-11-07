--!strict
-- Tiny client sound player. Generated SFX (assets/audio, ids in assets/audio/ASSET_IDS.md)
-- are uploaded audio assets; each has a Roblox built-in (rbxasset) `fallback` that always
-- loads, used while the upload is still in moderation or if it fails. Each play clones the
-- template so rapid sounds overlap instead of restarting.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

export type SoundName = "shoot" | "hit" | "headshot" | "death" | "levelup"

type Definition = { id: string, fallback: string?, volume: number, speed: number?, vary: number? }

local DEFINITIONS: { [string]: Definition } = {
	-- `vary` randomizes pitch a little so rapid fire doesn't sound robotic.
	shoot = {
		id = "rbxassetid://134062568029221",
		fallback = "rbxasset://sounds/snap.mp3",
		volume = 0.5,
		vary = 0.08,
	},
	hit = { id = "rbxasset://sounds/snap.mp3", volume = 0.3, speed = 0.85 },
	-- Placeholder until the sound day: the hit snap, sharper and louder, so a headshot
	-- is heard before the number is read.
	headshot = { id = "rbxasset://sounds/snap.mp3", volume = 0.55, speed = 1.35 },
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
