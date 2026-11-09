--!strict
-- Enemy archetype stats and behaviour (extended for the Infected
-- roster in docs/PROGRESSION.md). All enemy tuning lives here; EnemyService reads the
-- Behaviour table and has no per-type branches. The curve is flat (Config.Difficulty is
-- 1x since the the loadout rework); spawn weights and caps from Config.Spawning.
-- Health and damage sit on the realistic time-to-kill in Config.Weapon (rifle 20, head x3):
-- Walker 3 body / 1 head, Runner 2 / 1, Hocker 4 / 2, Brute 13 / 11.

export type PuddleSpec = {
	Radius: number,
	Duration: number, -- seconds
	DamagePerSecond: number,
}

export type ProjectileSpec = {
	Speed: number, -- flat studs/s; sets the flight time of the lob
	Size: number,
	Color: Color3,
	SplashRadius: number, -- studs around the impact that take Damage
	Lead: number, -- fraction of the target's velocity * flight time added to the aim
	Puddle: PuddleSpec?,
}

export type Behaviour = {
	Attack: "melee" | "projectile" | "boss", -- boss: steered by IndexService, not the chase loop
	StandOff: number?, -- projectile: stop approaching inside this distance
	Windup: number?, -- seconds the attack pose plays before the hit lands
	Projectile: ProjectileSpec?,
}

export type EnemyDefinition = {
	DisplayName: string,
	Scale: number,
	MaxHealth: number,
	WalkSpeed: number,
	Damage: number, -- per melee hit or per projectile impact
	AttackRange: number, -- studs between root parts (projectile: max throw)
	AttackCooldown: number, -- seconds between hits
	SupplyValue: number, -- credited to the squad's Resupply pool on death (any distance)
	SpawnCost: number, -- reserved for a budget director later
	FirstSpawnTime: number, -- seconds of run time before it may spawn
	Color: Color3,
	Behaviour: Behaviour,
	HeadshotMultiplier: number?, -- overrides Config.Weapon.HeadshotMultiplier (plated skulls)
	BodySet: string?, -- limb set to wear (assets/3d inf_<set>_*); defaults to the type name
	ThroatSac: boolean?, -- Hocker: a sac on the neck that swells during the windup
	-- Tallest cover top (studs above the feet) this form climbs when it is pressed against
	-- it (EnemyService; Config.Movement.Infected). nil = never climbs.
	ClimbHeight: number?,
	Boss: boolean?, -- an Index host: spawned by IndexService, never by the director
}

local MELEE: Behaviour = { Attack = "melee" }

local EnemyDefinitions: { [string]: EnemyDefinition } = {
	Walker = {
		DisplayName = "Walker",
		Scale = 1,
		MaxHealth = 55,
		WalkSpeed = 9.5,
		Damage = 10,
		AttackRange = 4,
		AttackCooldown = 1.1,
		SupplyValue = 10,
		SpawnCost = 1,
		FirstSpawnTime = 0,
		Color = Color3.fromRGB(88, 154, 84),
		Behaviour = MELEE,
		ClimbHeight = 5, -- jersey, hesco; not the bunker
	},
	Runner = {
		DisplayName = "Runner",
		Scale = 0.9,
		MaxHealth = 35,
		WalkSpeed = 17,
		Damage = 8,
		AttackRange = 3.5,
		AttackCooldown = 0.85,
		SupplyValue = 12,
		SpawnCost = 1.5,
		FirstSpawnTime = 75,
		Color = Color3.fromRGB(168, 146, 66),
		Behaviour = MELEE,
		ClimbHeight = 10.5, -- everything but T-walls and buses
	},
	Brute = {
		DisplayName = "Brute",
		Scale = 2,
		MaxHealth = 260,
		WalkSpeed = 6.5,
		Damage = 30,
		AttackRange = 5.5,
		AttackCooldown = 1.6,
		SupplyValue = 35,
		SpawnCost = 5,
		FirstSpawnTime = 180,
		Color = Color3.fromRGB(52, 88, 50),
		Behaviour = MELEE,
		HeadshotMultiplier = 1.25, -- bone overgrowth: the head is barely a weak point
	},
	-- Ranged: plants, rears back, lobs caustic fluid that leaves a puddle. The one rule:
	-- a Hocker that stops moving is about to spit. Numbers: systems designer.
	Hocker = {
		DisplayName = "Hocker",
		Scale = 1,
		MaxHealth = 75,
		WalkSpeed = 8,
		Damage = 15,
		AttackRange = 55,
		AttackCooldown = 3.0,
		SupplyValue = 18,
		SpawnCost = 2.5,
		FirstSpawnTime = 480,
		Color = Color3.fromRGB(176, 170, 84),
		Behaviour = {
			Attack = "projectile",
			StandOff = 40,
			Windup = 0.8,
			Projectile = {
				Speed = 45,
				Size = 1.4,
				Color = Color3.fromRGB(190, 215, 60),
				SplashRadius = 4,
				Lead = 0.5,
				Puddle = { Radius = 6, Duration = 4, DamagePerSecond = 8 },
			},
		},
		ThroatSac = true,
	},
	-- The Index (Delta): the Warden, armoured (Config.Index.Warden: plates, kit, phases).
	-- IndexService steers him; the director never picks him (FirstSpawnTime huge, Boss).
	Warden = {
		DisplayName = "The Warden",
		Scale = 1.9,
		MaxHealth = 7000,
		WalkSpeed = 8,
		Damage = 40, -- Shield Bash; the other attacks carry their own damage in Config.Index
		AttackRange = 8,
		AttackCooldown = 3,
		SupplyValue = 400,
		SpawnCost = 0,
		FirstSpawnTime = math.huge,
		Color = Color3.fromRGB(58, 60, 56),
		Behaviour = { Attack = "boss" },
		HeadshotMultiplier = 2, -- once the helmet is off (the shell takes the hits until then)
		Boss = true,
	},
}

return EnemyDefinitions
