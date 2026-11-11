--!strict
-- The revive animation, one implementation for players and bots (Config.ReviveAnimation,
-- Rules/ReviveAnim; docs/PROGRESSION.md > Downed and revive). The server (ReviveAnimService)
-- writes the ReviveRole attribute on both bodies; this module turns the role into motion:
--
--   drive    whoever owns a body's Animator (a player's own client, the server for a bot)
--            plays the clips, which replicate: the kneel (the crouch idle), the casualty on
--            their back (the last frame of the knockdown clip, held) and the get-up; and
--            slides the reviver to the kneel point the server picked.
--   watch    every client, for every body with a role: the arms. Clips cannot reach a chest
--            whose place differs every time, so the hands are solved onto it each frame
--            (two-bone IK written to the joints' Transform after the Animator, which does
--            not replicate: each client solves what it sees). Also the rifle across the
--            back, the lean into each press, the casualty's lift and nod.
--
-- The poses were authored from the clip numbers without being seen in game; every number
-- is in Config.ReviveAnimation.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Animations = require(script.Parent.Animations)
local Attributes = require(script.Parent.Attributes)
local Config = require(script.Parent.Config)
local Rules = require(script.Parent.Rules.ReviveAnim)

local ReviveAnimation = {}

-- On a body while it has a role (ReviveAnimService): how clients find the bodies to pose.
ReviveAnimation.TAG = "ReviveAnim"

local settings = Config.ReviveAnimation
local HOLD_MARGIN = 0.03 -- seconds before the end of the knockdown clip the lying body holds
local PARTNER_RANGE = 12 -- studs: a reviver's casualty (and the other way) is within this

function ReviveAnimation.times(): Rules.Times
	return {
		kneel = settings.KneelSeconds,
		finish = settings.FinishSeconds,
		pullShare = settings.PullShare,
		nudgeSeconds = settings.NudgeSeconds,
		nudgeSpeed = settings.NudgeSpeed,
	}
end

function ReviveAnimation.kneelSettings(): Rules.KneelSettings
	return {
		chestX = settings.Chest.X,
		chestZ = settings.Chest.Z,
		axisX = settings.BodyAxis.X,
		axisZ = settings.BodyAxis.Z,
		distance = settings.KneelDistance,
		turn = math.rad(settings.KneelTurn),
		maxNudge = settings.MaxNudge,
	}
end

local times = ReviveAnimation.times()

local function roleOf(character: Model): string
	local role = character:GetAttribute(Attributes.ReviveRole)
	return if typeof(role) == "string" then role else ""
end

-- Walking or crawling: over the break speed, until under the resume speed again.
local function isMoving(root: BasePart, was: boolean): boolean
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	return speed > (if was then settings.MoveResumeSpeed else settings.MoveBreakSpeed)
end

local function isDown(phase: Rules.Phase): boolean
	return phase == "kneel" or phase == "treat"
end

-- Freezes the knockdown clip on its last frame: the body on its back.
local function holdLastFrame(track: AnimationTrack)
	if track.Length <= 0 then
		return
	end
	if track.Speed ~= 0 then
		track:AdjustSpeed(0)
	end
	local goal = track.Length - HOLD_MARGIN
	if math.abs(track.TimePosition - goal) > 0.02 then
		track.TimePosition = goal
	end
end

--------------------------------------------------------------------------------------------
-- drive: the clips and the slide, run by the body's owner
--------------------------------------------------------------------------------------------

export type Hooks = {
	-- A player's body follows the camera's heading; the kneel and the lying body hold theirs.
	setYawLocked: ((locked: boolean) -> ())?,
}

type Driver = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	kneel: AnimationTrack?,
	lie: AnimationTrack?,
	rise: AnimationTrack?,
	hooks: Hooks,
	role: string,
	since: number,
	phase: Rules.Phase,
	moving: boolean,
	nudged: boolean, -- the slide to the server's kneel point was started for this role
	nudgeFrom: CFrame?,
	nudgeTo: CFrame?,
	nudgeStart: number,
	nudgeSeconds: number,
}

local drivers: { Driver } = {}
local driverConnection: RBXScriptConnection? = nil

local function lockYaw(driver: Driver, locked: boolean)
	if driver.hooks.setYawLocked then
		driver.hooks.setYawLocked(locked)
	end
end

local function stopTrack(track: AnimationTrack?, fade: number)
	if track and track.IsPlaying then
		track:Stop(fade)
	end
end

-- Down onto the knee: slide to the kneel point the server picked, once per role. After a
-- step away (or when the point is out of reach by now) only turn to face the chest again.
local function startNudge(driver: Driver, now: number)
	local root = driver.root
	local position = root.Position
	local kneelAt = driver.character:GetAttribute(Attributes.ReviveKneel)
	local chest = driver.character:GetAttribute(Attributes.ReviveChest)
	local target: CFrame? = nil
	if not driver.nudged and typeof(kneelAt) == "CFrame" then
		local offset = kneelAt.Position - position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= settings.MaxNudge then
			target = kneelAt
		end
	end
	if not target and typeof(chest) == "Vector3" then
		local yaw = Rules.facing(position.X, position.Z, chest.X, chest.Z)
		target = CFrame.new(position) * CFrame.Angles(0, yaw + math.rad(settings.KneelTurn), 0)
	end
	driver.nudged = true
	if target then
		local offset = target.Position - position
		driver.nudgeFrom = root.CFrame
		driver.nudgeTo = target
		driver.nudgeStart = now
		driver.nudgeSeconds =
			Rules.nudgeSeconds(Vector3.new(offset.X, 0, offset.Z).Magnitude, times)
	end
end

local function enterPhase(driver: Driver, old: Rules.Phase, new: Rules.Phase, now: number)
	local wasDown, down = isDown(old), isDown(new)
	if down and not wasDown then
		if driver.kneel then
			driver.kneel:Play(settings.KneelSeconds)
		end
		lockYaw(driver, true)
		startNudge(driver, now)
	elseif wasDown and not down then
		-- The pull-up rises slowly with a hand on the casualty; anything else stands at once.
		if new == "pull" then
			stopTrack(driver.kneel, settings.FinishSeconds * settings.PullShare)
		else
			stopTrack(driver.kneel, settings.StandSeconds)
			lockYaw(driver, false)
		end
	end
	if old == "pull" and new ~= "pull" then
		lockYaw(driver, false)
	end
	local lie, rise = driver.lie, driver.rise
	if new == "lie" then
		if lie then
			lie:Play(settings.LieSeconds, 1, 0)
			holdLastFrame(lie)
		end
		lockYaw(driver, true)
	elseif old == "lie" then
		stopTrack(lie, if new == "rise" then 0.15 else settings.StandSeconds)
		lockYaw(driver, false)
	end
	if new == "rise" then
		if rise then
			rise:Play(0.15)
			if rise.Length > 0 then
				rise:AdjustSpeed(rise.Length / math.max(settings.RecoverSeconds, 0.1))
			end
		end
	elseif old == "rise" then
		stopTrack(rise, 0.2)
	end
end

local function stepDriver(driver: Driver, now: number)
	local role = if settings.Enabled then roleOf(driver.character) else ""
	if role ~= driver.role then
		driver.role = role
		driver.since = now
		driver.nudged = false
	end
	driver.moving = isMoving(driver.root, driver.moving)
	local phase: Rules.Phase = Rules.phase(role, now - driver.since, driver.moving, times)
	if phase ~= driver.phase then
		local old: Rules.Phase = driver.phase
		driver.phase = phase
		enterPhase(driver, old, phase, now)
	end
	local from, to = driver.nudgeFrom, driver.nudgeTo
	if from and to then
		if not isDown(phase) then
			driver.nudgeFrom, driver.nudgeTo = nil, nil
		else
			local alpha = (now - driver.nudgeStart) / math.max(driver.nudgeSeconds, 0.01)
			local goal = from:Lerp(to, Rules.ease(alpha))
			-- The body keeps its own height: the Humanoid holds it over the floor.
			local position = Vector3.new(goal.X, driver.root.Position.Y, goal.Z)
			driver.root.CFrame = CFrame.new(position) * goal.Rotation
			if RunService:IsServer() then
				driver.humanoid:MoveTo(position) -- a bot's last walk target must not pull it back
			end
			if alpha >= 1 then
				driver.nudgeFrom, driver.nudgeTo = nil, nil
			end
		end
	end
	if phase == "lie" and driver.lie and driver.lie.IsPlaying then
		holdLastFrame(driver.lie)
	end
end

local function stepDrivers()
	local now = os.clock()
	for index = #drivers, 1, -1 do
		local driver = drivers[index]
		if driver.character.Parent == nil or driver.humanoid.Health <= 0 then
			if driver.phase ~= "none" then
				lockYaw(driver, false)
			end
			if driver.character.Parent == nil then
				table.remove(drivers, index)
				continue
			end
			stopTrack(driver.kneel, 0.1)
			stopTrack(driver.lie, 0.1)
			stopTrack(driver.rise, 0.1)
			driver.phase = "none"
			driver.role = ""
			continue
		end
		stepDriver(driver, now)
	end
end

-- Plays the revive clips on `character` from now on. Call it where the body's Animator is
-- owned: a player's own client, the server for a bot. Yields until the body is built.
function ReviveAnimation.drive(character: Model, hooks: Hooks?)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end
	local animator = humanoid:WaitForChild("Animator", 10)
	if not animator or not animator:IsA("Animator") then
		return
	end
	local clips = Config.Animations.Assault
	local kneel = Animations.load(animator, clips.crouch.idle, Enum.AnimationPriority.Action3)
	if kneel then
		kneel.Looped = true
	end
	table.insert(drivers, {
		character = character,
		humanoid = humanoid,
		root = root,
		kneel = kneel,
		-- Over the downed crawl (Action3) and whatever a revived body starts doing.
		lie = Animations.load(animator, clips.knockdown, Enum.AnimationPriority.Action4),
		rise = Animations.load(animator, clips.getup, Enum.AnimationPriority.Action4),
		hooks = hooks or {},
		role = "",
		since = os.clock(),
		phase = "none",
		moving = false,
		nudged = false,
		nudgeFrom = nil,
		nudgeTo = nil,
		nudgeStart = 0,
		nudgeSeconds = 0,
	})
	if not driverConnection then
		driverConnection = RunService.Heartbeat:Connect(stepDrivers)
	end
end

--------------------------------------------------------------------------------------------
-- watch: the arms and the rest of the pose, on every client
--------------------------------------------------------------------------------------------

-- A rig joint: a Motor6D, or the AnimationConstraint a rebuilt rig has in its place
-- (StanceService.liftRig). Part1 = Part0 * c0 * Transform * c1^-1 either way.
type Joint = {
	motor: Motor6D?,
	constraint: AnimationConstraint?,
	part0: BasePart,
	c0: CFrame,
	c1: CFrame,
	base: CFrame, -- the Animator's last value
	written: CFrame?, -- ours, to tell it from the Animator's
}

type Arm = {
	shoulder: Joint,
	elbow: Joint,
	wrist: Joint?,
	upperLength: number, -- shoulder to elbow
	lowerLength: number, -- elbow to palm
	-- A limb's joints are not straight above one another (the shoulder sits at the arm's
	-- inner edge): these turn each limb's own joint-to-joint line onto -Y.
	upperFix: CFrame,
	lowerFix: CFrame,
}

type Sling = { weld: Weld, part0: BasePart?, c0: CFrame, c1: CFrame }

type Body = {
	character: Model,
	root: BasePart,
	upperTorso: BasePart,
	animator: Animator?,
	left: Arm?,
	right: Arm?,
	waist: Joint?,
	neck: Joint?,
	rootJoint: Joint?,
	role: string,
	since: number,
	moving: boolean,
	hands: number, -- 0..1: the left arm is on the chest
	rightHand: number, -- 0..1: so is the right (the rifle is slung)
	pull: number, -- 0..1: the left hand is on the casualty's arm
	lift: number, -- 0..1: the casualty is on their back
	sling: Sling?,
}

local bodies: { [Model]: Body } = {}
local lieClipId: string? = nil

local function readJoint(part: Instance?, name: string): Joint?
	local joint = part and part:FindFirstChild(name)
	if not joint then
		return nil
	end
	if joint:IsA("Motor6D") then
		local part0 = joint.Part0
		if part0 then
			return {
				motor = joint,
				part0 = part0,
				c0 = joint.C0,
				c1 = joint.C1,
				base = joint.Transform,
			}
		end
	elseif joint:IsA("AnimationConstraint") then
		local attachment0, attachment1 = joint.Attachment0, joint.Attachment1
		local part0 = attachment0 and attachment0.Parent
		if attachment0 and attachment1 and part0 and part0:IsA("BasePart") then
			return {
				constraint = joint,
				part0 = part0,
				c0 = attachment0.CFrame,
				c1 = attachment1.CFrame,
				base = joint.Transform,
			}
		end
	end
	return nil
end

local function getTransform(joint: Joint): CFrame
	if joint.motor then
		return joint.motor.Transform
	elseif joint.constraint then
		return joint.constraint.Transform
	end
	return CFrame.identity
end

local function setTransform(joint: Joint, transform: CFrame)
	if joint.motor then
		joint.motor.Transform = transform
	elseif joint.constraint then
		joint.constraint.Transform = transform
	end
end

-- The clip's value this frame. The Animator rewrites Transform while a clip moves the
-- joint; when it has not (the value is still ours), the last one it wrote stands.
local function clipTransform(joint: Joint): CFrame
	local now = getTransform(joint)
	if joint.written and now == joint.written then
		return joint.base
	end
	joint.base = now
	return now
end

local function write(joint: Joint, transform: CFrame)
	setTransform(joint, transform)
	joint.written = transform
end

-- Hands a joint back to the Animator (and to its last value, when no clip moves it).
local function release(joint: Joint?)
	if joint and joint.written then
		if getTransform(joint) == joint.written then
			setTransform(joint, joint.base)
		end
		joint.written = nil
	end
end

-- The rotation that takes direction `from` onto direction `to` the short way.
local function rotationBetween(from: Vector3, to: Vector3): CFrame
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.atan2(axis.Magnitude, from:Dot(to)))
end

local function readArm(character: Model, prefix: string): Arm?
	local shoulder = readJoint(character:FindFirstChild(prefix .. "UpperArm"), prefix .. "Shoulder")
	local elbow = readJoint(character:FindFirstChild(prefix .. "LowerArm"), prefix .. "Elbow")
	local wrist = readJoint(character:FindFirstChild(prefix .. "Hand"), prefix .. "Wrist")
	if not shoulder or not elbow then
		return nil
	end
	local down = -Vector3.yAxis
	local upperBone = elbow.c0.Position - shoulder.c1.Position
	local lowerBone = if wrist then wrist.c0.Position - elbow.c1.Position else down * 0.8
	if upperBone.Magnitude < 0.05 or lowerBone.Magnitude < 0.05 then
		return nil
	end
	return {
		shoulder = shoulder,
		elbow = elbow,
		wrist = wrist,
		upperLength = upperBone.Magnitude,
		lowerLength = lowerBone.Magnitude + settings.HandLength,
		upperFix = rotationBetween(upperBone.Unit, down),
		lowerFix = rotationBetween(lowerBone.Unit, down),
	}
end

local function newBody(character: Model): Body?
	local root = character:FindFirstChild("HumanoidRootPart")
	local upperTorso = character:FindFirstChild("UpperTorso")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not upperTorso or not upperTorso:IsA("BasePart") then
		return nil
	end
	return {
		character = character,
		root = root,
		upperTorso = upperTorso,
		animator = humanoid and humanoid:FindFirstChildOfClass("Animator"),
		left = readArm(character, "Left"),
		right = readArm(character, "Right"),
		waist = readJoint(upperTorso, "Waist"),
		neck = readJoint(character:FindFirstChild("Head"), "Neck"),
		rootJoint = readJoint(character:FindFirstChild("LowerTorso"), "Root"),
		role = "",
		since = os.clock(),
		moving = false,
		hands = 0,
		rightHand = 0,
		pull = 0,
		lift = 0,
		sling = nil,
	}
end

-- A limb's rotation: it hangs along -Y, its front is -Z.
local function limbRotation(along: Vector3, front: Vector3): CFrame
	local y = -along
	local z = -front
	return CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
end

local function perpendicular(vector: Vector3, to: Vector3, fallback: Vector3): Vector3
	local across = vector - to * vector:Dot(to)
	if across.Magnitude < 1e-3 then
		across = fallback - to * fallback:Dot(to)
	end
	if across.Magnitude < 1e-3 then
		across = to:Cross(Vector3.xAxis)
	end
	return across.Unit
end

-- Two-bone IK: puts the palm of `arm` on `target` (as far as it reaches) with the elbow
-- toward `pole`, blended over the clip by `weight`.
local function solveArm(arm: Arm, target: Vector3, pole: Vector3, weight: number)
	local shoulder, elbow = arm.shoulder, arm.elbow
	local socket = shoulder.part0.CFrame * shoulder.c0
	local upper, lower = arm.upperLength, arm.lowerLength
	local toTarget = target - socket.Position
	local direction = if toTarget.Magnitude > 1e-3 then toTarget.Unit else -Vector3.yAxis
	local distance =
		math.clamp(toTarget.Magnitude, math.abs(upper - lower) + 0.05, upper + lower - 0.01)
	local cosine = math.clamp(
		(upper * upper + distance * distance - lower * lower) / (2 * upper * distance),
		-1,
		1
	)
	local out = perpendicular(pole, direction, Vector3.yAxis)
	local elbowAt = direction * (upper * cosine) + out * (upper * math.sqrt(1 - cosine * cosine))
	local upperAlong = elbowAt.Unit
	local lowerAlong = (direction * distance - elbowAt).Unit
	-- The forearm folds toward the upper arm's front, away from where the elbow points.
	local upperFront = -perpendicular(out, upperAlong, direction)
	local upperRotation = limbRotation(upperAlong, upperFront) * arm.upperFix
	local lowerRotation = limbRotation(
		lowerAlong,
		perpendicular(upperFront, lowerAlong, upperAlong)
	) * arm.lowerFix
	local shoulderGoal = socket.Rotation:Inverse() * upperRotation * shoulder.c1.Rotation
	local elbowGoal = (upperRotation * elbow.c0.Rotation):Inverse()
		* lowerRotation
		* elbow.c1.Rotation
	local shoulderClip, elbowClip = clipTransform(shoulder), clipTransform(elbow)
	write(shoulder, shoulderClip:Lerp(shoulderGoal + shoulderClip.Position, weight))
	write(elbow, elbowClip:Lerp(elbowGoal + elbowClip.Position, weight))
	local wrist = arm.wrist
	if wrist then
		local wristClip = clipTransform(wrist)
		write(wrist, wristClip:Lerp(CFrame.new(wristClip.Position), weight))
	end
end

local function releaseArm(arm: Arm?)
	if arm then
		release(arm.shoulder)
		release(arm.elbow)
		release(arm.wrist)
	end
end

-- The rifle across the back: this client's copy of the grip weld moves from the right hand
-- to the upper torso (the server's weld, and so a bot's muzzle, stays where it was).
local function slingRifle(body: Body)
	local current = body.sling
	if current and current.weld.Parent then
		return
	end
	body.sling = nil
	local hand = body.character:FindFirstChild("RightHand")
	local weld = hand and hand:FindFirstChild("RightGrip")
	if not weld or not weld:IsA("Weld") or not weld.Part1 then
		return
	end
	body.sling = { weld = weld, part0 = weld.Part0, c0 = weld.C0, c1 = weld.C1 }
	weld.Part0 = body.upperTorso
	weld.C0 = CFrame.lookAlong(settings.Sling.Position, settings.Sling.Barrel.Unit, Vector3.zAxis)
	weld.C1 = CFrame.identity
end

local function unslingRifle(body: Body)
	local current = body.sling
	body.sling = nil
	if current and current.weld.Parent then
		current.weld.Part0 = current.part0
		current.weld.C0 = current.c0
		current.weld.C1 = current.c1
	end
end

-- The nearest other body whose role is one of `roles`.
local function partnerOf(body: Body, roles: { [string]: boolean }): Body?
	local best: Body? = nil
	local bestDistance = PARTNER_RANGE
	for _, other in bodies do
		if other ~= body and roles[other.role] then
			local distance = (other.root.Position - body.root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

local CASUALTY_ROLES = { treated = true, recover = true }

local function elbowPole(body: Body, side: number): Vector3
	local out = settings.ElbowOut
	return body.root.CFrame:VectorToWorldSpace(Vector3.new(out.X * side, out.Y, out.Z))
end

-- Where the hands work: the top of the casualty's chest when it is within reach, else the
-- ground in front of the knee.
local function treatPoint(body: Body, casualty: Body?): Vector3
	local left = body.left
	if casualty and left then
		local torso = casualty.upperTorso
		local top = torso.Position
			+ Vector3.yAxis * (math.min(torso.Size.Y, torso.Size.Z) / 2 + settings.HandLift)
		local socket = left.shoulder.part0.CFrame * left.shoulder.c0
		local reach = (left.upperLength + left.lowerLength) * settings.ReachSlack
		if (top - socket.Position).Magnitude <= reach then
			return top
		end
	end
	return body.root.CFrame:PointToWorldSpace(settings.FallbackTarget)
end

-- The casualty's hand nearest the reviver's shoulder: what the pull-up takes hold of.
local function pullPoint(casualty: Body, arm: Arm): Vector3
	local socket = (arm.shoulder.part0.CFrame * arm.shoulder.c0).Position
	local best = casualty.upperTorso.Position
	local bestDistance = math.huge
	for _, name in { "LeftHand", "RightHand" } do
		local hand = casualty.character:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			local distance = (hand.Position - socket).Magnitude
			if distance < bestDistance then
				best, bestDistance = hand.Position, distance
			end
		end
	end
	return best
end

-- The lying body's clip, held on its last frame on this client's copy of the track (a
-- replicated track's time is not ours to trust).
local function holdLying(body: Body)
	local animator = body.animator
	local id = lieClipId
	if not animator or not id then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		local animation = track.Animation
		if animation and animation.AnimationId == id then
			holdLastFrame(track)
		end
	end
end

-- One body, one frame. Returns false once it has no role and nothing left to ease out.
local function stepBody(body: Body, now: number, deltaTime: number): boolean
	local role = if settings.Enabled then roleOf(body.character) else ""
	if role ~= body.role then
		body.role = role
		body.since = now
	end
	body.moving = isMoving(body.root, body.moving)
	local elapsed = now - body.since
	local phase: Rules.Phase = Rules.phase(role, elapsed, body.moving, times)
	local blend = deltaTime / math.max(settings.BlendSeconds, 0.01)
	local press = Rules.press(workspace:GetServerTimeNow(), settings.PressRate)

	-- The reviver: hands onto the chest half way down, working once down.
	local working = phase == "treat" or (phase == "kneel" and elapsed >= times.kneel / 2)
	body.hands = Rules.approach(body.hands, if working then 1 else 0, blend)
	if settings.SlingRifle and working and body.hands > 0.5 then
		slingRifle(body)
	elseif body.sling and (not working and body.rightHand < 0.5) then
		unslingRifle(body)
	end
	local slung = body.sling ~= nil and working
	body.rightHand = Rules.approach(body.rightHand, if slung then 1 else 0, blend)
	if phase == "pull" then
		body.pull = Rules.pull(elapsed, times)
	else
		body.pull = Rules.approach(body.pull, 0, blend)
	end

	local left, right, waist = body.left, body.right, body.waist
	if body.hands > 0 or body.pull > 0 or body.rightHand > 0 then
		local casualty = partnerOf(body, CASUALTY_ROLES)
		local depth = if phase == "treat" then press * body.hands else 0
		local point = treatPoint(body, casualty) - Vector3.yAxis * (depth * settings.PressDepth)
		local across = body.root.CFrame.RightVector * settings.HandGap
		if left then
			local target = point - across
			local weight = Rules.ease(body.hands)
			if body.pull > 0 and casualty then
				-- The pull-up takes over from the press.
				local pullWeight = Rules.ease(body.pull)
				target = target:Lerp(pullPoint(casualty, left), pullWeight)
				weight = math.max(weight, pullWeight)
			end
			solveArm(left, target, elbowPole(body, -1), weight)
		end
		if right then
			if body.rightHand > 0 then
				solveArm(right, point + across, elbowPole(body, 1), Rules.ease(body.rightHand))
			else
				releaseArm(right)
			end
		end
		if waist then
			local lean = math.rad(settings.PressLean) * depth
			write(waist, clipTransform(waist) * CFrame.Angles(-lean, 0, 0))
		end
	else
		releaseArm(left)
		releaseArm(right)
		release(waist)
	end

	-- The casualty: raised onto the floor while on their back, the head rocking with the press.
	local lying = phase == "lie"
	body.lift = Rules.approach(
		body.lift,
		if lying then 1 else 0,
		deltaTime / math.max(settings.LieSeconds, 0.01)
	)
	local rootJoint, neck = body.rootJoint, body.neck
	if lying then
		holdLying(body)
	end
	if body.lift > 0 then
		if rootJoint and settings.CasualtyLift ~= 0 then
			local lift = settings.CasualtyLift * Rules.ease(body.lift)
			write(rootJoint, CFrame.new(0, lift, 0) * clipTransform(rootJoint))
		end
		if neck then
			local nod = math.rad(settings.CasualtyNod) * press * body.lift
			write(neck, clipTransform(neck) * CFrame.Angles(nod, 0, 0))
		end
	else
		release(rootJoint)
		release(neck)
	end

	return role ~= ""
		or body.hands > 0
		or body.rightHand > 0
		or body.pull > 0
		or body.lift > 0
		or body.sling ~= nil
end

local function stepBodies(deltaTime: number)
	local now = os.clock()
	for character, body in bodies do
		local gone = character.Parent == nil
		if gone or not stepBody(body, now, deltaTime) then
			unslingRifle(body)
			if not gone and CollectionService:HasTag(character, ReviveAnimation.TAG) then
				continue -- between roles: keep it
			end
			bodies[character] = nil
		end
	end
end

-- Client: poses every body that has a revive role, from now on.
function ReviveAnimation.watch()
	lieClipId = Animations.getId(Config.Animations.Assault.knockdown)
	local function add(instance: Instance)
		if instance:IsA("Model") and not bodies[instance] then
			local body = newBody(instance)
			if body then
				bodies[instance] = body
			end
		end
	end
	CollectionService:GetInstanceAddedSignal(ReviveAnimation.TAG):Connect(add)
	for _, instance in CollectionService:GetTagged(ReviveAnimation.TAG) do
		add(instance)
	end
	-- Stepped runs after the Animator has written this frame's Transforms and before the
	-- joints are solved: what is written here is what is drawn.
	RunService.Stepped:Connect(function(_, deltaTime)
		stepBodies(deltaTime)
	end)
end

return ReviveAnimation
