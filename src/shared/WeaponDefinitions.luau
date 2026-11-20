--!strict
-- Guns and grenades as data (docs/PROGRESSION.md > Loadout). One row per gun; every number
-- comes from Config.Weapons.<ConfigKey> so tuning stays in Config. A soldier carries one
-- primary and one secondary (Slot), each with its own magazine and reserve on the server
-- (LoadoutService); ProjectileServer fires by the active row, BotService by the rifle's.
-- The Arms Room (LoadoutMenu, Rules/Loadout) lists PRIMARIES, SECONDARIES and GRENADES.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sight = require(ReplicatedStorage.Shared.Rules.Sight)
local KeyBindings = require(ReplicatedStorage.Shared.Rules.KeyBindings)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Optics = require(ReplicatedStorage.Shared.Attachments.Optics)
local AttachmentMerge = require(ReplicatedStorage.Shared.Rules.AttachmentMerge)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local Scarcity = require(ReplicatedStorage.Shared.Rules.Scarcity)
local AttachmentUnlock = require(ReplicatedStorage.Shared.Rules.AttachmentUnlock)
local AmmoTypes = require(ReplicatedStorage.Shared.Attachments.AmmoTypes)
local AttachmentOptions = require(ReplicatedStorage.Shared.Attachments.Options)
local Schema = require(ReplicatedStorage.Shared.Attachments.Schema)

local SCARCE_AMMO = Config.Scarcity.Enabled and Config.Scarcity.Ammo.Enabled

-- A row's sight points are written on the gun's design (guns.py); the eye lines up where
-- they show on the uploaded mesh, which Roblox mirrors left-right (MeshAssets.shownPoint).
local function shown(model: string, sight: Sight.Resolved): Sight.Resolved
	local out = table.clone(sight)
	out.Rear = MeshAssets.shownPoint(model, sight.Rear)
	out.Front = MeshAssets.shownPoint(model, sight.Front)
	return out
end

export type WeaponSlot = "primary" | "secondary"
export type FireMode = "auto" | "semi"
-- Per-shot camera kick: Pitch degrees up, a random +/- Yaw degrees, eased back over Recover s.
export type WeaponKick = { Pitch: number, Yaw: number, Recover: number }
-- The Barrel's suppressor (Config.Attachments): its quiet reach and its size on the muzzle.
export type Suppressor = { Noise: number, Length: number, Width: number }

-- Overpenetration (Rules/Overpen; the Fifty): bodies hit at most, the share off per body,
-- the thickest wall passed (studs), a squadmate's share, and whether it breaks the Brute's
-- plated front.
export type Overpen = {
	Bodies: number,
	Falloff: number,
	WallThickness: number,
	FriendlyFire: number,
	BreaksArmour: boolean,
}

export type WeaponDefinition = {
	Id: string,
	Name: string, -- HUD name
	Designation: string, -- the real gun
	Description: string, -- one line for the Arms Room
	Slot: WeaponSlot,
	FireMode: FireMode, -- "semi": one round per click
	Damage: number, -- per round (per pellet when Pellets is set)
	FireCooldown: number, -- seconds between shots
	MagazineSize: number,
	ReloadTime: number, -- seconds
	ReserveStart: number, -- rounds in reserve at insert
	ReserveMax: number,
	HipSpread: number, -- degrees, half-angle
	AdsSpread: number,
	BloomPerShot: number, -- degrees added to the cone per round
	BloomMax: number,
	BloomRecovery: number, -- degrees per second once the trigger rests
	AdsMoveFactor: number, -- walk speed multiplier while aiming
	Range: number, -- studs the hitscan ray reaches
	HeadshotMultiplier: number, -- on a Head hit (EnemyDefinitions may override per form)
	Pellets: number?, -- rounds per trigger pull (shotguns); nil = 1
	Pierce: number?, -- Infected a round passes through after the first; nil = 0
	Overpen: Overpen?, -- the round carries on through bodies and thin walls (Rules/Overpen)
	CarryMoveFactor: number, -- walk speed multiplier while it is in hand (1 = none)
	CanSprint: boolean, -- false: too heavy to sprint with
	Kick: WeaponKick, -- per-shot camera kick (CameraController)
	Heavy: boolean, -- staggers a Brute (Config.Enemies.Flinch)
	ReloadClip: string?, -- its own reload clip; nil = Config.Animations.Assault.reload
	Model: string, -- the held mesh (MeshAssets wpn_*); default wpn_rifle
	Price: number?, -- merits at the lobby's Quartermaster (Rules/Record): 0 = issued free, nil = not for sale
	Desk: string?, -- the Carrier desk that sells it (LobbyDesks id); nil = Config.Lobby.Sellers.Gun
	Sound: string?, -- its clips in the `guns` bank: <Sound>_shot, <Sound>_reload; nil = the shared rifle shot and gear reload
	Explosive: Explosive?, -- a launcher: the round is a visible rocket that blows at impact
	ProjectileSpeed: number?, -- studs/s of that rocket (Explosive only)
	ArmsOrder: number, -- its place in the Arms Room within its slot (lower first; default 100)
	Noise: number, -- studs a shot carries to the Infected (Config.Awareness; default DefaultNoise)
	Suppressor: Suppressor?, -- it takes one on the Barrel; nil = it cannot
	-- Attachment system v2 (Config.AttachmentsV2; WeaponDefinitions.fitted): its slots by
	-- family (nil: the one-slot fitting), its ammo by caliber. A fitted definition carries the
	-- merged stats in the fields above and in these (as issued: 1, 1, 0, "standard", false).
	Family: string?,
	Caliber: string?,
	AdsTimeFactor: number, -- on the time into the sights (CameraController)
	ArmourPenetration: number, -- 0..1 of a plate's reduction ignored (DamageService)
	AmmoBehaviour: string, -- the round's behaviour (AmmoTypes)
	BreachPower: number, -- a breaching round's push on a wall per hit (Rules/WallBreach; 1)
	Burn: AttachmentMerge.Burn?, -- an incendiary round's burn per hit (Rules/DoT; nil: none)
	Merged: boolean, -- true: built by fitted(); Noise already holds the quiet barrel's reach
	-- Its sights in first person (Rules/Sight): the two points on the mesh the eye lines up,
	-- irons or a scope, the eye relief, the zoom and the hip hold, defaults filled in.
	Sight: Sight.Resolved,
}

-- A launcher's blast at the impact point (the frag's blast, KitService.blast). SelfDamage is
-- the share of Damage a soldier inside Radius takes (0 = none).
export type Explosive = {
	Radius: number,
	Damage: number,
	ShakePower: number?,
	SelfDamage: number?,
}

export type GrenadeDefinition = {
	Id: string,
	Name: string,
	Designation: string,
	Description: string,
	ConfigKey: string, -- Config.Grenade[ConfigKey]
	Model: string?, -- its mesh on the Loadout screen (MeshAssets); nil = a stand-in grenade
}

type Tuning = {
	FireMode: string,
	Damage: number,
	FireCooldown: number,
	MagazineSize: number,
	ReloadTime: number,
	ReserveStart: number,
	ReserveMax: number,
	Scarce: { ReserveStart: number, ReserveMax: number }?, -- Config.Scarcity.Ammo
	HipSpread: number,
	AdsSpread: number,
	BloomPerShot: number,
	BloomMax: number,
	BloomRecovery: number,
	AdsMoveFactor: number,
	Range: number,
	HeadshotMultiplier: number,
	Pellets: number?,
	Pierce: number?,
	Overpen: Overpen?,
	CarryMoveFactor: number?,
	CanSprint: boolean?,
	Kick: WeaponKick,
	Heavy: boolean?,
	ReloadClip: string?,
	Model: string?,
	Price: number?,
	Desk: string?,
	Sound: string?,
	Explosive: Explosive?,
	ProjectileSpeed: number?,
	ArmsOrder: number?,
	Noise: number?,
	Suppressor: Suppressor?,
	Sight: Sight.Raw?,
	Family: string?,
	Caliber: string?,
}

local DEFAULT_ARMS_ORDER = 100
local DEFAULT_MODEL = "wpn_rifle"
-- A row that names no sight (tests/Sight.spec.luau fails it): along the top of wpn_rifle.
local DEFAULT_SIGHT: Sight.Raw =
	{ Rear = Vector3.new(0, 0.62, 0), Front = Vector3.new(0, 0.62, -1.4) }

local function row(
	id: string,
	slot: WeaponSlot,
	name: string,
	designation: string,
	description: string,
	tuning: Tuning
): WeaponDefinition
	-- Spare rounds: the row's Scarce block while Config.Scarcity.Ammo is on (Rules/Scarcity).
	local reserveStart, reserveMax = Scarcity.reserve(tuning, SCARCE_AMMO)
	return {
		Id = id,
		Name = name,
		Designation = designation,
		Description = description,
		Slot = slot,
		FireMode = if tuning.FireMode == "semi" then "semi" else "auto",
		Damage = tuning.Damage,
		FireCooldown = tuning.FireCooldown,
		MagazineSize = tuning.MagazineSize,
		ReloadTime = tuning.ReloadTime,
		ReserveStart = reserveStart,
		ReserveMax = reserveMax,
		HipSpread = tuning.HipSpread,
		AdsSpread = tuning.AdsSpread,
		BloomPerShot = tuning.BloomPerShot,
		BloomMax = tuning.BloomMax,
		BloomRecovery = tuning.BloomRecovery,
		AdsMoveFactor = tuning.AdsMoveFactor,
		Range = tuning.Range,
		HeadshotMultiplier = tuning.HeadshotMultiplier,
		Pellets = tuning.Pellets,
		Pierce = tuning.Pierce,
		Overpen = tuning.Overpen,
		CarryMoveFactor = tuning.CarryMoveFactor or 1,
		CanSprint = tuning.CanSprint ~= false,
		Kick = tuning.Kick,
		Heavy = tuning.Heavy == true,
		ReloadClip = tuning.ReloadClip,
		Model = tuning.Model or DEFAULT_MODEL,
		Price = tuning.Price,
		Desk = tuning.Desk,
		Sound = tuning.Sound,
		Explosive = tuning.Explosive,
		ProjectileSpeed = tuning.ProjectileSpeed,
		ArmsOrder = tuning.ArmsOrder or DEFAULT_ARMS_ORDER,
		Noise = tuning.Noise or Config.Awareness.DefaultNoise,
		Suppressor = tuning.Suppressor,
		Family = tuning.Family,
		Caliber = tuning.Caliber,
		AdsTimeFactor = 1,
		ArmourPenetration = 0,
		AmmoBehaviour = "standard",
		BreachPower = 1,
		Burn = nil,
		Merged = false,
		Sight = shown(
			tuning.Model or DEFAULT_MODEL,
			Sight.resolve(tuning.Sight or DEFAULT_SIGHT, Config.Weapon.Sights)
		),
	}
end

local W = (Config.Weapons :: any) :: { [string]: Tuning }

local WeaponDefinitions = {}

local ROWS: { [string]: WeaponDefinition } = {
	service_rifle = row(
		"service_rifle",
		"primary",
		"Service Rifle",
		"M16A4",
		"The all-rounder. Fire in short bursts: a held trigger sprays at range.",
		W.ServiceRifle
	),
	smg = row(
		"smg",
		"primary",
		"SMG",
		"MP5",
		"Best from the hip. Chews through Runners, struggles on Brutes.",
		W.Smg
	),
	lmg = row(
		"lmg",
		"primary",
		"LMG",
		"M249",
		"A 100-round belt: no reload inside a hold. Slow to aim on the move.",
		W.Lmg
	),
	shotgun = row(
		"shotgun",
		"primary",
		"Shotgun",
		"Mossberg 590",
		"Point-blank, one pump per shot. Drops anything but a Brute in one pull.",
		W.Shotgun
	),
	dmr = row(
		"dmr",
		"primary",
		"DMR",
		"M110",
		"One round per Walker, through two in a line. Poor up close, short on ammo.",
		W.Dmr
	),
	pistol = row(
		"pistol",
		"secondary",
		"Pistol",
		"M17",
		"The sidearm. Q to draw it when the long gun runs dry.",
		W.Pistol
	), -- Sample guns (2026-11-09), in the Arms Room like the rest.
	revolver = row(
		"revolver",
		"secondary",
		"Revolver",
		"S&W 686",
		"Six rounds of .357. One per Walker, and it rocks a Brute. Slow to reload.",
		W.Revolver
	),
	sniper = row(
		"sniper",
		"primary",
		"Sniper Rifle",
		"M2010 ESR",
		"One round, one kill, through four in a line. Two for a Brute. Work the bolt.",
		W.Sniper
	),
	fifty = row(
		"fifty",
		"primary",
		"Fifty",
		"Barrett M82A1",
		".50 BMG: through four in a line, walls and squadmates too. Heavy, loud, no sprint.",
		W.Fifty
	),
	goose = row(
		"goose",
		"primary",
		"Goose",
		"M3 recoilless rifle",
		"Two rockets. A direct hit kills a Brute; the blast clears a pack.",
		W.Goose
	),
}

local GRENADES: { [string]: GrenadeDefinition } = {
	frag = {
		Id = "frag",
		Name = "Frag",
		Designation = "M67",
		Description = `Hold {KeyBindings.label(Config.Keys.Grenade.Name)} to aim, release to throw. Kills a Hocker, not a Brute.`,
		ConfigKey = "Frag",
	},
}

WeaponDefinitions.DEFAULT = "service_rifle"
WeaponDefinitions.DEFAULT_SECONDARY = "pistol"
WeaponDefinitions.DEFAULT_GRENADE = "frag"
WeaponDefinitions.Rows = ROWS
WeaponDefinitions.Grenades = GRENADES
-- The Arms Room lists, built from the rows: every gun of the slot, by its ArmsOrder (then id).
-- The first of each is the default. A new gun appears by having a row.
local function slotList(slot: WeaponSlot): { string }
	local ids = {}
	for id, weapon in ROWS do
		if weapon.Slot == slot then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local oa, ob = ROWS[a].ArmsOrder, ROWS[b].ArmsOrder
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	return ids
end
WeaponDefinitions.PRIMARIES = slotList("primary")
WeaponDefinitions.SECONDARIES = slotList("secondary")
WeaponDefinitions.GRENADES = { "frag" }

-- Every gun id, sorted (the dev panel lists them all, Arms Room or not).
function WeaponDefinitions.allIds(): { string }
	local ids = {}
	for id in ROWS do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- The row for `id`, or the default rifle when the id is unknown (never nil).
function WeaponDefinitions.get(id: string?): WeaponDefinition
	return (id and ROWS[id]) or ROWS[WeaponDefinitions.DEFAULT]
end

function WeaponDefinitions.exists(id: string): boolean
	return ROWS[id] ~= nil
end

function WeaponDefinitions.grenade(id: string?): GrenadeDefinition
	return (id and GRENADES[id]) or GRENADES[WeaponDefinitions.DEFAULT_GRENADE]
end

-- What gun `id` can take: [slot] = its options (Config.Attachments, Config.Optics), empty
-- when nothing.
function WeaponDefinitions.options(id: string): { [string]: { string } }
	local options: { [string]: { string } } = {}
	local gun = ROWS[id]
	-- A v2 gun: every slot it takes, with every option but the issued part (an empty slot
	-- holds that one).
	if gun and gun.Family then
		local catalog = WeaponDefinitions.attachmentCatalog()
		for _, slot in WeaponDefinitions.slots(id) do
			local ids: { string } = {}
			for _, optionId in AttachmentUnlock.idsIn(catalog, id, slot.id) do
				local entry = AttachmentOptions.get(optionId) or AmmoTypes.get(optionId)
				if entry and not entry.base then
					table.insert(ids, optionId)
				end
			end
			if #ids > 0 then
				options[slot.id] = ids
			end
		end
		return options
	end
	if gun and gun.Suppressor then
		options.Barrel = { "suppressor" }
	end
	-- Optics: each Config.Optics row that lists this gun (only the M16A4 so far).
	local optics = Optics.idsFor(id)
	if gun and #optics > 0 then
		options[Optics.SLOT] = optics
	end
	return options
end

-- The optic on gun `id` in a soldier's Fitted attribute text (Loadout.encodeFitted), or nil.
function WeaponDefinitions.opticIn(fittedText: unknown, id: string): string?
	if typeof(fittedText) ~= "string" or fittedText == "" then
		return nil
	end
	return Loadout.fitted(Loadout.decodeFitted(fittedText), id, Optics.SLOT)
end

-- The Showcase id of gun `id` with optic `opticId` on ("service_rifle+acog").
function WeaponDefinitions.dressedId(id: string, opticId: string): string
	return `{id}+{opticId}`
end

-- Gun `id` as it is carried with optic `opticId` on (nil: none): its mesh and its sight on
-- that mesh, the zoom scaled by the optic (Rules/AttachmentMerge). The bare gun's own when the
-- optic does not fit it or its mesh is not uploaded. Kept per gun and optic (the camera asks
-- every frame).
local dressedCache: { [string]: { model: string, sight: Sight.Resolved } } = {}
function WeaponDefinitions.dressed(id: string?, opticId: string?): (string, Sight.Resolved)
	local weapon = WeaponDefinitions.get(id)
	if not opticId then
		return weapon.Model, weapon.Sight
	end
	local key = WeaponDefinitions.dressedId(weapon.Id, opticId)
	local cached = dressedCache[key]
	if not cached then
		local optic = Optics.get(opticId)
		local fit = Optics.fit(opticId, weapon.Id)
		if not optic or not fit or not MeshAssets.isUploaded(fit.model) then
			cached = { model = weapon.Model, sight = weapon.Sight }
		else
			local zoom =
				AttachmentMerge.apply({ zoom = weapon.Sight.Zoom, adsTime = 1 }, { optic }).zoom
			local raw: Sight.Raw = {
				Rear = fit.sight.Rear,
				Front = fit.sight.Front,
				Kind = fit.sight.Kind,
				Hold = weapon.Sight.Hold,
				Zoom = zoom,
			}
			cached = {
				model = fit.model,
				sight = shown(fit.model, Sight.resolve(raw, Config.Weapon.Sights)),
			}
		end
		dressedCache[key] = cached
	end
	return cached.model, cached.sight
end

-- How far a shot from `weapon` carries with `barrel` fitted (nil = bare).
function WeaponDefinitions.shotNoise(weapon: WeaponDefinition, barrel: string?): number
	if weapon.Merged then
		return weapon.Noise -- fitted(): the barrel, muzzle and ammo already in it
	end
	if barrel == "suppressor" and weapon.Suppressor then
		return weapon.Suppressor.Noise
	end
	return weapon.Noise
end

----------------------------------------------------------------------
-- Attachment system v2 (Config.AttachmentsV2; Nova 2026-11-20)
----------------------------------------------------------------------

-- What Rules/AttachmentUnlock checks against: every option and ammo type, and each gun's
-- caliber. Built once.
local catalog: AttachmentUnlock.Catalog? = nil
function WeaponDefinitions.attachmentCatalog(): AttachmentUnlock.Catalog
	local built = catalog
	if built then
		return built
	end
	local made: AttachmentUnlock.Catalog = {
		options = table.clone(AttachmentOptions.Rows) :: any,
		ammo = table.clone(AmmoTypes.Rows) :: any,
		gunCaliber = function(gunId: string): string?
			local gun = ROWS[gunId]
			return gun and gun.Caliber
		end,
	}
	catalog = made
	return made
end

-- The v2 slots gun `id` takes (its Family's, with at least one option for it), in menu order;
-- empty for a gun still on the one-slot fitting.
function WeaponDefinitions.slots(id: string): { Schema.Slot }
	local gun = ROWS[id]
	local list: { Schema.Slot } = {}
	if not gun or not gun.Family then
		return list
	end
	local all = WeaponDefinitions.attachmentCatalog()
	for _, slot in Schema.forFamily(gun.Family) do
		if #AttachmentUnlock.idsIn(all, id, slot.id) > 0 then
			table.insert(list, slot)
		end
	end
	return list
end

local fittedCache: { [string]: WeaponDefinition } = {}

-- Gun `id` as `attachments` fit it (Loadout.attachments: [gun][slot] = option or ammo id): its
-- row with the merged stats (Rules/AttachmentMerge.merge) for a v2 gun, the row itself for any
-- other gun, no fitting, or a fitting the rule refuses (the server never signs one). The server
-- fires, reloads and makes noise with this; the client reads it for its camera and walk only.
function WeaponDefinitions.fitted(id: string?, attachments: Loadout.Attachments?): WeaponDefinition
	local weapon = WeaponDefinitions.get(id)
	local slots = attachments and attachments[weapon.Id]
	if not weapon.Family or not slots or next(slots) == nil then
		return weapon
	end
	local names: { string } = {}
	for slot, option in slots do
		table.insert(names, `{slot}={option}`)
	end
	table.sort(names)
	local key = `{weapon.Id}|{table.concat(names, ";")}`
	local cached = fittedCache[key]
	if cached then
		return cached
	end
	local equipped: { [string]: AttachmentMerge.Option } = {}
	local ammo: AttachmentMerge.Ammo? = nil
	for slot, optionId in slots do
		if slot == AmmoTypes.SLOT then
			ammo = AmmoTypes.get(optionId)
		else
			local option = AttachmentOptions.get(optionId)
			if option then
				equipped[slot] = option
			end
		end
	end
	local stats = AttachmentMerge.merge({
		id = weapon.Id,
		caliber = weapon.Caliber,
		-- The suppressed barrel's quiet reach replaces the gun's (shotNoise, as before).
		stats = AttachmentMerge.gunStats(
			weapon,
			if slots.Barrel == "suppressor" and weapon.Suppressor
				then weapon.Suppressor.Noise
				else nil
		),
	}, equipped, ammo)
	if not stats then
		fittedCache[key] = weapon
		return weapon
	end
	local out = table.clone(weapon)
	out.Damage = stats.damage
	out.Pellets = if stats.projectileCount > 1 then stats.projectileCount else nil
	out.HeadshotMultiplier = stats.headshotMultiplier
	out.Noise = stats.alertRadius
	out.Range = stats.range
	out.MagazineSize = stats.magazineSize
	out.ReloadTime = stats.reloadTime
	out.HipSpread = stats.hipSpread
	out.AdsSpread = stats.adsSpread or weapon.AdsSpread
	out.BloomPerShot = weapon.BloomPerShot * stats.recoil
	out.BloomRecovery = weapon.BloomRecovery * stats.recoilRecovery
	out.Kick = {
		Pitch = weapon.Kick.Pitch * stats.recoil,
		Yaw = weapon.Kick.Yaw * stats.recoil,
		Recover = weapon.Kick.Recover / math.max(stats.recoilRecovery, 0.01),
	}
	out.CarryMoveFactor = weapon.CarryMoveFactor * stats.moveSpeed -- its own (the Fifty) x the fitting
	out.AdsTimeFactor = stats.adsTime
	out.ArmourPenetration = stats.armorPenetration
	out.AmmoBehaviour = stats.projectileBehavior
	out.BreachPower = stats.breachPower or 1
	out.Burn = stats.burn
	out.Merged = true
	fittedCache[key] = out
	return out
end

-- The gun `id` a soldier carries, from their Fitted attribute text (Loadout.encodeFitted).
function WeaponDefinitions.carried(id: string?, fittedText: unknown): WeaponDefinition
	if typeof(fittedText) ~= "string" or fittedText == "" then
		return WeaponDefinitions.get(id)
	end
	return WeaponDefinitions.fitted(id, Loadout.decodeFitted(fittedText))
end

return WeaponDefinitions
