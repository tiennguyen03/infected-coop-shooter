--!strict
-- Enemy archetype stats and behaviour (Sprint 9, extended 2026-11-06 for the Infected
-- roster in docs/PROGRESSION.md). All enemy tuning lives here; EnemyService reads the
-- Behaviour table and has no per-type branches. Time-based health/damage scaling comes from
-- Config.Difficulty on top of these; spawn weights and caps from Config.Spawning.

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
	Attack: "melee" | "projectile",
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
	XPReward: number,
	SpawnCost: number, -- reserved for a budget director later
	FirstSpawnTime: number, -- seconds of run time before it may spawn
	Color: Color3,
	Behaviour: Behaviour,
	BodySet: string?, -- limb set to wear (assets/3d inf_<set>_*); defaults to the type name
	ThroatSac: boolean?, -- Hocker: a sac on the neck that swells during the windup
}

local MELEE: Behaviour = { Attack = "melee" }

local EnemyDefinitions: { [string]: EnemyDefinition } = {
	Walker = {
		DisplayName = "Walker",
		Scale = 1,
		MaxHealth = 35,
		WalkSpeed = 9.5,
		Damage = 8,
		AttackRange = 4,
		AttackCooldown = 1.1,
		XPReward = 10,
		SpawnCost = 1,
		FirstSpawnTime = 0,
		Color = Color3.fromRGB(88, 154, 84),
		Behaviour = MELEE,
	},
	Runner = {
		DisplayName = "Runner",
		Scale = 0.9,
		MaxHealth = 22,
		WalkSpeed = 17,
		Damage = 6,
		AttackRange = 3.5,
		AttackCooldown = 0.85,
		XPReward = 12,
		SpawnCost = 1.5,
		FirstSpawnTime = 75,
		Color = Color3.fromRGB(168, 146, 66),
		Behaviour = MELEE,
	},
	Brute = {
		DisplayName = "Brute",
		Scale = 2,
		MaxHealth = 160,
		WalkSpeed = 6.5,
		Damage = 22,
		AttackRange = 5.5,
		AttackCooldown = 1.6,
		XPReward = 35,
		SpawnCost = 5,
		FirstSpawnTime = 180,
		Color = Color3.fromRGB(52, 88, 50),
		Behaviour = MELEE,
	},
	-- Ranged: plants, rears back, lobs caustic fluid that leaves a puddle. The one rule:
	-- a Hocker that stops moving is about to spit. Numbers: systems designer 2026-11-06.
	Hocker = {
		DisplayName = "Hocker",
		Scale = 1,
		MaxHealth = 45,
		WalkSpeed = 8,
		Damage = 12,
		AttackRange = 55,
		AttackCooldown = 3.0,
		XPReward = 18,
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
				Puddle = { Radius = 6, Duration = 4, DamagePerSecond = 6 },
			},
		},
		BodySet = "Walker", -- own limb set is backlog (assets/3d)
		ThroatSac = true,
	},
}

return EnemyDefinitions
