--!strict
-- The objective pools (docs/PROGRESSION.md > Objective pools): every objective's row and
-- every map's pool. Read through Config.Objectives.Rows / .Maps; ObjectiveService draws from
-- them and src/server/Objectives/<Module> plays the row. Plain data (positions are
-- { x, y, z }) so tests/ObjectiveDefinitions.spec.luau can load and check it outside Studio.
--
-- Two kinds of objective:
--   shared     any map may list it, by giving it Sites on that map
--   signature  belongs to one map (`Map`), built round that map's own landmarks and story;
--              never offered anywhere else
-- A new objective is a row here plus its module; a new map is a row in MAPS (its pools and
-- its sites). Nothing else names an objective: no list in the service, the HUD or the dev
-- tools.
--
-- Every row carries its own words, in plain language (docs/OWNER.md):
--   Brief   Control's radio line when the squad learns of it: what is wrong, what to do
--   Why     the reason, eight words or fewer, on the HUD under the name the whole time
--   Done    Control's line when it is finished: what changed because of it
--   Failed  (side objectives with a timer) Control's line when the time runs out
-- "{place}" in a line is the drawn site's Name, "{to}" its ToName.

export type Vec = { number } -- { x, y, z } in studs

-- One place an objective can be played on a map. Position is where its marker stands;
-- the rest is what that objective's module needs there (the row's `Needs`).
export type Site = {
	Name: string, -- as Control says it: "the Pens"
	Position: Vec,
	Size: Vec?, -- a hold zone's size
	Points: { Vec }?, -- props to interact with
	Spawns: { Vec }?, -- where marked Infected stand
	To: Vec?, -- where a carried item goes
	ToName: string?,
}

export type Row = {
	Kind: string, -- "shared" | "signature"
	Map: string?, -- signature only: the one map it belongs to
	Role: string, -- "main" | "side"
	Module: string, -- src/server/Objectives/<Module>
	Name: string,
	Brief: string,
	Why: string,
	Done: string,
	Failed: string?,
	Needs: { string }, -- Site fields this objective must have on every map that lists it
	-- A living squad member this close starts it (0 = as soon as it is known).
	StartRadius: number,
	Wave: { [string]: number }?, -- main: lands round it on start (default Config.Objective.PressureWave)
	Supply: number?, -- side: paid into the Resupply pool on Done
	Hold: number?, -- seconds of F on a prop
	Seconds: number?, -- a hold's length, or a timer
	Radius: number?,
	Form: string?, -- EnemyDefinitions key of the marked Infected
	Count: number?, -- marked Infected, one player
	PerExtraPlayer: number?, -- more per living player beyond the first
	BurnWave: { [string]: number }?,
	SurviveWave: { [string]: number }?,
	DeliverRadius: number?,
	ReachRadius: number?,
	SpawnFactor: number?,
	MaxLamps: number?,
	LampRange: number?,
	LampBrightness: number?,
}

export type Pick = { Id: string, Weight: number }

export type Map = {
	Main: { Pick }, -- drawn by weight, never the same twice in a row on a server
	Side: { Pick },
	Sites: { [string]: { Site } }, -- by objective id: where it can be played here
}

local ROWS: { [string]: Row } = {
	-- Shared main objectives.
	secure_site = {
		Kind = "shared",
		Role = "main",
		Module = "SecureSite",
		Name = "Secure the Site",
		Brief = "We lost the perimeter at {place}. Take it back and hold it so the helicopter can land.",
		Why = "Control needs the perimeter back to land",
		Done = "Perimeter is ours again. The helicopter has a way in.",
		Needs = { "Size" },
		StartRadius = 34,
		Seconds = 45, -- accumulated inside the zone
	},
	restore_comms = {
		Kind = "shared",
		Role = "main",
		Module = "RestoreComms",
		Name = "Restore Comms",
		Brief = "We are blind past the Gate and can't call the helicopter in. Get the radio mast at {place} working, then hold it.",
		Why = "No mast, no way to call the helicopter",
		Done = "Signal is back. We can see past the Gate and call the helicopter.",
		Needs = {},
		StartRadius = 40,
		Hold = 10, -- seconds of F on the radio set (letting go starts over)
		Seconds = 60, -- then held, accumulated while a living member is within Radius
		Radius = 20,
		SurviveWave = { Hocker = 2, Walker = 6, Runner = 3 },
	},
	confirm_casualties = {
		Kind = "shared",
		Role = "main",
		Module = "ConfirmCasualties",
		Name = "Confirm Casualties",
		Brief = "Heavy Infected are massing in {place}. Left alone they overrun the landing pad. Put them down.",
		Why = "The heavies will overrun the landing pad",
		Done = "The heavies are down. The landing pad is safe from that side.",
		Needs = { "Spawns" },
		StartRadius = 75,
		Wave = { Walker = 6 },
		Form = "Brute",
		Count = 3,
		PerExtraPlayer = 1,
	},
	recover_record = {
		Kind = "shared",
		Role = "main",
		Module = "RecoverRecord",
		Name = "Recover the Record",
		Brief = "The checkpoint's screening record is at {place}. We need to know who got through. Carry it to {to}.",
		Why = "Control must know who got through the checkpoint",
		Done = "Record sent. Now we know who got through before it fell.",
		Needs = { "To", "ToName" },
		StartRadius = 40,
		Hold = 1, -- seconds of the interact key to pick it up
		DeliverRadius = 9,
	},

	-- Checkpoint Delta's signature main objective: the screening tents at the Pens.
	sanitize = {
		Kind = "signature",
		Map = "delta",
		Role = "main",
		Module = "Sanitize",
		Name = "Sanitize the Pens",
		Brief = "The checkpoint's screening tents at the Pens are full of people who never got cleared. They will get up. Burn all three before the airstrike.",
		Why = "Bodies in the screening tents will get up",
		Done = "The tents are burning. Nobody in the Pens is getting back up.",
		Needs = { "Points" },
		StartRadius = 45,
		Hold = 3, -- seconds of F at each tent
		BurnWave = { Runner = 4, Walker = 3 }, -- flushed out by each fire
	},

	-- Shared side objectives: optional, failing one costs nothing.
	lights_on = {
		Kind = "shared",
		Role = "side",
		Module = "LightsOn",
		Name = "Lights On",
		Brief = "You are fighting blind and the helicopter needs light to find you. The generator at {place} still works. Start it.",
		Why = "The helicopter needs light to find you",
		Done = "Lights are on. The helicopter can see you, so supplies come sooner.",
		Needs = {},
		StartRadius = 0,
		Supply = 300,
		Hold = 8,
		Radius = 320, -- lamp posts this close to the generator light, nearest first
		MaxLamps = 5, -- STYLES light budget (20 static lights a mission)
		LampRange = 48,
		LampBrightness = 1.6,
	},
	misdrop = {
		Kind = "shared",
		Role = "side",
		Module = "Misdrop",
		Name = "Misdrop",
		Brief = "The helicopter put a supply pallet down in the wrong place: {place}. Get to it before the Infected swarm it.",
		Why = "Your supplies landed in the wrong place",
		Done = "Pallet is yours. Take what you need.",
		Failed = "Too late. The Infected swarmed the pallet. It is gone.",
		Needs = {},
		StartRadius = 0,
		Supply = 0, -- the crate (supply cards) is the reward
		Seconds = 240,
		ReachRadius = 10,
	},
	clear_spitters = {
		Kind = "shared",
		Role = "side",
		Module = "ClearSpitters",
		Name = "Clear the Spitters",
		Brief = "Spitters at {place} are shelling the landing pad, so the helicopter can't drop supplies. Kill them fast.",
		Why = "Spitters are shelling the helicopter's landing pad",
		Done = "Spitters are down. The supply drop we were holding is yours.",
		Failed = "Out of time. The Spitters dug in. No supply drop.",
		Needs = {},
		StartRadius = 45, -- they show, and the timer starts, when the squad gets this close
		Supply = 600, -- the Resupply burst
		Form = "Hocker",
		Count = 3,
		PerExtraPlayer = 1,
		Seconds = 120,
	},

	-- Checkpoint Delta's signature side objective: the Gate siren.
	silence_alarm = {
		Kind = "signature",
		Map = "delta",
		Role = "side",
		Module = "SilenceAlarm",
		Name = "Silence the Alarm",
		Brief = "The Gate siren has been running since the checkpoint fell, and it is drawing every Infected in the district. Shut it off.",
		Why = "The Gate siren is drawing Infected to you",
		Done = "Siren is off. Fewer of them will come to the Gate now.",
		Needs = {},
		StartRadius = 0,
		Supply = 150,
		Hold = 4,
		Radius = 140, -- roaming spawns picked this close to the siren ...
		SpawnFactor = 0.4, -- ... happen only this share of the time once it is off
	},
}

-- Coordinates: docs/LEVELS.md (A3 the three sites, A5 placements, A7 side objectives).
local MAPS: { [string]: Map } = {
	delta = {
		Main = {
			{ Id = "sanitize", Weight = 1.5 }, -- the signature comes up a little more often
			{ Id = "secure_site", Weight = 1 },
			{ Id = "restore_comms", Weight = 1 },
			{ Id = "confirm_casualties", Weight = 1 },
			{ Id = "recover_record", Weight = 1 },
		},
		Side = {
			{ Id = "silence_alarm", Weight = 1.5 },
			{ Id = "lights_on", Weight = 1 },
			{ Id = "misdrop", Weight = 1 },
			{ Id = "clear_spitters", Weight = 1 },
		},
		Sites = {
			secure_site = {
				{
					Name = "the Screening Compound",
					Position = { 50, 8.5, 50 },
					Size = { 46, 1, 46 },
				},
				{ Name = "the Pens", Position = { -240, 6.5, 120 }, Size = { 46, 1, 46 } },
				{ Name = "the Overlook", Position = { 105, 14.5, -105 }, Size = { 28, 1, 28 } },
			},
			sanitize = {
				{
					Name = "the Pens",
					Position = { -254, 7, 120 },
					-- the three tents' east faces
					Points = { { -254, 7.1, 102 }, { -254, 7.1, 120 }, { -254, 7.1, 138 } },
				},
			},
			restore_comms = {
				{ Name = "the comm tower", Position = { 88, 17.2, 88 } },
			},
			confirm_casualties = {
				{
					Name = "the Depot",
					Position = { 211, 0.5, 32 },
					-- the ends of the three container aisles
					Spawns = {
						{ 185, 0, 2 },
						{ 185, 0, 62 },
						{ 211, 0, 2 },
						{ 211, 0, 62 },
						{ 237, 0, 2 },
						{ 237, 0, 62 },
					},
				},
			},
			recover_record = {
				{
					Name = "the Ridge",
					Position = { -90, 8.25, 56 },
					To = { 88, 16.5, 88 },
					ToName = "the comm tower",
				},
			},
			silence_alarm = {
				{ Name = "the Gate", Position = { -14, 3, -263.1 } },
			},
			lights_on = {
				{ Name = "the Depot", Position = { 178, 3, 1.2 } },
			},
			misdrop = {
				{ Name = "the Suburb", Position = { 20, 0, 250 } },
				{ Name = "the Barracks", Position = { -250, 0, -20 } },
				{ Name = "the Depot mound", Position = { 235, 12, -205 } },
			},
			clear_spitters = {
				{ Name = "the highway", Position = { -175, 12, -45 } },
				{ Name = "the bus line", Position = { -25, 0, -160 } },
			},
		},
	},
}

return {
	Rows = ROWS,
	Maps = MAPS,
}
