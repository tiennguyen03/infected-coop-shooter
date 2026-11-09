--!strict
-- Sound banks. Every generated variant clip lives inside one packed
-- bank wav per speaker (assets/audio/build/generate.py BANKS): one Roblox audio asset per
-- bank, and a clip is played by seeking the Sound to the clip's offset and stopping it after
-- the clip's length. Offsets come from the generated SoundBankData; ids and the per-group
-- volumes live here and in Config.Audio. A group is a clip name without its _<n> suffix
-- (walker_idle_1..3 -> "walker_idle"); `pick` draws a random variant and never repeats the
-- previous one, so a crowd of Infected does not chant one groan.
--
-- Works on both the server (3D voices on enemy heads, replicated to every player) and the
-- client (footsteps, hit sounds). A Sound must be loaded before a seek lands, so each side
-- preloads the bank assets once in `preload`.

local ContentProvider = game:GetService("ContentProvider")

local Config = require(script.Parent.Config)
local SoundBankData = require(script.Parent.SoundBankData)

export type Clip = { start: number, length: number }

-- Uploaded bank audio ids (assets/audio/ASSET_IDS.md). "" = not uploaded yet: the bank is
-- silent and `play` returns nil.
local IDS: { [string]: string } = {
	player_steps = "rbxassetid://100789185448666",
	player_hits = "rbxassetid://91277491081004",
	walker = "rbxassetid://78379861633223",
	runner = "rbxassetid://77436367980865",
	brute = "rbxassetid://109978857666947",
	hocker = "rbxassetid://123541518944531",
	-- sound pass 2026-11-08
	player_gear = "rbxassetid://71009256896523",
	callins = "rbxassetid://110309276934239",
	warden = "rbxassetid://77678057873649",
	ui_radio = "rbxassetid://71130678294211",
	ambience = "rbxassetid://98770253514208",
	-- each gun's own shot and reload (Config.Weapons.<id>.Sound), 2026-11-09
	guns = "rbxassetid://97998220606581",
}

local SoundBanks = {}

-- bank -> group -> clip names, built once from the generated data.
local groups: { [string]: { [string]: { string } } } = {}
local lastPick: { [string]: string } = {}
-- The clip a Sound is currently playing: a stop scheduled for an older clip must not cut a
-- newer one that reused the same Sound.
local playTokens: { [Sound]: number } = setmetatable({}, { __mode = "k" }) :: any
local nextToken = 0

local function groupOf(clip: string): string
	local group = clip:match("^(.-)_%d+$")
	return group or clip
end

local function build()
	for bank, clips in SoundBankData :: { [string]: { [string]: Clip } } do
		local byGroup: { [string]: { string } } = {}
		for clip in clips do
			local group = groupOf(clip)
			local list = byGroup[group]
			if not list then
				list = {}
				byGroup[group] = list
			end
			table.insert(list, clip)
		end
		for _, list in byGroup do
			table.sort(list)
		end
		groups[bank] = byGroup
	end
end

build()

function SoundBanks.id(bank: string): string?
	local id = IDS[bank]
	if id and id ~= "" then
		return id
	end
	return nil
end

function SoundBanks.has(bank: string): boolean
	return groups[bank] ~= nil and SoundBanks.id(bank) ~= nil
end

-- True when `bank` is uploaded and has clips for `group`.
function SoundBanks.hasGroup(bank: string, group: string): boolean
	local bankGroups = groups[bank]
	return SoundBanks.has(bank) and bankGroups ~= nil and bankGroups[group] ~= nil
end

function SoundBanks.volume(group: string): number
	return Config.Audio.Volumes[group] or Config.Audio.DefaultVolume
end

-- A random variant of `group` in `bank`, never the one picked last time (when there are
-- at least two). Returns the clip name and its offsets, or nil when the bank is not loaded.
function SoundBanks.pick(bank: string, group: string): (string?, Clip?)
	local bankGroups = groups[bank]
	local list = bankGroups and bankGroups[group]
	if not list or #list == 0 then
		return nil, nil
	end
	local key = bank .. "/" .. group
	local clip = list[math.random(#list)]
	if #list > 1 and clip == lastPick[key] then
		clip = list[(table.find(list, clip) :: number) % #list + 1]
	end
	lastPick[key] = clip
	return clip, SoundBankData[bank][clip]
end

-- Seeks `sound` to a random variant of the group and plays it; the sound stops itself when
-- the clip ends. Returns the clip length in seconds (at the sound's playback speed), or
-- nil when the bank has no id yet.
function SoundBanks.play(sound: Sound, bank: string, group: string, volume: number?): number?
	local id = SoundBanks.id(bank)
	if not id then
		return nil
	end
	local clip, offsets = SoundBanks.pick(bank, group)
	if not clip or not offsets then
		return nil
	end
	if sound.SoundId ~= id then
		sound.SoundId = id
	end
	sound.Volume = volume or SoundBanks.volume(group)
	nextToken += 1
	local token = nextToken
	playTokens[sound] = token
	if sound.IsPlaying then
		sound:Stop()
	end
	sound.TimePosition = offsets.start
	sound:Play()
	local duration = offsets.length / math.max(sound.PlaybackSpeed, 0.05)
	task.delay(duration, function()
		if playTokens[sound] == token and sound.Parent then
			sound:Stop()
		end
	end)
	return duration
end

-- Loops a random variant of `group` on `sound` (the bank's other clips stay out: the
-- playback and loop regions are the clip). Returns false when the bank has no id yet.
function SoundBanks.loop(sound: Sound, bank: string, group: string, volume: number?): boolean
	local id = SoundBanks.id(bank)
	if not id then
		return false
	end
	local clip, offsets = SoundBanks.pick(bank, group)
	if not clip or not offsets then
		return false
	end
	sound.SoundId = id
	sound.Volume = volume or SoundBanks.volume(group)
	local region = NumberRange.new(offsets.start, offsets.start + offsets.length)
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = region
	sound.LoopRegion = region
	sound.Looped = true
	sound.TimePosition = offsets.start
	sound:Play()
	return true
end

-- The SoundGroup every in-world sound plays through (voices, blasts, gunshots, footsteps,
-- hits), so the client can treat the world apart from UI stings and the player's own body
-- (LowHealthFX muffles it). The server makes it in SoundService and it replicates; a client
-- only finds it (nil until it arrives; a sound made before then plays ungrouped).
SoundBanks.WORLD_GROUP = "World"
-- The bank holding each gun's own shot and reload clips (`<Sound>_shot`, `<Sound>_reload`).
SoundBanks.GUN_BANK = "guns"

function SoundBanks.worldGroup(): SoundGroup?
	local SoundService = game:GetService("SoundService")
	local existing = SoundService:FindFirstChild(SoundBanks.WORLD_GROUP)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	if not game:GetService("RunService"):IsServer() then
		return nil
	end
	local group = Instance.new("SoundGroup")
	group.Name = SoundBanks.WORLD_GROUP
	group.Volume = 1
	group.Parent = SoundService
	return group
end

-- A 3D Sound ready for `play`: inverse-tapered rolloff between the two distances, in the
-- World group.
function SoundBanks.create(name: string, rollOffMin: number, rollOffMax: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundGroup = SoundBanks.worldGroup()
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = rollOffMin
	sound.RollOffMaxDistance = rollOffMax
	return sound
end

-- Loads every uploaded bank so the first seek on each side lands on a decoded asset.
-- Call once from the client; the server calls it too so its replicated Sounds have an id
-- to hand out. Logs a bank that fails to load instead of raising.
function SoundBanks.preload(parent: Instance)
	local sounds: { Sound } = {}
	for bank in groups do
		local id = SoundBanks.id(bank)
		if id then
			local sound = Instance.new("Sound")
			sound.Name = "Bank_" .. bank
			sound.SoundId = id
			sound.Volume = 0
			sound.Parent = parent
			table.insert(sounds, sound)
		end
	end
	if #sounds == 0 then
		return
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(sounds, function(assetId, status)
			if status == Enum.AssetFetchStatus.Failure then
				warn(`SoundBanks: {assetId} failed to load`)
			end
		end)
	end)
end

return SoundBanks
