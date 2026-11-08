-- Data integrity of the definition modules and the parts of Config that name them.
-- Catches typos and broken links between tables before a playtest does.

local Shared = require("./lib/shared")

local function isPositive(value: any): boolean
	return type(value) == "number" and value > 0
end

local function isText(value: any): boolean
	return type(value) == "string" and #value > 0
end

local function isWhole(value: any): boolean
	return isPositive(value) and value % 1 == 0
end

local function checkEnemies(t, EnemyDefinitions)
	local attacks = { melee = true, projectile = true, boss = true }
	for kind, def in EnemyDefinitions do
		local at = `EnemyDefinitions.{kind}`
		t.check(isText(def.DisplayName), `{at}.DisplayName is empty`)
		t.check(isPositive(def.Scale), `{at}.Scale must be > 0`)
		t.check(isPositive(def.MaxHealth), `{at}.MaxHealth must be > 0`)
		t.check(isPositive(def.WalkSpeed), `{at}.WalkSpeed must be > 0`)
		t.check(type(def.Damage) == "number" and def.Damage >= 0, `{at}.Damage must be >= 0`)
		t.check(isPositive(def.AttackRange), `{at}.AttackRange must be > 0`)
		t.check(isPositive(def.AttackCooldown), `{at}.AttackCooldown must be > 0`)
		t.check(type(def.SupplyValue) == "number", `{at}.SupplyValue is missing`)

		local behaviour = def.Behaviour or {}
		t.check(attacks[behaviour.Attack] == true, `{at}.Behaviour.Attack is not a known attack`)
		if behaviour.Attack == "projectile" then
			local projectile = behaviour.Projectile or {}
			t.check(isPositive(projectile.Speed), `{at} lobs a projectile with no Speed`)
		end

		local first = def.FirstSpawnTime
		if def.Boss then
			t.check(first == math.huge, `{at} is a Boss but the director could spawn it`)
		else
			local finite = type(first) == "number" and first >= 0 and first < math.huge
			t.check(finite, `{at}.FirstSpawnTime must be a finite number of seconds`)
		end
	end
end

-- Every Config table keyed by Infected form names a real, non-boss form.
local FORM_KEYED = { Weights = true, Caps = true, MaxShare = true, CapSchedule = true }
FORM_KEYED.CapLate = true

local function checkFormKeys(t, Config, EnemyDefinitions)
	local seen = {}
	local function walk(node: any, path: string)
		if type(node) ~= "table" or seen[node] then
			return
		end
		seen[node] = true
		for key, value in node do
			local here = `{path}.{tostring(key)}`
			if FORM_KEYED[key] and type(value) == "table" then
				for form in value do
					local def = EnemyDefinitions[form]
					t.check(def ~= nil, `{here} names unknown form "{tostring(form)}"`)
					t.check(not (def and def.Boss), `{here} names boss "{tostring(form)}"`)
				end
			end
			walk(value, here)
		end
	end
	walk(Config, "Config")

	local phases = Config.Spawning.Phases
	local previous = -math.huge
	for index, phase in phases do
		local at = `Config.Spawning.Phases[{index}]`
		t.check(phase.Until > previous, `{at}.Until must be later than the phase before`)
		previous = phase.Until
		for form, weight in phase.Weights do
			t.check(isPositive(weight), `{at}.Weights.{form} must be > 0`)
		end
	end
	t.check(phases[#phases].Until == math.huge, "the last spawn phase must run forever")
end

local function checkWeapons(t, WeaponDefinitions)
	local default = WeaponDefinitions.DEFAULT
	t.check(WeaponDefinitions.exists(default), "WeaponDefinitions.DEFAULT has no row")
	for id, row in WeaponDefinitions.Rows do
		local at = `WeaponDefinitions.{id}`
		t.check(row.Id == id, `{at}.Id must equal its key`)
		t.check(isText(row.Name), `{at}.Name is empty`)
		t.check(isPositive(row.Damage), `{at}.Damage must be > 0`)
		t.check(isPositive(row.FireCooldown), `{at}.FireCooldown must be > 0`)
		t.check(isWhole(row.MagazineSize), `{at}.MagazineSize must be a whole number > 0`)
		t.check(isPositive(row.ReloadTime), `{at}.ReloadTime must be > 0`)
		t.check(row.ReserveStart <= row.ReserveMax, `{at}.ReserveStart exceeds ReserveMax`)
		t.check(row.AdsSpread <= row.HipSpread, `{at}.AdsSpread is wider than HipSpread`)
		t.check(isPositive(row.Range), `{at}.Range must be > 0`)
		t.check(isPositive(row.HeadshotMultiplier), `{at}.HeadshotMultiplier must be > 0`)
	end
end

local function checkCallIns(t, Config, CallInDefinitions)
	local kinds = { throw = true, self = true }
	local rows = CallInDefinitions.Rows
	local ordered: { [string]: number } = {}
	for _, id in CallInDefinitions.Order do
		ordered[id] = (ordered[id] or 0) + 1
		t.check(rows[id] ~= nil, `CallInDefinitions.Order names unknown call-in "{id}"`)
	end
	for _, id in CallInDefinitions.DEFAULT do
		t.check(rows[id] ~= nil, `CallInDefinitions.DEFAULT names unknown call-in "{id}"`)
	end
	for id, row in rows do
		local at = `CallInDefinitions.{id}`
		t.check(row.Id == id, `{at}.Id must equal its key`)
		t.check(isText(row.Name), `{at}.Name is empty`)
		t.check(isText(row.Abbrev), `{at}.Abbrev is empty`)
		t.check(kinds[row.Kind] == true, `{at}.Kind must be throw or self`)
		t.check(Config.CallIns[row.ConfigKey] ~= nil, `{at}.ConfigKey has no Config.CallIns entry`)
		t.check(ordered[id] == 1, `{at} must appear exactly once in CallInDefinitions.Order`)
	end
end

local function checkCards(t, UpgradeDefinitions, CallInDefinitions)
	local slots = { Dash = true, Breach = true, Rifle = true, Kit = true, CallIn = true }
	local upgrades = {}
	for id, row in UpgradeDefinitions.Rows do
		local at = `UpgradeDefinitions.{id}`
		t.check(row.Id == id, `{at}.Id must equal its key`)
		t.check(isText(row.Name), `{at}.Name is empty`)
		t.check(isText(row.Description), `{at}.Description is empty`)
		t.check(isText(row.Abbrev), `{at}.Abbrev is empty`)
		if row.Kind == "upgrade" then
			table.insert(upgrades, id)
			t.check(slots[row.Slot] == true, `{at}.Slot is not a known slot`)
			if row.Slot == "CallIn" then
				local rides = CallInDefinitions.Rows[row.CallIn] ~= nil
				t.check(rides, `{at} rides on unknown call-in "{tostring(row.CallIn)}"`)
			else
				t.check(row.CallIn == nil, `{at}.CallIn is set but its Slot is not CallIn`)
			end
		else
			t.check(row.Kind == "supply", `{at}.Kind must be supply or upgrade`)
			t.check(row.Slot == nil, `{at} is a supply card but has a Slot`)
		end
	end
	table.sort(upgrades)
	local listed = table.concat(UpgradeDefinitions.upgradeIds(), ",")
	t.check(listed == table.concat(upgrades, ","), "upgradeIds() does not match the upgrade rows")
end

return function(t)
	local Config = Shared.require("Config")
	local EnemyDefinitions = Shared.require("EnemyDefinitions")
	local CallInDefinitions = Shared.require("CallInDefinitions")

	checkEnemies(t, EnemyDefinitions)
	checkFormKeys(t, Config, EnemyDefinitions)
	checkWeapons(t, Shared.require("WeaponDefinitions"))
	checkCallIns(t, Config, CallInDefinitions)
	checkCards(t, Shared.require("UpgradeDefinitions"), CallInDefinitions)
end
