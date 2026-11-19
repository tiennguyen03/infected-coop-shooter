--!strict
-- The Warden's presence on each screen (the boss pass, 2026-11-18, docs/sprints/FUN_WARDEN.md).
-- Driven by the BossUpdate remote next to BossBarUI:
--   "incoming" (landing, seconds): his fight loop starts (Config.Index.Warden.Music) and the
--     ground rumbles while the landing ring shows (BossBarUI draws the ring).
--   "shake" (position, power, radius): a boot or a blow shakes the camera (CameraController).
--   "quake" (center, radius, speed, waves, gap): the Quake's rings running out on the ground.
--   "line" (from, direction, length, width, seconds): a Charge's lane on the ground.
--   "show" / "state" (phase) / "hide": the loop starts if it has not, swells each stage, and
--     fades out after the fight.
-- Everything here is look and sound; the server owns every hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Messages = require(Shared:WaitForChild("Messages"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CameraController = require(script.Parent.CameraController)

local BossPresence = {}

-- STYLES.md: objective yellow for a warning on the ground (as the Pound's ring), the wound
-- red for the lane he will run down.
local RING_COLOR = Color3.fromHex("e6bd60")
local LANE_COLOR = Color3.fromHex("c4464a")
local RING_SEGMENTS = 28
-- Shake added per second while the landing ring shows; against the camera's decay
-- (Config.Camera.Shake.Decay) it settles near 0.7 degrees at the ring.
local RUMBLE_RATE = 4.5

local music: Sound? = nil
local stage = 1
local rumbleUntil = 0
local rumbleAt: Vector3? = nil

local function settings()
	return Config.Index.Warden
end

local function fadeTo(sound: Sound, volume: number, seconds: number)
	TweenService:Create(sound, TweenInfo.new(seconds), { Volume = volume }):Play()
end

local function stageValue(list: { number }): number
	return list[math.clamp(stage, 1, #list)] or list[1] or 1
end

local function startMusic()
	local cfg = settings().Music
	if not cfg.Enabled or cfg.Id == "" then
		return
	end
	if not music then
		local sound = Instance.new("Sound")
		sound.Name = "WardenFight"
		sound.SoundId = cfg.Id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		music = sound
	end
	local sound = music :: Sound
	sound.PlaybackSpeed = stageValue(cfg.Speed)
	if not sound.IsPlaying then
		sound:Play()
	end
	fadeTo(sound, stageValue(cfg.Volume), cfg.FadeIn)
end

local function stopMusic()
	local sound = music
	if not sound then
		return
	end
	music = nil
	local fade = settings().Music.FadeOut
	fadeTo(sound, 0, fade)
	task.delay(fade + 0.1, function()
		sound:Destroy()
	end)
end

local function setStage(phase: number)
	if phase == stage then
		return
	end
	stage = phase
	local sound = music
	if sound then
		local cfg = settings().Music
		sound.PlaybackSpeed = stageValue(cfg.Speed)
		fadeTo(sound, stageValue(cfg.Volume), 1)
	end
end

local function flatPart(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.3
	return part
end

-- One ring: RING_SEGMENTS short flat bars round `center`, pushed out to `radius` over the
-- ring's travel time, fading as it goes. Cheap (one tween per bar, gone after).
local function ring(center: Vector3, radius: number, speed: number)
	local travel = radius / math.max(speed, 1)
	local y = center.Y + 0.25
	local arc = 2 * math.pi / RING_SEGMENTS
	for index = 1, RING_SEGMENTS do
		local angle = index * arc
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local bar = flatPart("QuakeRing", RING_COLOR)
		bar.Size = Vector3.new(0.4, 0.6, 1.2)
		bar.CFrame = CFrame.lookAt(
			Vector3.new(center.X, y, center.Z),
			Vector3.new(center.X, y, center.Z) + outward
		)
		bar.Parent = workspace
		local finish = Vector3.new(center.X, y, center.Z) + outward * radius
		TweenService:Create(bar, TweenInfo.new(travel, Enum.EasingStyle.Linear), {
			CFrame = CFrame.lookAt(finish, finish + outward),
			-- The bar widens with the circle so the ring stays closed.
			Size = Vector3.new(0.4, 0.6, math.max(radius * arc * 1.05, 1.2)),
			Transparency = 0.75,
		}):Play()
		task.delay(travel + 0.05, function()
			bar:Destroy()
		end)
	end
end

local function quake(center: Vector3, radius: number, speed: number, waves: number, gap: number)
	for wave = 1, waves do
		task.delay((wave - 1) * gap, function()
			ring(center, radius, speed)
		end)
	end
end

-- The Charge's lane: a flat red strip from his feet along `direction`, held `seconds`.
local function lane(
	from: Vector3,
	direction: Vector3,
	length: number,
	width: number,
	seconds: number
)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	flat = flat.Unit
	local strip = flatPart("ChargeLane", LANE_COLOR)
	strip.Size = Vector3.new(width, 0.2, length)
	local middle = from + flat * (length / 2) + Vector3.new(0, 0.15, 0)
	strip.CFrame = CFrame.lookAt(middle, middle + flat)
	strip.Transparency = 0.7
	strip.Parent = workspace
	TweenService:Create(strip, TweenInfo.new(math.max(seconds - 0.2, 0.1)), { Transparency = 0.35 })
		:Play()
	task.delay(seconds, function()
		strip:Destroy()
	end)
end

local function onUpdate(kind: string, ...: any)
	if kind == Messages.BossUpdate.Incoming then
		local landing, seconds = ...
		stage = 1
		startMusic()
		rumbleAt = landing
		rumbleUntil = os.clock() + (seconds :: number)
	elseif kind == Messages.BossUpdate.Shake then
		local position, power, radius = ...
		CameraController.shake(position, power, radius)
	elseif kind == Messages.BossUpdate.Quake then
		quake(...)
	elseif kind == Messages.BossUpdate.Line then
		lane(...)
	elseif kind == Messages.BossUpdate.Show then
		startMusic()
	elseif kind == Messages.BossUpdate.State then
		local _, _, phase = ...
		if typeof(phase) == "number" then
			setStage(phase)
		end
	elseif kind == Messages.BossUpdate.Hide then
		stopMusic()
		stage = 1
	end
end

function BossPresence.init()
	Remotes.get("BossUpdate").OnClientEvent:Connect(onUpdate)
	-- The ground rumbling under the landing ring (stronger the closer you are).
	RunService.Heartbeat:Connect(function(dt: number)
		local at = rumbleAt
		if at and os.clock() < rumbleUntil then
			CameraController.shake(at, RUMBLE_RATE * dt, 80)
		elseif at then
			rumbleAt = nil
		end
	end)
end

return BossPresence
