--!strict
-- Plays the Chosen's body animations (Config.Animations.Assault) in place of the stock
-- Roblox Animate script. Three stances (StanceController): standing has an idle, a four-way
-- directional blend for walking and another for running; crouch has an idle and a four-way
-- walk; prone has an idle and a two-way crawl. The blend weights come from the direction of
-- travel relative to where the body faces (the body faces the camera, so strafing and
-- backpedalling are real). Enter/exit clips play over a stance change. An aim pose per
-- stance while the trigger is held, a recoil clip per shot, a flinch on damage, the death
-- clip and ability clips sit on top; a vault or climb clip (MovementController) replaces
-- the locomotion while the body is carried over cover. Upper-body clips (aim, fire, hit,
-- throw) carry no leg poses so the legs keep moving underneath them. Other controllers
-- call in: WeaponController (setAiming, onShot), AbilityController (playAbility),
-- StanceController (setStance), MovementController (playMove).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animations"))
local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local WeaponDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FADE = 0.2
local IDLE_SPEED = 1 -- studs/s below which the character counts as standing still
local MIN_CLIP_RATE, MAX_CLIP_RATE = 0.6, 1.8
local MIN_WEIGHT = 0.001 -- a looped track at zero weight stops contributing but keeps time
local DIRECTIONS = { "forward", "back", "left", "right" }

export type Stance = "stand" | "crouch" | "prone"

local AnimationController = {}

-- One locomotion set: a looped track per direction it has, blended by weight. Directions
-- a set lacks fold into forward (the prone crawl has no sideways clips).
type MoveSet = { tracks: { [string]: AnimationTrack }, clips: { [string]: string } }

-- Everything one stance plays.
type StanceSet = {
	idle: AnimationTrack?,
	aim: AnimationTrack?,
	walk: MoveSet?,
	run: MoveSet?,
	enter: AnimationTrack?,
	exit: AnimationTrack?,
}

type Tracks = {
	fire: AnimationTrack?,
	hit: AnimationTrack?,
	death: AnimationTrack?,
	throw: AnimationTrack?,
	vault: AnimationTrack?,
	climb: AnimationTrack?,
	roll: AnimationTrack?,
	slide: AnimationTrack?,
	knockdown: AnimationTrack?,
	getup: AnimationTrack?,
	ladder: AnimationTrack?,
}

local tracks: Tracks = {}
-- Reload clips by name (a gun may name its own, WeaponDefinitions.ReloadClip); loaded once per
-- character, the one playing now.
local reloadTracks: { [string]: AnimationTrack } = {}
local reloadPlaying: AnimationTrack? = nil
local currentAnimator: Animator? = nil
local stances: { [string]: StanceSet } = {}
local stance: Stance = "stand"
local currentSet: MoveSet? = nil
local idlePlaying = false
local aiming = false
local dead = false
local busyUntil = 0 -- a vault/climb clip owns the body until then
local lastHealth = 0
local stepConnection: RBXScriptConnection? = nil

local function stopAll(fade: number)
	for _, track in tracks :: { [string]: AnimationTrack } do
		if track.IsPlaying then
			track:Stop(fade)
		end
	end
	for _, set in stances do
		for _, key in { "idle", "aim", "enter", "exit" } do
			local track = (set :: any)[key] :: AnimationTrack?
			if track and track.IsPlaying then
				track:Stop(fade)
			end
		end
		for _, moveKey in { "walk", "run" } do
			local moveSet = (set :: any)[moveKey] :: MoveSet?
			if moveSet then
				for _, track in moveSet.tracks do
					if track.IsPlaying then
						track:Stop(fade)
					end
				end
			end
		end
	end
end

local function loadMoveSet(animator: Animator, clips: { [string]: string }?): MoveSet?
	if not clips then
		return nil
	end
	local set: MoveSet = { tracks = {}, clips = clips }
	for _, direction in DIRECTIONS do
		local clip = clips[direction]
		if clip then
			local track = Animations.load(animator, clip, Enum.AnimationPriority.Core)
			if not track then
				return nil
			end
			track.Looped = true
			set.tracks[direction] = track
		end
	end
	if not set.tracks.forward then
		return nil
	end
	return set
end

local function loadLooped(
	animator: Animator,
	clip: string?,
	priority: Enum.AnimationPriority
): AnimationTrack?
	local track = clip and Animations.load(animator, clip, priority)
	if track then
		track.Looped = true
	end
	return track
end

local function loadStance(animator: Animator, clips: { [string]: any }): StanceSet
	return {
		idle = loadLooped(animator, clips.idle, Enum.AnimationPriority.Core),
		aim = loadLooped(animator, clips.aim, Enum.AnimationPriority.Action),
		walk = loadMoveSet(animator, clips.walk),
		run = loadMoveSet(animator, clips.run),
		enter = if clips.enter
			then Animations.load(animator, clips.enter, Enum.AnimationPriority.Action2)
			else nil,
		exit = if clips.exit
			then Animations.load(animator, clips.exit, Enum.AnimationPriority.Action2)
			else nil,
	}
end

local function current(): StanceSet
	return stances[stance] or stances.stand
end

local function setIdle(on: boolean)
	if idlePlaying == on then
		return
	end
	idlePlaying = on
	local idle = current().idle
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
-- +X is its right. Diagonals split between two clips; directions the set lacks go forward.
local function blendWeights(localVelocity: Vector3, set: MoveSet): { [string]: number }
	local forward = math.max(0, -localVelocity.Z)
	local back = math.max(0, localVelocity.Z)
	local right = math.max(0, localVelocity.X)
	local left = math.max(0, -localVelocity.X)
	local total = forward + back + right + left
	if total <= 0 then
		return { forward = 1, back = 0, left = 0, right = 0 }
	end
	local weights = {
		forward = forward / total,
		back = back / total,
		left = left / total,
		right = right / total,
	}
	for _, direction in DIRECTIONS do
		if direction ~= "forward" and not set.tracks[direction] then
			weights.forward += weights[direction]
			weights[direction] = 0
		end
	end
	return weights
end

local function playAim(on: boolean)
	local aim = current().aim
	if not aim then
		return
	end
	if on then
		if not aim.IsPlaying then
			aim:Play(0.15)
		end
	elseif aim.IsPlaying then
		aim:Stop(0.25)
	end
end

local function step(humanoid: Humanoid, root: BasePart)
	if dead then
		return
	end
	if os.clock() < busyUntil then
		switchSet(nil)
		setIdle(false)
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude
	-- On a ladder (TrussPart): the stock climb clip, rate from the vertical speed, nothing
	-- else playing. Off it, the clip stops and the locomotion below takes over.
	local ladder = tracks.ladder
	if humanoid:GetState() == Enum.HumanoidStateType.Climbing then
		switchSet(nil)
		setIdle(false)
		if ladder then
			if not ladder.IsPlaying then
				ladder:Play(0.1)
			end
			ladder:AdjustSpeed(
				math.clamp(math.abs(velocity.Y) / Config.Animations.LadderClipSpeed, 0, 2)
			)
		end
		return
	elseif ladder and ladder.IsPlaying then
		ladder:Stop(0.15)
	end
	-- Off the ground: hold whatever is playing (no jump clip; cover is vaulted instead).
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	if speed < IDLE_SPEED then
		switchSet(nil)
		setIdle(true)
		return
	end
	setIdle(false)
	local set = current()
	local moveSet = if set.run and speed >= Config.Animations.WalkRunThreshold
		then set.run
		else set.walk
	switchSet(moveSet)
	if not moveSet then
		return
	end
	local weights = blendWeights(root.CFrame:VectorToObjectSpace(flat), moveSet)
	for direction, track in moveSet.tracks do
		track:AdjustWeight(math.max(weights[direction], MIN_WEIGHT), 0.1)
		local reference = Config.Animations.MoveClipSpeed[moveSet.clips[direction]] or speed
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
	currentAnimator = animator
	reloadTracks = {}
	reloadPlaying = nil
	tracks = {
		fire = Animations.load(animator, clips.fire, Enum.AnimationPriority.Action2),
		hit = Animations.load(animator, clips.hit, Enum.AnimationPriority.Action3),
		death = Animations.load(animator, clips.death, Enum.AnimationPriority.Action4),
		throw = Animations.load(animator, clips.throw, Enum.AnimationPriority.Action3),
		vault = Animations.load(animator, clips.vault, Enum.AnimationPriority.Action3),
		climb = Animations.load(animator, clips.climb, Enum.AnimationPriority.Action3),
		roll = Animations.load(animator, clips.roll, Enum.AnimationPriority.Action3),
		slide = Animations.load(animator, clips.slide, Enum.AnimationPriority.Action3),
		knockdown = Animations.load(animator, clips.knockdown, Enum.AnimationPriority.Action3),
		getup = Animations.load(animator, clips.getup, Enum.AnimationPriority.Action3),
		ladder = Animations.load(animator, clips.ladder, Enum.AnimationPriority.Action),
	}
	if tracks.ladder then
		tracks.ladder.Looped = true
	end
	stances = {
		stand = loadStance(animator, {
			idle = clips.idle,
			aim = clips.aim,
			walk = clips.walk,
			run = clips.run,
		}),
		crouch = loadStance(animator, clips.crouch),
		prone = loadStance(animator, clips.prone),
	}
	stance = "stand"
	currentSet = nil
	idlePlaying = false
	dead = false
	aiming = false
	busyUntil = 0
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
	playAim(on)
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

-- Switches stance: the old set stops, the transition clip (the old stance's exit or the
-- new one's enter, whichever exists) plays over the new idle at the rate that makes it take
-- `transitionTime` seconds.
function AnimationController.setStance(newStance: Stance, transitionTime: number)
	if newStance == stance or dead then
		return
	end
	local old = current()
	local wasAiming = aiming
	if old.aim and old.aim.IsPlaying then
		old.aim:Stop(0.1)
	end
	switchSet(nil)
	if old.idle and old.idle.IsPlaying then
		old.idle:Stop(FADE)
	end
	idlePlaying = false
	local transition = if newStance == "stand" then old.exit else stances[newStance].enter
	if newStance ~= "stand" and old.exit and stance ~= "stand" then
		-- Crouch <-> prone: no direct clip; the old stance's exit then the new enter.
		transition = stances[newStance].enter
	end
	stance = newStance
	if transition and transitionTime > 0 then
		transition:Play(0.1)
		transition:AdjustSpeed(math.max(transition.Length, 0.01) / transitionTime)
		task.delay(transitionTime, function()
			if transition.IsPlaying then
				transition:Stop(FADE)
			end
		end)
	end
	if wasAiming then
		playAim(true)
	end
end

function AnimationController.getStance(): Stance
	return stance
end

-- Plays the vault or climb clip at the rate that fits `duration` and holds the locomotion
-- off for that long. Returns false when the clip is not available.
function AnimationController.playMove(
	kind: "vault" | "climb" | "roll" | "slide",
	duration: number
): boolean
	local track = (tracks :: { [string]: AnimationTrack? })[kind]
	if dead then
		return false
	end
	busyUntil = os.clock() + duration
	switchSet(nil)
	setIdle(false)
	if not track then
		return false
	end
	track:Play(0.1)
	track:AdjustSpeed(math.max(track.Length, 0.01) / duration)
	task.delay(duration, function()
		if track.IsPlaying then
			track:Stop(FADE)
		end
	end)
	return true
end

-- Knocked down (KnockdownController): the fall clip over the first part of `seconds`, the
-- get-up over the last Config.Knockdown.GetUp; the locomotion and the aim stay off.
function AnimationController.playKnockdown(seconds: number)
	if dead then
		return
	end
	local getUp = math.min(Config.Knockdown.GetUp, seconds * 0.5)
	local fallTime = seconds - getUp
	busyUntil = os.clock() + seconds
	switchSet(nil)
	setIdle(false)
	playAim(false)
	local fall = tracks.knockdown
	if fall then
		fall:Play(0.05)
		fall:AdjustSpeed(math.max(fall.Length, 0.01) / math.max(fallTime, 0.2))
	end
	task.delay(fallTime, function()
		if dead then
			return
		end
		if fall and fall.IsPlaying then
			fall:Stop(0.1)
		end
		local rise = tracks.getup
		if rise then
			rise:Play(0.05)
			rise:AdjustSpeed(math.max(rise.Length, 0.01) / math.max(getUp, 0.2))
			task.delay(getUp, function()
				if rise.IsPlaying then
					rise:Stop(FADE)
				end
				if aiming then
					playAim(true)
				end
			end)
		end
	end)
end

local function stopReload()
	if reloadPlaying then
		reloadPlaying:Stop(0.15)
		reloadPlaying = nil
	end
end

-- ReloadUntil (server time) rose: play the gun's reload clip so it ends with the reload;
-- cleared or moved back (a swap, a death): stop it.
local function onReloadChanged()
	local player = Players.LocalPlayer
	local untilAt = (player:GetAttribute(Attributes.ReloadUntil) :: number?) or 0
	local remaining = untilAt - workspace:GetServerTimeNow()
	stopReload()
	local animator = currentAnimator
	if dead or remaining <= 0.05 or not animator then
		return
	end
	local weapon = WeaponDefinitions.get(player:GetAttribute(Attributes.Weapon) :: string?)
	local clip = weapon.ReloadClip or Config.Animations.Assault.reload
	local track = reloadTracks[clip]
		or Animations.load(animator, clip, Enum.AnimationPriority.Action2)
	if not track then
		return
	end
	reloadTracks[clip] = track
	track:Play(0.1)
	if track.Length > 0 then
		track:AdjustSpeed(track.Length / remaining)
	end
	reloadPlaying = track
end

function AnimationController.init()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
	player:GetAttributeChangedSignal(Attributes.ReloadUntil):Connect(onReloadChanged)
	player:GetAttributeChangedSignal(Attributes.Weapon):Connect(stopReload)
end

return AnimationController
