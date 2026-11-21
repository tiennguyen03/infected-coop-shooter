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
--
-- A main objective's `Boss` block: how the Warden plays its last act (docs/PROGRESSION.md >
-- The Warden in the main objective). Any field left out comes from Config.Objectives.Boss.

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
	BossFrom: Vec?, -- main objectives: where the Warden walks in from (default: open ground nearby)
}

-- Fields as in Config.Objectives.Boss; each one optional here.
export type Boss = {
	At: number?, -- share of the objective's progress when he comes
	Contest: number?, -- studs: he stops it while he stands this close (0 = never)
	Target: string?, -- "nearest" | "carrier"
	EnterMin: number?,
	EnterMax: number?,
	HealthFactor: number?,
	Arrive: string?, -- Control, when he comes
	Contested: string?, -- Control, the first time he stands on it
	Blocked: string?, -- the HUD step while he stands on it
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
	-- Words for a module two maps share (Sanitize, SilenceAlarm); nil = the module's own.
	Prompt: string?, -- the hold prompt's action ("Burn the bus")
	Object: string?, -- the prompt's object ("Fuel can")
	Step: string?, -- the HUD step after "Hold E " ("at each fuel can to burn the buses")
	Target: string?, -- SilenceAlarm: the map part the noise comes from ("Siren")
	Sound: string?, -- SilenceAlarm: its loop (WorldSounds key)
	Noise: { Reach: number, Every: number }?, -- SilenceAlarm: wakes the Infected until off
	LampRange: number?,
	LampBrightness: number?,
	Boss: Boss?, -- main only: the Warden's last act (defaults Config.Objectives.Boss)
}

export type Pick = { Id: string, Weight: number }

export type Map = {
	Of: string?, -- a bigger version of that map: it plays that map's signature objectives
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
		-- He comes halfway through the hold and the hold stops while he stands in the zone.
		Boss = {
			At = 0.5,
			Contest = 1, -- on: the zone itself is the area
			Arrive = "That woke the Warden. He still holds this perimeter, and he's coming to take {place} back.",
			Contested = "He's inside the perimeter. The hold stops while he stands in it. Pull him out.",
			Blocked = "The Warden is in the zone: pull him out",
		},
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
		-- He comes 30 s into the 60 s hold and the signal stops while he is at the mast.
		Boss = {
			At = 0.5,
			Contest = 1, -- on: the hold's Radius is the area
			Arrive = "That signal woke the Warden. He still answers this radio, and he's coming for the mast.",
			Contested = "He's at the mast and the signal is dropping. Pull him away from it.",
			Blocked = "The Warden is at the mast: pull him away",
		},
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
		-- He comes when half the heavies are down: they were his reserve.
		Boss = {
			At = 0.5,
			Arrive = "Those heavies were his reserve. The Warden is coming to {place} to lead the rest.",
		},
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
		-- He comes a third of the way and hunts whoever carries the record.
		Boss = {
			At = 0.3,
			Target = "carrier",
			Arrive = "That record is his. The Warden kept the count, and he's coming for whoever carries it.",
		},
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
		-- He comes when the second tent burns, goes to the last fuel can and it will not
		-- light while he stands at it.
		Boss = {
			At = 0.6,
			Contest = 14,
			Arrive = "The fires woke the Warden. Those were his pens. He's coming to guard the last tent.",
			Contested = "He's standing over the last fuel can. Pull him off it, then burn it.",
			Blocked = "The Warden is at the fuel can: pull him off",
		},
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

	-- Mile 14's signature main objective: three sealed buses in the jam (the Sanitize module).
	burn_buses = {
		Kind = "signature",
		Map = "mile14",
		Role = "main",
		Module = "Sanitize",
		Name = "Burn the Buses",
		Brief = "Three buses in the jam are sealed with the bitten inside. When they get out, the road is theirs. Burn all three.",
		Why = "Sealed buses full of the bitten",
		Done = "The buses are burning. Nothing is getting out of them.",
		Needs = { "Points" },
		StartRadius = 60,
		Hold = 3,
		Prompt = "Burn the bus",
		Object = "Fuel can",
		Step = "at each fuel can to burn the buses",
		BurnWave = { Runner = 4, Walker = 3 },
		Boss = {
			At = 0.6,
			Contest = 14,
			Arrive = "The fires woke something in the lead bus. It's coming up the lane.",
			Contested = "It's standing over the last fuel can. Pull it off, then burn the bus.",
			Blocked = "The Warden is at the fuel can: pull him off",
		},
	},

	-- Mile 14's signature side objective: a stuck bus horn (the SilenceAlarm module).
	kill_horn = {
		Kind = "signature",
		Map = "mile14",
		Role = "side",
		Module = "SilenceAlarm",
		Name = "Kill the Horn",
		Brief = "A bus horn near the toll plaza is stuck on, and it is waking the whole jam. Get to the cab and kill it.",
		Why = "The horn is waking the Infected",
		Done = "Horn's dead. The jam goes quiet.",
		Needs = {},
		StartRadius = 0,
		Supply = 150,
		Hold = 4,
		Radius = 140,
		SpawnFactor = 0.4,
		Target = "Horn",
		Prompt = "Kill the horn",
		Object = "Bus cab",
		Step = "at the bus cab to kill the horn",
		-- The siren loop stands in until a horn sound is made (assets/audio/build).
		Noise = { Reach = 200, Every = 6 },
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
	-- Mile 14 v2 (docs/LEVELS.md > Mile 14; level designer 2026-11-20). Frame x +-320, z +-450;
	-- the deck at 12, the span and county road at 26.
	mile14 = {
		Main = {
			{ Id = "burn_buses", Weight = 1.5 },
			{ Id = "secure_site", Weight = 1 },
			{ Id = "restore_comms", Weight = 1 },
			{ Id = "confirm_casualties", Weight = 1 },
			{ Id = "recover_record", Weight = 1 },
		},
		Side = {
			{ Id = "kill_horn", Weight = 1.5 },
			{ Id = "lights_on", Weight = 1 },
			{ Id = "misdrop", Weight = 1 },
			{ Id = "clear_spitters", Weight = 1 },
		},
		Sites = {
			burn_buses = {
				{
					Name = "the jam",
					Position = { 16, 12, -246 },
					-- a fuel can by each sealed bus's door
					Points = { { -11.5, 12.6, -160 }, { 20.5, 12.6, -246 }, { -11.5, 12.6, -366 } },
					BossFrom = { -16, 12, -400 }, -- out of the lead bus
				},
			},
			secure_site = {
				{
					Name = "the Overpass",
					Position = { 0, 26.5, 80 },
					Size = { 28, 1, 28 },
					BossFrom = { -70, 26, 80 },
				},
				{
					Name = "the toll plaza",
					Position = { 0, 12.5, 260 },
					Size = { 46, 1, 46 },
					BossFrom = { -80, 12, 236 },
				},
				{
					Name = "the rest stop",
					Position = { -190, 0.6, -255 },
					Size = { 46, 1, 46 },
					BossFrom = { -70, 0, -320 },
				},
			},
			restore_comms = {
				{ Name = "the water tower", Position = { 225, 8.6, -350 } },
			},
			confirm_casualties = {
				{
					Name = "the weigh station",
					Position = { 150, 0.5, -185 },
					Spawns = {
						{ 80, 0, -180 },
						{ 160, 0, -170 },
						{ 215, 0, -185 },
						{ 240, 0, -140 },
						{ 160, 0, -235 },
						{ 95, 0, -235 },
					},
				},
			},
			recover_record = {
				{
					Name = "the toll office",
					Position = { 154, 12.6, 341 },
					To = { 0, 26.5, 80 },
					ToName = "the Overpass",
				},
			},
			kill_horn = {
				{ Name = "the jam", Position = { 21.5, 13, 168 } },
			},
			lights_on = {
				{ Name = "the weigh station", Position = { 142, 3, -172.8 } },
			},
			misdrop = {
				{ Name = "the Halt", Position = { -200, 0, 250 } },
				{ Name = "the east field", Position = { 230, 0, 10 } },
				{ Name = "the county road", Position = { -250, 26, 80 } },
			},
			clear_spitters = {
				{ Name = "the south barricade", Position = { 0, 12, -425 } },
				{ Name = "the Drop", Position = { -110, 0, -50 } },
			},
		},
	},
}

-- The big map (docs/sprints/DELTA_XL.md, Config.DeltaXL): today's Delta in the middle with
-- eight areas round it. Every site of `delta` is kept; the outer areas add theirs (data only,
-- no new objective types). Coordinates: docs/LEVELS.md > E. Checkpoint Delta XL.
local OUTER: { [string]: { Site } } = {
	secure_site = {
		{ Name = "the truck stop", Position = { 60, 0.8, 735 }, Size = { 46, 1, 46 } },
		{ Name = "the interchange", Position = { 90, 0.5, -640 }, Size = { 46, 1, 46 } },
	},
	restore_comms = {
		{ Name = "the water tower", Position = { 820, 1.2, 772 } },
	},
	confirm_casualties = {
		{
			Name = "the freight wagons",
			Position = { 607, 0.5, -60 },
			-- between the sidings, at the wagons' ends
			Spawns = {
				{ 607, 0, -145 },
				{ 607, 0, -95 },
				{ 607, 0, 5 },
				{ 607, 0, 55 },
				{ 582, 0, -110 },
				{ 582, 0, -20 },
			},
		},
	},
	lights_on = {
		{ Name = "the fuel farm", Position = { 540, 3, -647.6 } },
		{ Name = "the water works", Position = { 720, 3, 652.6 } },
		{ Name = "the camp", Position = { -440, 3, 37.6 } },
	},
	misdrop = {
		{ Name = "the farms", Position = { -780, 0, 580 } },
		{ Name = "the truck stop", Position = { 200, 0, 640 } },
		{ Name = "the water works", Position = { 560, 0, 380 } },
		{ Name = "the camp", Position = { -520, 0, 240 } },
		{ Name = "the rail yard", Position = { 420, 0, -200 } },
		{ Name = "the houses", Position = { -480, 0, -760 } },
		{ Name = "the interchange", Position = { 200, 0, -760 } },
		{ Name = "the fuel farm", Position = { 420, 0, -420 } },
	},
	clear_spitters = {
		{ Name = "the flyover", Position = { -110, 24.2, -560 } },
		{ Name = "the bridge", Position = { -30, 0, 425 } },
		{ Name = "the grain silos", Position = { -470, 0, 760 } },
	},
}

local deltaXL: Map = { Of = "delta", Main = MAPS.delta.Main, Side = MAPS.delta.Side, Sites = {} }
for id, sites in MAPS.delta.Sites do
	deltaXL.Sites[id] = table.clone(sites)
end
for id, sites in OUTER do
	local list = deltaXL.Sites[id] or {}
	table.move(sites, 1, #sites, #list + 1, list)
	deltaXL.Sites[id] = list
end
MAPS.delta_xl = deltaXL

return {
	Rows = ROWS,
	Maps = MAPS,
}
