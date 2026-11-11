--!strict
-- Call-in arrivals (docs/PROGRESSION.md > Call-in arrivals): what everyone sees and hears
-- between a call-in's throw and its effect, so each one reads as its own thing. The server
-- tells every client once per throw (remote CallInArrival: id, thrower, point, direction,
-- and for a fire mission where each round lands); everything here is local and for looks
-- only. Damage, the blast flash and its sound, the gunship and the kit itself stay the
-- server's (AirStrikeService, CallInService), on the same clock: an arrival holds while the
-- field is paused, as the server's waits do.
--
-- The call-in's Config row names a Style in its `Arrival` block (over
-- Config.CallIns.Arrivals.Defaults, Rules/Arrival) and every number comes from that block,
-- so a new call-in picks a look by its row; none is named here.
--   thrown    the marker flies the aim arc and lands (every style starts with this)
--   mortar    a diamond per round; far-off tubes, a short high whistle, a thin round dropping
--             near straight down, low pale dust
--   shell     one ring closing on the mark; a long falling whistle, a heavy round on a
--             flatter line with a smoke trail, a column of earth, smoke, burnt ground
--   gunrun    a ladder of rungs running the way the gunship flies; the cannon from the air,
--             a rake of tracers and dust spurts walking the lane
--   case      a case under a cross-shaped cargo chute, a thud, the chute folding beside it
--   scatter   charges hopping out of the satchel to their places, a blink as each arms
--   unroll    two drums rolling out from the coil, paying out a strand
--   tumble    a bundle tumbling down with no chute, one bounce
--   streamer  a bag coming down steadily under a fluttering red and white streamer
-- An arrival is a list of cues (run once at a time) and tracks (run every frame between two
-- times) over one Model that goes when the last of them is done. Smoke and dust are
-- particle bursts (docs/STYLES.md > Performance budget), never a running rate.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Arrival = require(Rules:WaitForChild("Arrival"))
local StrikePattern = require(Rules:WaitForChild("StrikePattern"))
local Attributes = require(Shared:WaitForChild("Attributes"))
local CallInDefinitions = require(Shared:WaitForChild("CallInDefinitions"))
local Config = require(Shared:WaitForChild("Config"))
local GroundUtil = require(Shared:WaitForChild("GroundUtil"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundBanks = require(Shared:WaitForChild("SoundBanks"))

local UP = Vector3.yAxis
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local PUFF_INTERVAL = 0.35 -- seconds between marker-smoke puffs
local PUFF_LIFE = 3 -- seconds a marker-smoke puff lasts
-- Stand-in kit, in the palette (docs/STYLES.md section 2): the real thing is the server's.
local OLIVE = Color3.fromRGB(99, 110, 66)
local OLIVE_DARK = Color3.fromRGB(65, 73, 43)
local CANOPY = Color3.fromRGB(142, 152, 98)
local STEEL = Color3.fromRGB(99, 109, 119)
local STEEL_DARK = Color3.fromRGB(61, 69, 77)
local POLYMER = Color3.fromRGB(48, 53, 59)
local CORD = Color3.fromRGB(158, 131, 90)
local BAG = Color3.fromRGB(92, 98, 66)
local PATCH = Color3.fromRGB(230, 230, 224)
local CROSS_RED = Color3.fromRGB(176, 38, 52)
local TRACER = Color3.fromRGB(255, 196, 90)
local SCORCH = Color3.fromRGB(31, 35, 39)
local CASE_SIZE = Vector3.new(2.4, 1.3, 1.5)
local BUNDLE_SIZE = Vector3.new(2.6, 1.6, 1.8)
local BAG_SIZE = Vector3.new(2.2, 1.1, 1.5)

type Cue = { at: number, run: () -> (), fired: boolean }
type Track = { from: number, to: number, run: (t: number) -> (), done: boolean }

type Ctx = {
	model: Model,
	cfg: any, -- the call-in's Config row
	arrival: Arrival.Resolved,
	color: Color3, -- the call-in's accent (CallInDefinitions.Color)
	origin: Vector3, -- the thrower's hand
	point: Vector3, -- where the throw lands
	flat: Vector3, -- the flat throw direction
	frame: CFrame, -- at `point`, looking along the throw
	impacts: { Vector3 },
	elapsed: number,
	endsAt: number,
	cues: { Cue },
	tracks: { Track },
}

local CallInArrivalFX = {}

local folder: Folder
local active: { Ctx } = {}

-- ------------------------------------------------------------------ the timeline

local function cue(ctx: Ctx, at: number, run: () -> ())
	table.insert(ctx.cues, { at = at, run = run, fired = false })
	ctx.endsAt = math.max(ctx.endsAt, at)
end

local function track(ctx: Ctx, from: number, to: number, run: (t: number) -> ())
	table.insert(ctx.tracks, { from = from, to = to, run = run, done = false })
	ctx.endsAt = math.max(ctx.endsAt, to)
end

-- Keeps the arrival (and what it drew) alive until `at`.
local function hold(ctx: Ctx, at: number)
	ctx.endsAt = math.max(ctx.endsAt, at)
end

local function advance(ctx: Ctx, dt: number)
	ctx.elapsed += dt
	local t = ctx.elapsed
	for _, entry in ctx.tracks do
		if not entry.done and t >= entry.from then
			entry.run(math.min(t, entry.to))
			entry.done = t >= entry.to
		end
	end
	for _, entry in ctx.cues do
		if not entry.fired and t >= entry.at then
			entry.fired = true
			entry.run()
		end
	end
end

-- ------------------------------------------------------------------ pieces

local function part(ctx: Ctx, name: string, size: Vector3, color: Color3): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Parent = ctx.model
	return piece
end

local function setVisible(pieces: { BasePart }, visible: boolean)
	for _, piece in pieces do
		piece.Transparency = if visible then 0 else 1
	end
end

local function destroyAll(pieces: { BasePart })
	for _, piece in pieces do
		piece:Destroy()
	end
end

-- A burst emitter at a world position, gone by itself after `seconds`. It lives outside
-- the arrival's Model so its particles finish even when the arrival is done.
local function emitterAt(position: Vector3, seconds: number): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "CallInArrivalFX"
	attachment.WorldPosition = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Texture = SMOKE_TEXTURE
	emitter.LightEmission = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Parent = attachment
	attachment.Parent = workspace.Terrain
	Debris:AddItem(attachment, seconds)
	return emitter
end

-- One burst of `count` puffs of `color` thrown out from `position`.
local function puff(
	position: Vector3,
	color: Color3,
	count: number,
	size: number,
	speed: number,
	life: number
)
	local emitter = emitterAt(position, life + 0.5)
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.4),
		NumberSequenceKeypoint.new(1, size),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(life * 0.6, life)
	emitter.Speed = NumberRange.new(speed * 0.4, speed)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Drag = 3
	emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter:Emit(count)
end

-- A 3D one-shot from a bank at `volume` times the group's own, at playback speed `pitch`.
-- `far` carries it across the map (rounds in the air, the gunship's cannon).
local function sound(
	position: Vector3,
	bank: string,
	group: string,
	volume: number,
	pitch: number,
	far: boolean
)
	if not SoundBanks.hasGroup(bank, group) then
		return
	end
	local rolloff = if far then Config.Audio.Far else Config.Audio.Voice
	local attachment = Instance.new("Attachment")
	attachment.Name = "CallInArrivalFX"
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local clip = SoundBanks.create(group, rolloff.RollOffMin, rolloff.RollOffMax)
	clip.PlaybackSpeed = pitch
	clip.Parent = attachment
	local duration = SoundBanks.play(clip, bank, group, SoundBanks.volume(group) * volume)
	Debris:AddItem(attachment, (duration or 0) + 0.3)
end

-- The thrown marker (or the kit itself): flies the aim arc from the hand to the mark over
-- Arrival.Throw and stays there (Throw 0: unseen). With `Smoke` on the row it then smokes
-- in that colour.
local function thrown(ctx: Ctx): Part
	local arrival = ctx.arrival
	local size = arrival.ThrownSize :: Vector3
	local body = part(ctx, "Thrown", size, ctx.color)
	body.Material = Enum.Material.Metal
	local rest = ctx.point + UP * (size.Y / 2)
	local arc = Config.CallIns.AimArc
	local reach = (Vector3.new(rest.X, 0, rest.Z) - Vector3.new(ctx.origin.X, 0, ctx.origin.Z)).Magnitude
	local rise = math.max(reach * arc.Rise, arc.MinRise)
	local flight = arrival.Throw
	if flight <= 0 then
		-- Marked, not thrown (a binoculars call-in): nothing flies and nothing lies there.
		body.Transparency = 1
	end
	track(ctx, 0, flight, function(t)
		local u = Arrival.progress(t, 0, flight)
		local at = ctx.origin:Lerp(rest, u) + UP * Arrival.hop(t, 0, flight, rise)
		-- one and a half turns end over end, flat again as it lands
		body.CFrame = CFrame.lookAt(at, at + ctx.flat) * CFrame.Angles((1 - u) * math.pi * 3, 0, 0)
	end)
	local smoke = arrival.Smoke
	if typeof(smoke) == "Color3" then
		local seconds = arrival.SmokeTime :: number
		local emitter: ParticleEmitter? = nil
		local nextPuff = flight
		track(ctx, flight, flight + seconds, function(t)
			local source = emitter
			if not source then
				local made = emitterAt(ctx.point + UP * 0.6, seconds + PUFF_LIFE + 1)
				made.Color = ColorSequence.new(smoke)
				made.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1.2),
					NumberSequenceKeypoint.new(1, 4.5),
				})
				made.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				})
				made.Lifetime = NumberRange.new(PUFF_LIFE * 0.7, PUFF_LIFE)
				made.Speed = NumberRange.new(3, 5)
				made.SpreadAngle = Vector2.new(10, 10)
				made.Acceleration = Vector3.new(1.5, 1.5, 0)
				emitter = made
				source = made
			end
			while t >= nextPuff do
				(source :: ParticleEmitter):Emit(2)
				nextPuff += PUFF_INTERVAL
			end
		end)
	end
	return body
end

-- ------------------------------------------------------------------ fire missions

-- A flat diamond on the ground (one Part, so nothing overlaps).
local function diamond(ctx: Ctx, at: Vector3, size: number): Part
	local mark = part(ctx, "Mark", Vector3.new(size, 0.15, size), ctx.color)
	mark.Material = Enum.Material.Neon
	mark.Transparency = 1
	mark.CFrame = CFrame.new(at + UP * 0.12) * CFrame.Angles(0, math.rad(45), 0)
	return mark
end

-- The round coming in on `impact` at `at`: its whistle, then the round itself for its last
-- Fall seconds with a thin smoke trail (Rules/Arrival.shellOffset).
local function incoming(ctx: Ctx, impact: Vector3, at: number)
	local arrival = ctx.arrival
	cue(ctx, Arrival.cueTime(at, arrival.Whistle, arrival.Throw), function()
		sound(
			impact + UP * 30,
			"callins",
			"anvil_incoming",
			arrival.WhistleVolume,
			arrival.WhistlePitch,
			true
		)
	end)
	local size = arrival.ShellSize :: Vector3
	local startBack, startUp = Arrival.shellOffset(arrival.Angle, arrival.Distance, 1)
	local start = impact - ctx.flat * startBack + UP * startUp
	local round = part(ctx, "Round", size, STEEL_DARK)
	round.Material = Enum.Material.Metal
	round.Transparency = 1
	round.CFrame = CFrame.lookAt(start, impact)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, size.Y / 2, size.Z / 2)
	top.Parent = round
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -size.Y / 2, size.Z / 2)
	bottom.Parent = round
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Enabled = false
	trail.Lifetime = arrival.Fall * 0.6
	trail.Color = ColorSequence.new(STEEL)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.LightEmission = 0
	trail.Parent = round
	local from = math.max(at - arrival.Fall, 0)
	track(ctx, from, at, function(t)
		local remaining = 1 - Arrival.progress(t, from, at)
		local back, up = Arrival.shellOffset(arrival.Angle, arrival.Distance, remaining)
		local position = impact - ctx.flat * back + UP * up
		round.Transparency = 0
		trail.Enabled = true
		if remaining > 0.001 then
			round.CFrame = CFrame.lookAt(position, impact)
		end
	end)
	cue(ctx, at, function()
		round:Destroy()
	end)
end

-- What a round does to the ground at `at` (the flash, the sound and the damage are the
-- server's): thrown dust, a low dome of it, and from the row a column of earth (Column),
-- smoke after (Linger) and burnt ground (Scorch).
local function strike(ctx: Ctx, impact: Vector3, at: number, radius: number)
	local arrival = ctx.arrival
	local dust = arrival.Dust :: Color3
	cue(ctx, at, function()
		puff(impact + UP, dust, arrival.DustCount, arrival.DustSize, radius * 1.2, 0.9)
		local linger = arrival.Linger :: number
		if linger > 0 then
			local smoke = emitterAt(impact + UP * 3, linger + 1)
			smoke.Color = ColorSequence.new(dust)
			smoke.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, arrival.DustSize * 0.5),
				NumberSequenceKeypoint.new(1, arrival.DustSize * 1.6),
			})
			smoke.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			smoke.Lifetime = NumberRange.new(linger * 0.6, linger)
			smoke.Speed = NumberRange.new(3, 9)
			smoke.SpreadAngle = Vector2.new(25, 25)
			smoke.Acceleration = Vector3.new(1.5, 1, 0)
			smoke:Emit(arrival.DustCount)
		end
	end)

	-- The dome: a flattened ball of dust that spreads to the blast's edge and thins out.
	-- (A Ball part is always round, so the squash is a sphere mesh's Scale.)
	local dome = part(ctx, "Dust", Vector3.one, dust)
	dome.Transparency = 1
	dome.CFrame = CFrame.new(impact + UP * 0.5)
	local domeShape = Instance.new("SpecialMesh")
	domeShape.MeshType = Enum.MeshType.Sphere
	domeShape.Parent = dome
	local domeEnds = at + 0.6
	track(ctx, at, domeEnds, function(t)
		local u = Arrival.easeOut(Arrival.progress(t, at, domeEnds))
		local wide = radius * (0.3 + 0.6 * u) * 2
		domeShape.Scale = Vector3.new(wide, arrival.DustSize * (0.5 + 0.5 * u), wide)
		dome.Transparency = 0.45 + 0.55 * u
	end)
	cue(ctx, domeEnds, function()
		dome:Destroy()
	end)

	local height = arrival.Column :: number
	if height > 0 then
		-- The column: up fast, then it hangs, widens and thins.
		local width = arrival.ColumnWidth :: number
		local column = part(ctx, "Column", Vector3.one, dust)
		column.Shape = Enum.PartType.Cylinder
		column.Transparency = 1
		local risen = at + 0.25
		local gone = at + 1.8
		track(ctx, at, gone, function(t)
			local rise = Arrival.easeOut(Arrival.progress(t, at, risen))
			local fade = Arrival.progress(t, risen, gone)
			local tall = math.max(height * rise * (1 - 0.15 * fade), 0.1)
			local wide = width * (1 + 0.4 * fade)
			column.Size = Vector3.new(tall, wide, wide)
			column.CFrame = CFrame.new(impact + UP * (tall / 2)) * CFrame.Angles(0, 0, math.rad(90))
			column.Transparency = 0.1 + 0.9 * fade
		end)
		cue(ctx, gone, function()
			column:Destroy()
		end)
	end

	local burnt = arrival.Scorch :: number
	if burnt > 0 then
		local disc = part(ctx, "Scorch", Vector3.new(0.1, radius * 0.9, radius * 0.9), SCORCH)
		disc.Shape = Enum.PartType.Cylinder
		disc.Transparency = 1
		disc.CFrame = CFrame.new(impact + UP * 0.07) * CFrame.Angles(0, 0, math.rad(90))
		local fadeFrom = at + math.max(burnt - 2, 0)
		track(ctx, at, at + burnt, function(t)
			disc.Transparency = 0.25 + 0.75 * Arrival.progress(t, fadeFrom, at + burnt)
		end)
	end
end

local STYLES: { [string]: (ctx: Ctx) -> () } = {}

STYLES.thrown = function(ctx: Ctx)
	thrown(ctx)
end

STYLES.mortar = function(ctx: Ctx)
	local arrival, cfg = ctx.arrival, ctx.cfg
	local landed = arrival.Throw
	thrown(ctx)
	local times = StrikePattern.impactTimes(#ctx.impacts, cfg.Delay, cfg.ShellInterval)
	-- The tubes are a long way behind the thrower.
	local tubes = ctx.point - ctx.flat * 140 + UP * 20
	for index, impact in ctx.impacts do
		local at = times[index]
		local mark = diamond(ctx, impact, 2.4)
		-- Dim until its round is a second out, then bright.
		track(ctx, landed, at, function(t)
			mark.Transparency = 0.6 - 0.5 * Arrival.progress(t, at - 1, at)
		end)
		if arrival.Report > 0 then
			cue(ctx, Arrival.cueTime(at, arrival.Report, landed), function()
				sound(
					tubes,
					"callins",
					"anvil_blast",
					arrival.ReportVolume,
					arrival.ReportPitch,
					true
				)
			end)
		end
		incoming(ctx, impact, at)
		cue(ctx, at, function()
			mark:Destroy()
		end)
		strike(ctx, impact, at, cfg.BlastRadius)
	end
end

STYLES.shell = function(ctx: Ctx)
	local arrival, cfg = ctx.arrival, ctx.cfg
	local landed = arrival.Throw
	thrown(ctx)
	local radius = cfg.BlastRadius :: number
	local times = StrikePattern.impactTimes(#ctx.impacts, cfg.Delay, cfg.ShellInterval)
	local segments = 16
	local chord = 2 * radius * math.sin(math.pi / segments)
	for index, impact in ctx.impacts do
		local at = times[index]
		local centre = diamond(ctx, impact, 3)
		local ring: { BasePart } = { centre }
		for _ = 1, segments do
			local dash = part(ctx, "Ring", Vector3.new(chord * 0.6, 0.15, 0.8), ctx.color)
			dash.Material = Enum.Material.Neon
			dash.Transparency = 1
			table.insert(ring, dash)
		end
		-- The ring starts Close blast radii out and closes on the blast's edge as the round
		-- lands, turning slowly and pulsing faster.
		track(ctx, landed, at, function(t)
			local u = Arrival.progress(t, landed, at)
			local reach = radius * (arrival.Close + (1 - arrival.Close) * u)
			local pulse = 0.5 + 0.5 * math.sin(t * (4 + 14 * u))
			local see = 0.2 + 0.4 * pulse
			centre.Transparency = see
			for slot = 1, segments do
				local angle = slot / segments * math.pi * 2 + t * 0.4
				local at3 = impact
					+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach
					+ UP * 0.12
				local dash = ring[slot + 1]
				dash.CFrame = CFrame.lookAt(at3, Vector3.new(impact.X, at3.Y, impact.Z))
				dash.Transparency = see
			end
		end)
		incoming(ctx, impact, at)
		cue(ctx, at, function()
			destroyAll(ring)
		end)
		strike(ctx, impact, at, radius)
	end
end

STYLES.gunrun = function(ctx: Ctx)
	local arrival, cfg = ctx.arrival, ctx.cfg
	local landed = arrival.Throw
	thrown(ctx)
	local count = #ctx.impacts
	if count == 0 then
		return
	end
	local delay = cfg.Delay :: number
	local interval = cfg.BurstInterval :: number
	local step = cfg.Step :: number
	local width = cfg.BlastRadius * 2
	local span = step * (count - 1) + width
	local firstOffset = -step * (count - 1) / 2

	-- The lane: rungs across the run, lit one after another the way the gunship flies; each
	-- goes as the bursts pass it.
	local marks = Arrival.lane(span, arrival.MarkSpacing)
	for index, offset in marks do
		local ground = GroundUtil.GetGroundPosition(ctx.point + ctx.flat * offset, 0.12)
		local rung = part(ctx, "Rung", Vector3.new(width * 0.8, 0.15, 0.7), ctx.color)
		rung.Material = Enum.Material.Neon
		rung.Transparency = 1
		rung.CFrame = CFrame.lookAt(ground, ground + ctx.flat)
		local passedAt = delay
			+ math.clamp((offset - firstOffset) / math.max(step, 0.01), 0, count - 1) * interval
		local place = (index - 1) / #marks
		track(ctx, landed, passedAt, function(t)
			local phase = (t * 1.5 - place) % 1
			rung.Transparency = if phase < 0.2 then 0.15 else 0.7
		end)
		cue(ctx, passedAt, function()
			rung:Destroy()
		end)
	end

	-- Where the gunship's gun is at `t` (the server flies the same pass, Rules/Arrival.pass).
	local startsAt, seconds = Arrival.pass(delay, arrival.Approach, count, interval)
	local height = UP * cfg.PassHeight
	local lead = ctx.flat * cfg.PassLead
	local from = ctx.impacts[1] + height - lead
	local to = ctx.impacts[count] + height + lead
	local function muzzle(t: number): Vector3?
		local fraction = Arrival.passFraction(t, startsAt, seconds)
		if not fraction then
			return nil
		end
		local at = from:Lerp(to, fraction)
		return (CFrame.lookAt(at, at + ctx.flat) * CFrame.new(cfg.GunMuzzle)).Position
	end

	local side = ctx.flat:Cross(UP)
	local dust = arrival.Dust :: Color3
	for index, impact in ctx.impacts do
		local at = delay + interval * (index - 1)
		cue(ctx, at, function()
			local gun = muzzle(at) or impact + height
			if (index - 1) % math.max(arrival.GunEvery, 1) == 0 then
				sound(gun, "guns", arrival.GunSound, arrival.GunVolume, arrival.GunPitch, true)
			end
			puff(impact + UP * 0.5, dust, arrival.DustCount, arrival.DustSize, 14, 0.6)
			-- The rest of the burst: rounds landing either side of the one that counts.
			for _ = 1, arrival.Tracers do
				local wide = (math.random() * 2 - 1) * arrival.TracerSpread
				local long = (math.random() * 2 - 1) * step / 2
				local hit = impact + side * wide + ctx.flat * long
				local line = Instance.new("Part")
				line.Name = "Tracer"
				line.Size = Vector3.new(0.2, 0.2, (hit - gun).Magnitude)
				line.CFrame = CFrame.lookAt((gun + hit) / 2, hit)
				line.Anchored = true
				line.CanCollide = false
				line.CanQuery = false
				line.CanTouch = false
				line.CastShadow = false
				line.Material = Enum.Material.Neon
				line.Color = TRACER
				line.Parent = folder
				Debris:AddItem(line, 0.07)
			end
		end)
	end
end

-- ------------------------------------------------------------------ emplacements

STYLES.case = function(ctx: Ctx)
	local arrival = ctx.arrival
	local landed = arrival.Throw
	local ready = arrival.Time
	local down = math.max(ready - arrival.Settle, landed)
	local dropHeight = arrival.Height :: number
	local sway = arrival.Sway :: number
	local canopy = arrival.Chute :: number
	local hang = canopy * 0.9 -- the chute rides this far above the case

	local case = part(ctx, "Case", CASE_SIZE, OLIVE)
	case.Material = Enum.Material.Metal
	local lid = part(ctx, "Lid", Vector3.new(CASE_SIZE.X, 0.15, CASE_SIZE.Z), OLIVE_DARK)
	lid.Material = Enum.Material.Metal
	-- A cross-shaped cargo chute: one long panel and a square either side of it, edge to edge
	-- (nothing overlaps).
	local third = canopy / 3
	local long = part(ctx, "Chute", Vector3.new(canopy, 0.2, third), CANOPY)
	local left = part(ctx, "Chute", Vector3.new(third, 0.2, third), CANOPY)
	local right = part(ctx, "Chute", Vector3.new(third, 0.2, third), CANOPY)
	local chute: { BasePart } = { long, left, right }
	for _, panel in chute do
		panel.Material = Enum.Material.Fabric
	end
	local pieces: { BasePart } = { case, lid, long, left, right }
	setVisible(pieces, false)

	-- Four lines from the chute's arms to the case's corners.
	local lines: { Beam } = {}
	local function line(panel: BasePart, onPanel: Vector3, onCase: Vector3)
		local upper = Instance.new("Attachment")
		upper.Position = onPanel
		upper.Parent = panel
		local lower = Instance.new("Attachment")
		lower.Position = onCase
		lower.Parent = case
		local beam = Instance.new("Beam")
		beam.Attachment0 = upper
		beam.Attachment1 = lower
		beam.Width0 = 0.08
		beam.Width1 = 0.08
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Color = ColorSequence.new(CORD)
		beam.LightEmission = 0
		beam.Enabled = false
		beam.Parent = panel
		table.insert(lines, beam)
	end
	local cornerX, cornerY, cornerZ = CASE_SIZE.X / 2, CASE_SIZE.Y / 2, CASE_SIZE.Z / 2
	line(long, Vector3.new(canopy / 2, -0.1, 0), Vector3.new(cornerX, cornerY, 0))
	line(long, Vector3.new(-canopy / 2, -0.1, 0), Vector3.new(-cornerX, cornerY, 0))
	line(left, Vector3.new(0, -0.1, third / 2), Vector3.new(0, cornerY, cornerZ))
	line(right, Vector3.new(0, -0.1, -third / 2), Vector3.new(0, cornerY, -cornerZ))

	local function placeChute(at: CFrame)
		long.CFrame = at
		left.CFrame = at * CFrame.new(0, 0, third)
		right.CFrame = at * CFrame.new(0, 0, -third)
	end

	local marker = thrown(ctx)
	track(ctx, landed, down, function(t)
		local height = Arrival.drift(t, landed, down, dropHeight)
		local swing = math.sin(t * 3) * sway * (height / math.max(dropHeight, 1))
		local base = ctx.frame * CFrame.new(swing, height + CASE_SIZE.Y / 2, 0)
		case.CFrame = base
		lid.CFrame = base * CFrame.new(0, CASE_SIZE.Y / 2 + 0.075, 0)
		placeChute(base * CFrame.new(-swing * 0.5, hang, 0))
		setVisible(pieces, true)
		for _, beam in lines do
			beam.Enabled = true
		end
	end)
	cue(ctx, down, function()
		marker:Destroy() -- under the case now
		for _, beam in lines do
			beam.Enabled = false
		end
		puff(ctx.point + UP * 0.5, CORD, 8, 4, 12, 0.8)
		sound(ctx.point, "callins", "pallet_land", 0.5, 1.2, false)
	end)
	-- The chute comes down beside the case and goes.
	local folded = down + 0.7
	track(ctx, down, folded, function(t)
		local u = Arrival.easeOut(Arrival.progress(t, down, folded))
		local rest = CASE_SIZE.Y / 2 + hang
		-- 0.8 of its width aside: clear of the case before it is down to the lid's height.
		placeChute(ctx.frame * CFrame.new(-(canopy * 0.8) * u, rest * (1 - u) + 0.3, 0))
		for _, panel in chute do
			panel.Transparency = u
		end
	end)
	cue(ctx, folded, function()
		destroyAll(chute)
	end)
	-- The gun stands up (the server's tripod appears here now).
	cue(ctx, ready, function()
		case:Destroy()
		lid:Destroy()
		puff(ctx.point + UP, CORD, 4, 3, 8, 0.5)
		sound(ctx.point, "callins", "tripline_arm", 1, 0.6, false)
	end)
end

STYLES.scatter = function(ctx: Ctx)
	local arrival, cfg = ctx.arrival, ctx.cfg
	local landed = arrival.Throw
	local armed = arrival.Time
	local settled = math.max(armed - 0.1, landed)
	local satchel = thrown(ctx)
	satchel.Color = OLIVE
	satchel.Material = Enum.Material.Fabric
	local angles = Arrival.arcAngles(cfg.Mines, cfg.ArcDegrees)
	for index, angle in angles do
		local direction = CFrame.fromAxisAngle(UP, angle):VectorToWorldSpace(ctx.flat)
		local spot = GroundUtil.GetGroundPosition(ctx.point + direction * cfg.ArcRadius, 0.2)
		local charge = part(ctx, "Charge", Vector3.new(0.3, 0.9, 0.9), POLYMER)
		charge.Shape = Enum.PartType.Cylinder
		charge.Transparency = 1
		local leaves = math.min(landed + (index - 1) * 0.03, settled)
		track(ctx, leaves, settled, function(t)
			local u = Arrival.progress(t, leaves, settled)
			local at = ctx.point:Lerp(spot, u)
				+ UP * (0.3 + Arrival.hop(t, leaves, settled, arrival.Hop))
			charge.Transparency = 0
			charge.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
		end)
		-- Armed: the charge is the server's mine now; one blink in the call-in's colour.
		local blink = part(ctx, "Armed", Vector3.one * 0.5, ctx.color)
		blink.Shape = Enum.PartType.Ball
		blink.Material = Enum.Material.Neon
		blink.Transparency = 1
		blink.CFrame = CFrame.new(spot + UP * 1.2)
		cue(ctx, armed, function()
			charge:Destroy()
		end)
		track(ctx, armed, armed + 0.3, function(t)
			blink.Transparency = Arrival.progress(t, armed, armed + 0.3)
		end)
	end
	cue(ctx, settled, function()
		satchel:Destroy()
	end)
end

STYLES.unroll = function(ctx: Ctx)
	local arrival, cfg = ctx.arrival, ctx.cfg
	local landed = arrival.Throw
	local standing = arrival.Time
	local half = cfg.Length / 2
	local axis = ctx.flat:Cross(UP).Unit -- the wire's long side, as the server lays it
	local coil = thrown(ctx)
	coil.Shape = Enum.PartType.Cylinder
	coil.Color = STEEL
	local drumWide = 1.4
	local axle = UP * (drumWide / 2)
	local drums: { BasePart } = {}
	local strands: { BasePart } = {}
	for _ = 1, 2 do
		local drum = part(ctx, "Drum", Vector3.new(0.7, drumWide, drumWide), STEEL)
		drum.Shape = Enum.PartType.Cylinder
		drum.Material = Enum.Material.Metal
		drum.Transparency = 1
		table.insert(drums, drum)
		local strand = part(ctx, "Strand", Vector3.new(0.12, 0.12, 0.1), STEEL)
		strand.Material = Enum.Material.Metal
		strand.Transparency = 1
		table.insert(strands, strand)
	end
	local dust = arrival.Dust :: Color3
	local nextDust = landed
	track(ctx, landed, standing, function(t)
		local reach = half * Arrival.easeOut(Arrival.progress(t, landed, standing))
		for index, drum in drums do
			local way = if index == 1 then axis else -axis
			local at = ctx.point + way * reach + axle
			drum.Transparency = 0
			-- The cylinder's length (X) lies across the roll; it turns as it goes.
			drum.CFrame = CFrame.lookAt(at, at + way) * CFrame.Angles(-reach / (drumWide / 2), 0, 0)
			local strand = strands[index]
			local length = math.max(reach - drumWide / 2, 0.05)
			strand.Transparency = if reach > drumWide / 2 then 0 else 1
			strand.Size = Vector3.new(0.12, 0.12, length)
			local middle = ctx.point + way * (length / 2) + axle
			strand.CFrame = CFrame.lookAt(middle, middle + way)
		end
		if t >= nextDust then
			nextDust += 0.2
			for index = 1, 2 do
				local way = if index == 1 then axis else -axis
				puff(
					ctx.point + way * reach + UP * 0.3,
					dust,
					arrival.DustCount,
					arrival.DustSize,
					5,
					0.5
				)
			end
		end
	end)
	-- The coil springs open; it rattles as it pays out.
	cue(ctx, landed, function()
		coil:Destroy()
	end)
	local span = standing - landed
	for rattle = 0, 2 do
		cue(ctx, landed + span * rattle / 3, function()
			sound(ctx.point, "callins", "tripline_arm", 0.6, 0.7 + rattle * 0.08, false)
		end)
	end
	-- The wire stands (the server's is here now).
	cue(ctx, standing, function()
		destroyAll(drums)
		destroyAll(strands)
	end)
end

-- ------------------------------------------------------------------ supply

STYLES.tumble = function(ctx: Ctx)
	local arrival = ctx.arrival
	local settled = arrival.Time
	local touches = math.max(settled - arrival.Settle, 0)
	local kicked = math.max(touches - arrival.Fall, 0)
	local dropHeight = arrival.Height :: number
	local bundle = part(ctx, "Bundle", BUNDLE_SIZE, OLIVE)
	bundle.Material = Enum.Material.Fabric
	local strap = part(ctx, "Strap", Vector3.new(BUNDLE_SIZE.X * 0.3, 0.1, BUNDLE_SIZE.Z), CORD)
	strap.Material = Enum.Material.Fabric
	local pieces: { BasePart } = { bundle, strap }
	setVisible(pieces, false)
	local strapOffset = CFrame.new(0, BUNDLE_SIZE.Y / 2 + 0.05, 0)
	local marker = thrown(ctx)
	-- Down fast, turning end over end, level again as it hits.
	track(ctx, kicked, touches, function(t)
		local height = Arrival.fall(t, kicked, touches, dropHeight)
		local turn = math.rad(arrival.Spin) * (touches - t)
		local base = ctx.frame
			* CFrame.new(0, height + BUNDLE_SIZE.Y / 2, 0)
			* CFrame.Angles(turn, turn * 0.6, 0)
		bundle.CFrame = base
		strap.CFrame = base * strapOffset
		setVisible(pieces, true)
	end)
	cue(ctx, touches, function()
		marker:Destroy() -- under the bundle now
		puff(ctx.point + UP * 0.5, CORD, 10, 5, 14, 0.9)
	end)
	-- One bounce.
	track(ctx, touches, settled, function(t)
		local height = Arrival.hop(t, touches, settled, arrival.Hop)
		local tip = math.rad(10) * height / math.max(arrival.Hop, 0.01)
		local base = ctx.frame
			* CFrame.new(0, height + BUNDLE_SIZE.Y / 2, 0)
			* CFrame.Angles(tip, 0, 0)
		bundle.CFrame = base
		strap.CFrame = base * strapOffset
	end)
	-- Settled: the server's bundle is here now.
	cue(ctx, settled, function()
		destroyAll(pieces)
		puff(ctx.point + UP * 0.5, CORD, 4, 3, 8, 0.6)
	end)
end

STYLES.streamer = function(ctx: Ctx)
	local arrival = ctx.arrival
	local landed = arrival.Throw
	local down = math.max(arrival.Time, landed)
	local dropHeight = arrival.Height :: number
	local sway = arrival.Sway :: number
	local length = arrival.Streamer :: number
	-- The same bag the server puts down (SupplyDropService.aidBagBody).
	local bag = part(ctx, "Bag", BAG_SIZE, BAG)
	bag.Material = Enum.Material.Fabric
	local patch = part(ctx, "Patch", Vector3.new(1, 0.05, 1), PATCH)
	patch.Material = Enum.Material.Fabric
	local pieces: { BasePart } = { bag, patch }
	setVisible(pieces, false)
	-- The streamer: a striped ribbon from the bag's top to a tip that trails above it.
	local root = part(ctx, "StreamerRoot", Vector3.one * 0.2, BAG)
	root.Transparency = 1
	local tip = part(ctx, "StreamerTip", Vector3.one * 0.2, BAG)
	tip.Transparency = 1
	local rootAt = Instance.new("Attachment")
	rootAt.Parent = root
	local tipAt = Instance.new("Attachment")
	tipAt.Parent = tip
	local ribbon = Instance.new("Beam")
	ribbon.Attachment0 = rootAt
	ribbon.Attachment1 = tipAt
	ribbon.Width0 = 1
	ribbon.Width1 = 0.7
	ribbon.FaceCamera = true
	ribbon.Segments = 12
	ribbon.LightEmission = 0
	ribbon.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PATCH),
		ColorSequenceKeypoint.new(0.24, PATCH),
		ColorSequenceKeypoint.new(0.25, CROSS_RED),
		ColorSequenceKeypoint.new(0.49, CROSS_RED),
		ColorSequenceKeypoint.new(0.5, PATCH),
		ColorSequenceKeypoint.new(0.74, PATCH),
		ColorSequenceKeypoint.new(0.75, CROSS_RED),
		ColorSequenceKeypoint.new(1, CROSS_RED),
	})
	ribbon.Enabled = false
	ribbon.Parent = root

	local marker = thrown(ctx)
	local top = BAG_SIZE.Y
	local tipUp = BAG_SIZE.Y / 2 + length -- the tip's height over the mark as the bag lands
	track(ctx, landed, down, function(t)
		local height = Arrival.drift(t, landed, down, dropHeight)
		local swing = math.sin(t * 2.5) * sway * (height / math.max(dropHeight, 1))
		local base = ctx.frame * CFrame.new(swing, height + BAG_SIZE.Y / 2, 0)
		bag.CFrame = base
		patch.CFrame = base * CFrame.new(0, BAG_SIZE.Y / 2 + 0.03, 0)
		root.CFrame = base * CFrame.new(0, BAG_SIZE.Y / 2, 0)
		tip.CFrame = base
			* CFrame.new(-swing * 1.5 + math.sin(t * 6) * 0.8, length, math.cos(t * 5) * 0.8)
		ribbon.CurveSize0 = math.sin(t * 9) * 1.5
		ribbon.CurveSize1 = math.cos(t * 7) * 1.5
		ribbon.Enabled = true
		setVisible(pieces, true)
	end)
	-- Down: the server's bag is here now; the streamer falls across the ground and goes.
	cue(ctx, down, function()
		marker:Destroy()
		destroyAll(pieces)
		puff(ctx.point + UP * 0.5, CORD, 5, 3, 7, 0.7)
	end)
	local limp = down + 0.6
	local gone = limp + 0.5
	track(ctx, down, gone, function(t)
		local u = Arrival.easeOut(Arrival.progress(t, down, limp))
		root.CFrame = ctx.frame * CFrame.new(0, top, 0)
		tip.CFrame = ctx.frame * CFrame.new(length * 0.7 * u, tipUp * (1 - u) + 0.15 * u, 0)
		ribbon.CurveSize0 = 1.5 * (1 - u)
		ribbon.CurveSize1 = 1.5 * (1 - u)
		ribbon.Transparency = NumberSequence.new(Arrival.progress(t, limp, gone))
	end)
end

-- ------------------------------------------------------------------ the remote

local function remove(index: number)
	active[index].model:Destroy()
	table.remove(active, index)
end

local function clear()
	for index = #active, 1, -1 do
		remove(index)
	end
end

local function onArrival(
	id: unknown,
	thrower: unknown,
	point: unknown,
	direction: unknown,
	impacts: unknown
)
	local settings = Config.CallIns.Arrivals
	if not settings.Enabled or typeof(id) ~= "string" then
		return
	end
	if typeof(point) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	local definition = CallInDefinitions.get(id)
	local cfg = definition and (Config.CallIns :: { [string]: any })[definition.ConfigKey]
	if not definition or not cfg then
		return
	end
	local arrival = Arrival.resolve(settings.Defaults :: any, cfg.Arrival)

	local flat = Vector3.new(direction.X, 0, direction.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	-- The hand it left: the thrower's body when it is here, else a short lob onto the mark.
	local origin = point - flat * 6 + UP * 2
	if typeof(thrower) == "Instance" and thrower:IsA("Player") then
		local character = thrower.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			origin = root.Position + UP * 1.5
		end
	end
	local landings: { Vector3 } = {}
	if typeof(impacts) == "table" then
		for _, impact in impacts :: { unknown } do
			if typeof(impact) == "Vector3" then
				table.insert(landings, impact)
			end
		end
	end

	while #active >= settings.MaxActive do
		remove(1)
	end
	local model = Instance.new("Model")
	model.Name = "Arrival_" .. id
	local ctx: Ctx = {
		model = model,
		cfg = cfg,
		arrival = arrival,
		color = definition.Color,
		origin = origin,
		point = point,
		flat = flat,
		frame = CFrame.lookAt(point, point + flat),
		impacts = landings,
		elapsed = 0,
		endsAt = 0,
		cues = {},
		tracks = {},
	}
	-- A Style this client does not know still gets its marker.
	local ok: boolean, problem: any = (xpcall :: any)(
		STYLES[arrival.Style] or STYLES.thrown,
		debug.traceback,
		ctx
	)
	if not ok then
		warn(`CallInArrivalFX: {id} ({arrival.Style}) could not be drawn: {problem}`)
		model:Destroy()
		return
	end
	hold(ctx, arrival.Throw)
	model.Parent = folder
	table.insert(active, ctx)
end

local function step(dt: number)
	if workspace:GetAttribute(Attributes.GamePaused) == true then
		return
	end
	for index = #active, 1, -1 do
		local ctx = active[index]
		local ok: boolean, problem: any = (xpcall :: any)(advance, debug.traceback, ctx, dt)
		if not ok then
			warn(`CallInArrivalFX: {ctx.model.Name} stopped: {problem}`)
			remove(index)
		elseif ctx.elapsed >= ctx.endsAt then
			remove(index)
		end
	end
end

function CallInArrivalFX.init()
	folder = Instance.new("Folder")
	folder.Name = "CallInEffects"
	folder.Parent = workspace
	Remotes.get("CallInArrival").OnClientEvent:Connect(onArrival)
	RunService.RenderStepped:Connect(step)
	-- A new run: whatever was still on its way in belongs to the last one.
	workspace:GetAttributeChangedSignal(Attributes.RunStartTime):Connect(clear)
end

return CallInArrivalFX
