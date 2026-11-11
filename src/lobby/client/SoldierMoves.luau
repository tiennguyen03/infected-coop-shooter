--!strict
-- Your soldier on the ship stands and walks like the match's (owner, 2026-11-11): the match's
-- rifle idle and four-way walk/run blend (Config.Animations.Assault, the shared
-- SoldierLocomotion that the match's AnimationController also drives) in place of Roblox's
-- stock Animate script. Each client plays its own character's clips on the Animator, so the
-- other soldiers see them too. No combat states here (aim, stances, roll, vault).
--
-- The clips belong to the group and only play in places the group owns. If the idle or the
-- walk does not load within Config.Lobby.Soldier.ClipWait seconds, the stock Animate script
-- is left running and nothing changes. Config.Lobby.Soldier.Enabled = false turns this off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoldierLocomotion =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoldierLocomotion"))

local SoldierMoves = {}

local SETTINGS = Config.Lobby.Soldier
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

local function setup(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator

	local clips = Config.Animations.Assault
	local idle = SoldierLocomotion.loadLooped(animator, clips.idle, Enum.AnimationPriority.Core)
	local walk = SoldierLocomotion.loadMoveSet(animator, clips.walk)
	-- The ship has no sprint today; the run set plays if a soldier ever moves that fast.
	local run = SoldierLocomotion.loadMoveSet(animator, clips.run)
	if not idle or not walk then
		warn("[SoldierMoves] the idle or walk clip has no id; keeping the stock animations")
		return
	end
	local needed: { AnimationTrack } = { idle }
	for _, track in walk.tracks do
		table.insert(needed, track)
	end
	if not loaded(needed, character) then
		if character.Parent then
			warn("[SoldierMoves] the soldier clips did not load; keeping the stock animations")
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

	local current: SoldierLocomotion.MoveSet? = nil
	local idling = false
	local function setIdle(on: boolean)
		if idling == on then
			return
		end
		idling = on
		if on then
			idle:Play(SoldierLocomotion.FADE)
		else
			idle:Stop(SoldierLocomotion.FADE)
		end
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
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		if speed < SoldierLocomotion.IDLE_SPEED then
			current = SoldierLocomotion.switch(current, nil)
			setIdle(true)
			return
		end
		setIdle(false)
		local set = SoldierLocomotion.pick(walk, run, speed)
		current = SoldierLocomotion.switch(current, set)
		if set then
			SoldierLocomotion.drive(set, root.CFrame:VectorToObjectSpace(flat), speed)
		end
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
