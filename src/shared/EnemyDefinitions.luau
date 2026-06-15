--!strict
-- Enemy archetype stats (Sprint 9). All enemy tuning lives here — nothing
-- about a specific enemy type is hardcoded in EnemyService. Time-based
-- health/damage scaling comes from Config.Difficulty on top of these.

export type EnemyDefinition = {
	DisplayName: string,
	Scale: number,
	MaxHealth: number,
	WalkSpeed: number,
	Damage: number,
	AttackRange: number, -- studs between root parts
	AttackCooldown: number, -- seconds between hits
	XPReward: number,
	SpawnCost: number, -- reserved for a budget director later
	FirstSpawnTime: number, -- seconds of run time before it may spawn
	Color: Color3,
}

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
	},
}

return EnemyDefinitions
