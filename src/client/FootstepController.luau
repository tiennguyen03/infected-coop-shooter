--!strict
-- Footsteps synced to the locomotion clips. For every player
-- character in the place (the local one and, in co-op, the teammates, whose animation
-- tracks replicate), each frame finds the locomotion track with the most weight and reads
-- its loop phase (TimePosition / Length). A boot sound plays when the phase crosses one of
-- the clip's footfall phases in Config.Audio.Footsteps.Phases, measured from the feet's
-- lowest points in Studio, so the step lands when the foot does at any playback rate.
-- The ground material picks the step surface (concrete vs dirt). Sounds are 3D on the
-- character's root so a teammate's steps come from where they are.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animations"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LoopPhase = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("LoopPhase")
)
local SoundBanks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBanks"))

local BANK = "player_steps"
local DEFAULT_PHASES = { 0, 0.5 }
local SOFT_MATERIALS = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Snow] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Salt] = true,
}

type Walker = {
	humanoid: Humanoid,
	root: BasePart,
	animator: Animator,
	clip: string?,
	lastPhase: number?,
	lastStepAt: number,
	sound: Sound,
}

local FootstepController = {}

local walkers: { [Model]: Walker } = {}
-- Published animation id -> locomotion clip name, so a replicated track can be recognised.
local clipByAnimationId: { [string]: string } = {}

local function collectLocomotionClips()
	local sets = Config.Animations.Assault
	-- Standing walk and run, and the crouch walk (the prone crawl makes no steps).
	for _, set in { sets.walk, sets.run, sets.crouch.walk } do
		for _, clip in set :: { [string]: string } do
			local id = Animations.getId(clip)
			if id then
				clipByAnimationId[id] = clip
			end
		end
	end
end

local function surfaceOf(humanoid: Humanoid): string
	return if SOFT_MATERIALS[humanoid.FloorMaterial] then "step_soft" else "step_hard"
end

local function update(walker: Walker, now: number)
	local humanoid = walker.humanoid
	if humanoid.Health <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
		walker.lastPhase = nil
		return
	end
	local best: AnimationTrack? = nil
	local bestClip: string? = nil
	local bestWeight = 0
	for _, track in walker.animator:GetPlayingAnimationTracks() do
		local animation = track.Animation
		local clip = animation and clipByAnimationId[animation.AnimationId]
		if clip and track.WeightCurrent > bestWeight then
			best, bestClip, bestWeight = track, clip, track.WeightCurrent
		end
	end
	if not best or not bestClip or best.Length <= 0 then
		walker.lastPhase = nil
		walker.clip = nil
		return
	end
	local phase = best.TimePosition / best.Length
	local lastPhase = walker.lastPhase
	if walker.clip ~= bestClip or not lastPhase then
		-- A new dominant clip: take its phase as the baseline, step on the next footfall.
		walker.clip = bestClip
		walker.lastPhase = phase
		return
	end
	walker.lastPhase = phase
	local settings = Config.Audio.Footsteps
	if now - walker.lastStepAt < settings.MinInterval then
		return
	end
	local phases = settings.Phases[bestClip] or DEFAULT_PHASES
	for _, mark in phases do
		if LoopPhase.crossed(lastPhase, phase, mark) then
			walker.lastStepAt = now
			local running = bestClip:find("run") ~= nil
			local volume = SoundBanks.volume(surfaceOf(humanoid))
				* (if running then settings.RunVolume else settings.WalkVolume)
			SoundBanks.play(walker.sound, BANK, surfaceOf(humanoid), volume)
			break
		end
	end
end

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	local animator = humanoid:WaitForChild("Animator", 10) :: Animator?
	if not animator then
		return
	end
	local settings = Config.Audio.Footsteps
	local sound = SoundBanks.create("Footsteps", settings.RollOffMin, settings.RollOffMax)
	sound.Parent = root
	walkers[character] = {
		humanoid = humanoid,
		root = root,
		animator = animator,
		clip = nil,
		lastPhase = nil,
		lastStepAt = 0,
		sound = sound,
	}
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(watch, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		walkers[character] = nil
	end)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

function FootstepController.init()
	collectLocomotionClips()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			walkers[player.Character] = nil
		end
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for character, walker in walkers do
			if character.Parent then
				update(walker, now)
			else
				walkers[character] = nil
			end
		end
	end)
end

return FootstepController
