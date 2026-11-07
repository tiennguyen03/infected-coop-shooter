--!strict
-- Plays the Chosen's body animations (Config.Animations.Assault) in place of the stock
-- Roblox Animate script: idle / walk / run from the character's ground speed, an aim pose
-- while the trigger is held, a recoil clip per shot, a flinch on damage, the death clip,
-- and ability clips. Upper-body clips (aim, fire, hit, breach) carry no leg poses so the
-- legs keep walking underneath them. Other controllers call in: WeaponController
-- (setAiming, onShot), AbilityController (playAbility).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animations"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FADE = 0.2
local IDLE_SPEED = 1 -- studs/s below which the character counts as standing still
local MIN_CLIP_RATE, MAX_CLIP_RATE = 0.6, 1.8

local AnimationController = {}

type Tracks = {
	idle: AnimationTrack?,
	walk: AnimationTrack?,
	run: AnimationTrack?,
	aim: AnimationTrack?,
	fire: AnimationTrack?,
	hit: AnimationTrack?,
	death: AnimationTrack?,
	breach: AnimationTrack?,
}

local tracks: Tracks = {}
local currentMove: AnimationTrack? = nil
local currentMoveClip: string? = nil
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
end

local function switchMove(clipKey: string, track: AnimationTrack?)
	if track == currentMove then
		return
	end
	if currentMove then
		currentMove:Stop(FADE)
	end
	currentMove = track
	currentMoveClip = clipKey
	if track then
		track:Play(FADE)
	end
end

local function step(humanoid: Humanoid, root: BasePart)
	if dead then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	-- Off the ground: hold whatever is playing (no jump clip; the game has no jump).
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	if speed < IDLE_SPEED then
		switchMove("idle", tracks.idle)
	elseif speed < Config.Animations.WalkRunThreshold then
		switchMove("walk", tracks.walk)
	else
		switchMove("run", tracks.run)
	end
	if currentMove and currentMoveClip ~= "idle" then
		local clipName = Config.Animations.Assault[currentMoveClip :: string]
		local reference = Config.Animations.MoveClipSpeed[clipName] or speed
		currentMove:AdjustSpeed(math.clamp(speed / reference, MIN_CLIP_RATE, MAX_CLIP_RATE))
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
		walk = Animations.load(animator, clips.walk, Enum.AnimationPriority.Core),
		run = Animations.load(animator, clips.run, Enum.AnimationPriority.Core),
		aim = Animations.load(animator, clips.aim, Enum.AnimationPriority.Action),
		fire = Animations.load(animator, clips.fire, Enum.AnimationPriority.Action2),
		hit = Animations.load(animator, clips.hit, Enum.AnimationPriority.Action3),
		death = Animations.load(animator, clips.death, Enum.AnimationPriority.Action4),
		breach = Animations.load(animator, clips.breach, Enum.AnimationPriority.Action3),
	}
	for _, key in { "idle", "walk", "run", "aim" } do
		local track = (tracks :: { [string]: AnimationTrack? })[key]
		if track then
			track.Looped = true
		end
	end
	currentMove = nil
	currentMoveClip = nil
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
