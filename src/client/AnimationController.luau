--!strict
-- Plays the Chosen's body animations (Config.Animations.Assault) in place of the stock
-- Roblox Animate script: idle, then a four-way directional blend (forward / back / left /
-- right) for walking and for running, picked from the character's ground speed and the
-- direction of travel relative to where the body faces (the body faces the camera, so
-- strafing and backpedalling are real). An aim pose while the trigger is held, a recoil
-- clip per shot, a flinch on damage, the death clip, and ability clips sit on top.
-- Upper-body clips (aim, fire, hit, breach) carry no leg poses so the legs keep moving
-- underneath them. Other controllers call in: WeaponController (setAiming, onShot),
-- AbilityController (playAbility).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animations"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FADE = 0.2
local IDLE_SPEED = 1 -- studs/s below which the character counts as standing still
local MIN_CLIP_RATE, MAX_CLIP_RATE = 0.6, 1.8
local MIN_WEIGHT = 0.001 -- a looped track at zero weight stops contributing but keeps time
local DIRECTIONS = { "forward", "back", "left", "right" }

local AnimationController = {}

-- One locomotion set (walk or run): a looped track per direction, blended by weight.
type MoveSet = { tracks: { [string]: AnimationTrack }, clips: { [string]: string } }

type Tracks = {
	idle: AnimationTrack?,
	aim: AnimationTrack?,
	fire: AnimationTrack?,
	hit: AnimationTrack?,
	death: AnimationTrack?,
	breach: AnimationTrack?,
}

local tracks: Tracks = {}
local moveSets: { walk: MoveSet?, run: MoveSet? } = {}
local currentSet: MoveSet? = nil
local idlePlaying = false
local aiming = false
local dead = false
local lastHealth = 0
local stepConnection: RBXScriptConnection? = nil

local function stopAll(fade: number)
	for _, track in tracks :: { [string]: AnimationTrack } do
		if track.IsPlaying then
			track:Stop(fade)
		end
	end
	for _, set in moveSets :: { [string]: MoveSet } do
		for _, track in set.tracks do
			if track.IsPlaying then
				track:Stop(fade)
			end
		end
	end
end

local function loadMoveSet(animator: Animator, clips: { [string]: string }): MoveSet?
	local set: MoveSet = { tracks = {}, clips = clips }
	for _, direction in DIRECTIONS do
		local clip = clips[direction]
		local track = clip and Animations.load(animator, clip, Enum.AnimationPriority.Core)
		if not track then
			return nil
		end
		track.Looped = true
		set.tracks[direction] = track
	end
	return set
end

local function setIdle(on: boolean)
	if idlePlaying == on then
		return
	end
	idlePlaying = on
	local idle = tracks.idle
	if idle then
		if on then
			idle:Play(FADE)
		else
			idle:Stop(FADE)
		end
	end
end

local function switchSet(set: MoveSet?)
	if set == currentSet then
		return
	end
	if currentSet then
		for _, track in currentSet.tracks do
			track:Stop(FADE)
		end
	end
	currentSet = set
	if set then
		for _, track in set.tracks do
			track:Play(FADE, MIN_WEIGHT)
		end
	end
end

-- Blend weights from the direction of travel in the body's frame: the body faces -Z,
-- +X is its right. Diagonals split between two clips.
local function blendWeights(localVelocity: Vector3): { [string]: number }
	local forward = math.max(0, -localVelocity.Z)
	local back = math.max(0, localVelocity.Z)
	local right = math.max(0, localVelocity.X)
	local left = math.max(0, -localVelocity.X)
	local total = forward + back + right + left
	if total <= 0 then
		return { forward = 1, back = 0, left = 0, right = 0 }
	end
	return {
		forward = forward / total,
		back = back / total,
		left = left / total,
		right = right / total,
	}
end

local function step(humanoid: Humanoid, root: BasePart)
	if dead then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude
	-- Off the ground: hold whatever is playing (no jump clip; the game has no jump).
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	if speed < IDLE_SPEED then
		switchSet(nil)
		setIdle(true)
		return
	end
	setIdle(false)
	local set = if speed < Config.Animations.WalkRunThreshold then moveSets.walk else moveSets.run
	switchSet(set)
	if not set then
		return
	end
	local weights = blendWeights(root.CFrame:VectorToObjectSpace(flat))
	for direction, track in set.tracks do
		track:AdjustWeight(math.max(weights[direction], MIN_WEIGHT), 0.1)
		local reference = Config.Animations.MoveClipSpeed[set.clips[direction]] or speed
		track:AdjustSpeed(math.clamp(speed / reference, MIN_CLIP_RATE, MAX_CLIP_RATE))
	end
end

local function setup(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator

	-- Retire the stock Animate script and whatever it started.
	local animate = character:FindFirstChild("Animate") or character:WaitForChild("Animate", 3)
	if animate and animate:IsA("LocalScript") then
		animate.Disabled = true
		animate:Destroy()
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
	end

	local clips = Config.Animations.Assault
	tracks = {
		idle = Animations.load(animator, clips.idle, Enum.AnimationPriority.Core),
		aim = Animations.load(animator, clips.aim, Enum.AnimationPriority.Action),
		fire = Animations.load(animator, clips.fire, Enum.AnimationPriority.Action2),
		hit = Animations.load(animator, clips.hit, Enum.AnimationPriority.Action3),
		death = Animations.load(animator, clips.death, Enum.AnimationPriority.Action4),
		breach = Animations.load(animator, clips.breach, Enum.AnimationPriority.Action3),
	}
	for _, key in { "idle", "aim" } do
		local track = (tracks :: { [string]: AnimationTrack? })[key]
		if track then
			track.Looped = true
		end
	end
	moveSets = {
		walk = loadMoveSet(animator, clips.walk),
		run = loadMoveSet(animator, clips.run),
	}
	currentSet = nil
	idlePlaying = false
	dead = false
	aiming = false
	lastHealth = humanoid.Health

	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth and health > 0 and tracks.hit and not aiming then
			tracks.hit:Play(0.1)
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		dead = true
		stopAll(0.1)
		if tracks.death then
			tracks.death:Play(0.1)
		end
	end)

	if stepConnection then
		stepConnection:Disconnect()
	end
	stepConnection = RunService.Heartbeat:Connect(function()
		if character.Parent then
			step(humanoid, root)
		end
	end)
end

-- Hold the rifle shouldered while the trigger is held.
function AnimationController.setAiming(on: boolean)
	if aiming == on or dead then
		return
	end
	aiming = on
	local aim = tracks.aim
	if not aim then
		return
	end
	if on then
		aim:Play(0.15)
	else
		aim:Stop(0.25)
	end
end

-- One recoil clip per shot fired.
function AnimationController.onShot()
	local fire = tracks.fire
	if fire and not dead then
		fire:Play(0.05)
	end
end

function AnimationController.playAbility(name: string)
	local track = (tracks :: { [string]: AnimationTrack? })[name]
	if track and not dead then
		track:Play(0.1)
	end
end

function AnimationController.init()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
end

return AnimationController
