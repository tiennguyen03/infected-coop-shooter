--!strict
-- The Pike soldier's ground locomotion, shared by the match (client AnimationController) and
-- the lobby (SoldierMoves): a looped track per direction, blended by the direction of travel
-- (Rules/MoveBlend) and paced by ground speed (Config.Animations.MoveClipSpeed). Stances,
-- aim and the action clips stay in AnimationController; this is only "which legs clip, how
-- much of each, how fast".

local Animations = require(script.Parent.Animations)
local Config = require(script.Parent.Config)
local MoveBlend = require(script.Parent.Rules.MoveBlend)

local SoldierLocomotion = {}

SoldierLocomotion.FADE = 0.2
SoldierLocomotion.IDLE_SPEED = 1 -- studs/s below which the character counts as standing still
local MIN_WEIGHT = 0.001 -- a looped track at zero weight stops contributing but keeps time

-- One locomotion set: a looped track per direction it has. Directions a set lacks fold into
-- forward (the prone crawl has no sideways clips).
export type MoveSet = { tracks: { [string]: AnimationTrack }, clips: { [string]: string } }

-- A looped clip, or nil when the clip is not named or has no id.
function SoldierLocomotion.loadLooped(
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

-- The set for `clips` ({ forward =, back =, left =, right = } clip names), or nil when the
-- forward clip is missing or any clip it names has no id.
function SoldierLocomotion.loadMoveSet(animator: Animator, clips: { [string]: string }?): MoveSet?
	if not clips then
		return nil
	end
	local set: MoveSet = { tracks = {}, clips = clips }
	for _, direction in MoveBlend.DIRECTIONS do
		local clip = clips[direction]
		if clip then
			local track = SoldierLocomotion.loadLooped(animator, clip, Enum.AnimationPriority.Core)
			if not track then
				return nil
			end
			set.tracks[direction] = track
		end
	end
	if not set.tracks.forward then
		return nil
	end
	return set
end

-- Fades `from` out and starts `to` (either may be nil). Returns `to`, the set now playing.
function SoldierLocomotion.switch(from: MoveSet?, to: MoveSet?): MoveSet?
	if from == to then
		return to
	end
	if from then
		for _, track in from.tracks do
			track:Stop(SoldierLocomotion.FADE)
		end
	end
	if to then
		for _, track in to.tracks do
			track:Play(SoldierLocomotion.FADE, MIN_WEIGHT)
		end
	end
	return to
end

-- The run set at or above Config.Animations.WalkRunThreshold (when there is one), else the walk.
function SoldierLocomotion.pick(walk: MoveSet?, run: MoveSet?, speed: number): MoveSet?
	return if run and speed >= Config.Animations.WalkRunThreshold then run else walk
end

-- Each frame while `set` plays: weights from the travel direction in the body's frame
-- (`localVelocity`, flat), rates from the ground speed.
function SoldierLocomotion.drive(set: MoveSet, localVelocity: Vector3, speed: number)
	local weights: { [string]: number } =
		MoveBlend.weights(localVelocity.X, localVelocity.Z, set.tracks) :: any
	for direction, track in set.tracks do
		track:AdjustWeight(math.max(weights[direction], MIN_WEIGHT), 0.1)
		local reference = Config.Animations.MoveClipSpeed[set.clips[direction]]
		track:AdjustSpeed(MoveBlend.rate(speed, reference))
	end
end

return SoldierLocomotion
