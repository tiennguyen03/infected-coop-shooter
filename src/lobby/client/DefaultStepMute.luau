--!strict
-- Mutes Roblox's default walking sound on the Fallow (Nova, 2026-11-09). The engine's
-- character-sounds script puts a looping Sound named "Running" in every character's
-- HumanoidRootPart, on each client, for every character it sees. This holds its volume at 0
-- for every character (yours and the other soldiers'). Jump, land and the other default
-- sounds are left alone. The match's own synced footsteps (FootstepController) need the
-- match's locomotion clips, which the lobby does not have yet.

local Players = game:GetService("Players")

local DefaultStepMute = {}

local SOUND_NAME = "Running"

local function mute(sound: Instance)
	if sound.Name == SOUND_NAME and sound:IsA("Sound") then
		sound.Volume = 0
		-- The sounds script may reset the volume; keep it at 0.
		sound:GetPropertyChangedSignal("Volume"):Connect(function()
			if sound.Volume ~= 0 then
				sound.Volume = 0
			end
		end)
	end
end

local function watch(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	for _, child in root:GetChildren() do
		mute(child)
	end
	root.ChildAdded:Connect(mute)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

function DefaultStepMute.init()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return DefaultStepMute
