--!strict
-- Downed crawl. While the local character is Downed (Squad: SquadState
-- attribute) it crawls on hands and knees at Config.Downed.CrawlSpeed (SprintController
-- sets the speed). This plays the Mixamo crawl clip over everything else, its rate following
-- ground speed against Config.Animations.MoveClipSpeed, and frozen on all fours when still.
-- The clip plays on the client's own Animator, so the squad sees it too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Animations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animations"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DownedController = {}

local track: AnimationTrack? = nil
local root: BasePart? = nil

local function stop()
	if track and track.IsPlaying then
		track:Stop(0.3)
	end
end

local function onStateChanged(character: Model)
	if character:GetAttribute(Attributes.SquadState) ~= "Downed" then
		stop()
		return
	end
	if track and not track.IsPlaying then
		track:Play(0.3)
		track:AdjustSpeed(0)
	end
end

local function onCharacterAdded(character: Model)
	track, root = nil, nil
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local animator = humanoid:WaitForChild("Animator", 10) :: Animator?
	if animator then
		local loaded = Animations.load(
			animator,
			Config.Animations.Assault.downed,
			Enum.AnimationPriority.Action3
		)
		if loaded then
			loaded.Looped = true
		end
		track = loaded
	end
	character:GetAttributeChangedSignal(Attributes.SquadState):Connect(function()
		onStateChanged(character)
	end)
	humanoid.Died:Connect(stop)
	onStateChanged(character)
end

local function step()
	local current, body = track, root
	if not current or not current.IsPlaying or not body then
		return
	end
	local velocity = body.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local clipSpeed = (Config.Animations.MoveClipSpeed :: { [string]: number }).downed_crawl or 4
	current:AdjustSpeed(if speed > 0.3 then math.clamp(speed / clipSpeed, 0.4, 1.6) else 0)
end

function DownedController.init()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService.Heartbeat:Connect(step)
end

return DownedController
