--!strict
-- Music on the Carrier (Nova, 2026-11-10): a short playlist of licensed tracks from Roblox's
-- audio library (Config.Lobby.Music; free for any experience), shuffled, low in the mix (the
-- owner's "no harsh sound", docs/OWNER.md) in its own SoundGroup so a volume or mute setting
-- can be added later. It fades in when the soldier arrives and fades out when their Lantern
-- lifts (the transition is the rotor and a fade to black, OWNER.md); a failed lift or stepping
-- off brings it back. Local to each player: nothing replicates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LobbyMusic = {}

local MUSIC = Config.Lobby.Music

local group: SoundGroup
local sound: Sound
local queue: { string } = {}
local lifting = false

local function shuffled(): { string }
	local list = table.clone(MUSIC.Tracks)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function fade(volume: number, seconds: number)
	TweenService:Create(
		group,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = volume }
	):Play()
end

local function playNext()
	if #queue == 0 then
		queue = shuffled()
	end
	local id = table.remove(queue, 1)
	if not id then
		return
	end
	sound.SoundId = id
	sound.TimePosition = 0
	sound:Play()
end

function LobbyMusic.init()
	if #MUSIC.Tracks == 0 then
		return
	end
	group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Volume = 0
	group.Parent = SoundService
	sound = Instance.new("Sound")
	sound.Name = "LobbyMusic"
	sound.Volume = 1
	sound.SoundGroup = group
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		task.delay(MUSIC.GapSeconds, function()
			if not lifting then
				playNext()
			end
		end)
	end)

	Remotes.get("Launch").OnClientEvent:Connect(function(kind: string)
		if kind == Messages.Launch.Lifting then
			lifting = true
			fade(0, MUSIC.FadeOutSeconds)
		elseif lifting and (kind == Messages.Launch.Failed or kind == Messages.Launch.Cleared) then
			lifting = false
			if not sound.IsPlaying then
				playNext()
			end
			fade(MUSIC.Volume, MUSIC.FadeInSeconds)
		end
	end)

	queue = shuffled()
	playNext()
	fade(MUSIC.Volume, MUSIC.FadeInSeconds)
end

return LobbyMusic
