--!strict
-- Your soldier on the ship stands up straight and walks with the gun slung across the chest
-- (owner, 2026-11-11: not the match's hunched rifle walk). Roblox's Rthro idle, walk and run
-- (Config.Lobby.Soldier.Animations) replace the stock Animate script, each at a rate that
-- fits the ground speed; the gun is welded across the chest by the server (PikeBody) and the
-- hands are put on it by SlingHands. Each client plays its own character's clips on the
-- Animator, so the other soldiers see them too.
--
-- If the clips do not load within Config.Lobby.Soldier.ClipWait seconds, the stock Animate
-- script is left running. Config.Lobby.Soldier.Enabled = false turns this off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SoldierMoves = {}

local SETTINGS = Config.Lobby.Soldier
local FADE = 0.25
local IDLE_SPEED = 0.6 -- studs a second: slower than this stands
local stepConnection: RBXScriptConnection? = nil

-- True once every track has its keyframes (Length is 0 until a clip loads, and stays 0
-- when it is refused).
local function loaded(tracks: { AnimationTrack }, character: Model): boolean
	local deadline = os.clock() + SETTINGS.ClipWait
	while os.clock() < deadline and character.Parent do
		local ready = true
		for _, track in tracks do
			if track.Length <= 0 then
				ready = false
				break
			end
		end
		if ready then
			return true
		end
		task.wait(0.25)
	end
	return false
end

local function load(
	animator: Animator,
	id: string,
	priority: Enum.AnimationPriority
): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track.Priority = priority
	return track
end

local function setup(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator

	local clips = SETTINGS.Animations
	local idle = load(animator, clips.Idle, Enum.AnimationPriority.Core)
	local walk = load(animator, clips.Walk, Enum.AnimationPriority.Movement)
	local run = load(animator, clips.Run, Enum.AnimationPriority.Movement)
	if not loaded({ idle, walk, run }, character) then
		if character.Parent then
			warn("[SoldierMoves] the clips did not load; keeping the stock animations")
		end
		return
	end

	-- Retire the stock Animate script and whatever it started (disabled, not destroyed).
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Disabled = true
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
	end

	local playing: AnimationTrack? = nil
	local function switch(track: AnimationTrack)
		if playing == track then
			return
		end
		if playing then
			playing:Stop(FADE)
		end
		track:Play(FADE)
		playing = track
	end

	if stepConnection then
		stepConnection:Disconnect()
	end
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if not character.Parent then
			connection:Disconnect()
			return
		end
		-- Off the deck (a jump, a fall): hold whatever is playing.
		if humanoid.FloorMaterial == Enum.Material.Air then
			return
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if speed < IDLE_SPEED then
			switch(idle)
			return
		end
		local running = speed > SETTINGS.RunAbove
		local track = if running then run else walk
		switch(track)
		local made = if running then SETTINGS.RunClipSpeed else SETTINGS.WalkClipSpeed
		track:AdjustSpeed(math.clamp(speed / made, SETTINGS.MinRate, SETTINGS.MaxRate))
	end)
	stepConnection = connection
end

function SoldierMoves.init()
	if not SETTINGS.Enabled then
		return
	end
	if SETTINGS.CarryRifle then
		-- The carried rifle is a Tool that is always in hand (PikeBody): no hotbar for it.
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
	end
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
end

return SoldierMoves
