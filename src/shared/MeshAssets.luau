--!strict
-- MeshAssets: low-poly MeshPart templates for the props/weapons/pickups built in Blender
-- (assets/3d). The server builds each template once at boot with
-- InsertService:CreateMeshPartAsync, which is the only path that gives a MeshPart its real
-- mesh bounds (a MeshPart created by setting MeshId through Rojo sync renders at the wrong
-- scale: MeshSize stays 0). Services call `MeshAssets.clone(name)` and fall back to their old
-- placeholder Part when it returns nil (template missing or still loading), so a slow asset
-- fetch never breaks gameplay. Asset ids are recorded in assets/3d/ASSET_IDS.md.
--
-- Composite colliders (Delta rework): a mesh with `colliders` renders only; its
-- collision and raycast shape is the listed invisible Parts (walls, steps, decks, a
-- TrussPart ladder), so bunkers, humvees, towers and the ruin have real openings and steps
-- that the vault/climb code (Shared.Ledge: anchored, CanCollide parts) and the Infected
-- climb read exactly. `offset` is the mesh bounds centre relative to the piece's design
-- origin (the floor centre; printed by build_assets.py), so collider boxes are written in
-- build coordinates. A `shell` is a cheaper sealed fallback set (outer ruins).
-- An entry whose meshId is "" is registered but not uploaded yet: no template is built,
-- `isUploaded` is false and ArenaService skips it without a warning. One that also names a
-- `fallback` (an earlier upload of the same piece) is drawn as that earlier mesh, at its
-- own size with plain solid collision: the new size and colliders describe the new FBX and
-- must not be laid over the old one.

local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MeshAssets = {}

-- Shared palette texture (assets/3d/palette.png as an Image asset).
local PALETTE_TEXTURE = "rbxassetid://121741835746247" -- palette v3 (vehicle glass, 2026-11-08)
-- What a palette mesh shows if its texture has not loaded (the client retries it:
-- PaletteController): a neutral mid grey, never the black a leftover BodyColors gave.
local PALETTE_FALLBACK = Color3.fromRGB(118, 122, 128)

-- `solid` = a static obstacle: CanCollide + CastShadow on (buildings, barriers).
-- `offset` = the mesh's bounds centre relative to its design origin (Infected limbs are
-- designed around the R15 limb centre; environment pieces around the floor centre; a
-- MeshPart is centred on its bounds).
-- A collider box in design coordinates (Roblox axis order: x, up, z = Blender x, z, y).
export type Collider = {
	size: Vector3,
	offset: Vector3, -- centre relative to the design origin
	yaw: number?, -- degrees about the up axis (WedgePart roofs)
	class: string?, -- "Part" (default), "WedgePart", "TrussPart" (a ladder)
}
type MeshDef = {
	meshId: string,
	size: Vector3,
	solid: boolean?,
	offset: Vector3?,
	fidelity: Enum.CollisionFidelity?, -- default Box; thin/open pieces use a tighter hull
	-- `surface` = a one-material mesh drawn with a Roblox built-in material instead of the
	-- palette texture (the texture would hide it): `color` is its palette hex. Only for meshes
	-- whose swatches are tones of one material; multi-colour meshes keep the palette.
	surface: { material: Enum.Material, color: Color3 }?,
	colliders: { Collider }?, -- composite collision; the mesh itself stops colliding
	shell: { Collider }?, -- sealed cheaper set, chosen per placement (ArenaService `shell`)
	castShadow: boolean?, -- override: small cover never casts (default = solid)
	render: Enum.RenderFidelity?, -- default Automatic; huge pieces always near (the Fallow) use Precise
	seeThrough: boolean?, -- fences and wire: solid to walk into, bullets and sight pass
	-- A held gun (wpn_*): the barrel tip relative to the grip (Roblox axes, barrel along -Z);
	-- PlayerSetup puts the Muzzle there. `offset` is the bounds centre from the grip.
	muzzle: Vector3?,
	-- The earlier upload that stands in while meshId is "" (see the header). At upload:
	-- paste the new meshId and delete the fallback.
	fallback: { meshId: string, size: Vector3, fidelity: Enum.CollisionFidelity? }?,
}

-- `size` is the in-game size in studs (the mesh is scaled to it). Blender sizes are in
-- assets/3d/README.md; the rifle is 0.65x of the Blender size.
local MESHES: { [string]: MeshDef } = {
	prop_ammo_crate = {
		meshId = "rbxassetid://70908704628683",
		size = Vector3.new(2.86, 1.68, 1.92),
	},
	prop_repulsor_mine = {
		meshId = "rbxassetid://122106813224951",
		size = Vector3.new(1.9, 0.97, 2),
	},
	-- Held guns: designed around the grip (pivot), barrel along -Z; `offset` = bounds centre
	-- from the grip, `muzzle` = barrel tip from the grip. A gun row names its mesh in
	-- Config.Weapons.<id>.Model (default wpn_rifle).
	wpn_rifle = {
		meshId = "rbxassetid://86613539481097",
		size = Vector3.new(0.195, 0.84, 2.9),
		offset = Vector3.new(0, 0.185, -0.54),
		muzzle = Vector3.new(0, 0.42, -1.95),
	},
	-- The Shrike gunship (assets/3d/build/aircraft.py, in-game size): the hull, origin at the
	-- fuselage centre (`offset` = bounds centre from it), and the main rotor, origin at the hub.
	veh_shrike_hull = {
		meshId = "rbxassetid://137109529997310",
		size = Vector3.new(8.4, 8.62, 29.75),
		offset = Vector3.new(0, 0.712, 3.425),
	},
	veh_shrike_rotor = {
		meshId = "rbxassetid://137738331555839",
		size = Vector3.new(18.96, 0.35, 18.89),
		offset = Vector3.new(0, 0, -0.035),
	},
	-- Sample guns (assets/3d/build/guns.py, built at in-game size, 2026-11-09).
	wpn_revolver = {
		meshId = "rbxassetid://133525801275343",
		size = Vector3.new(0.25, 0.76, 1.0),
		offset = Vector3.new(0, 0.094, -0.258),
		muzzle = Vector3.new(0, 0.34, -0.76),
	},
	wpn_sniper = {
		meshId = "rbxassetid://86507403821540",
		size = Vector3.new(0.46, 1.07, 3.65),
		offset = Vector3.new(0.117, 0.246, -0.795),
		muzzle = Vector3.new(0, 0.34, -2.62),
	},
	wpn_goose = {
		meshId = "rbxassetid://82637563176152",
		size = Vector3.new(0.6, 0.94, 3.03),
		offset = Vector3.new(-0.061, 0.202, -0.078),
		muzzle = Vector3.new(0, 0.42, -1.58),
	},
	-- The six original guns (guns.py, 2026-11-09); until then they all wore wpn_rifle.
	wpn_m16 = {
		meshId = "rbxassetid://74091027600803",
		size = Vector3.new(0.27, 1.02, 3.09),
		offset = Vector3.new(0.025, 0.144, -0.475),
		muzzle = Vector3.new(0, 0.36, -2.02),
	},
	wpn_mp5 = {
		meshId = "rbxassetid://84221584333359",
		size = Vector3.new(0.23, 0.87, 2.19),
		offset = Vector3.new(-0.025, 0.167, -0.393),
		muzzle = Vector3.new(0, 0.32, -1.49),
	},
	wpn_m249 = {
		meshId = "rbxassetid://106050421873423",
		size = Vector3.new(0.32, 0.95, 2.89),
		offset = Vector3.new(-0.043, 0.207, -0.445),
		muzzle = Vector3.new(0, 0.38, -1.89),
	},
	wpn_mossberg = {
		meshId = "rbxassetid://101866256014088",
		size = Vector3.new(0.26, 0.77, 2.82),
		offset = Vector3.new(-0.025, 0.119, -0.401),
		muzzle = Vector3.new(0, 0.42, -1.8),
	},
	wpn_m110 = {
		meshId = "rbxassetid://124848490890431",
		size = Vector3.new(0.23, 1.03, 3.25),
		offset = Vector3.new(0, 0.24, -0.825),
		muzzle = Vector3.new(0, 0.4, -2.45),
	},
	wpn_m17 = {
		meshId = "rbxassetid://104797900074658",
		size = Vector3.new(0.14, 0.76, 0.67),
		offset = Vector3.new(0, 0.067, -0.148),
		muzzle = Vector3.new(0, 0.32, -0.485),
	},
	-- Environment (assets/3d Environment collection, built to the 5-stud character; sizes are
	-- the Blender dims in Roblox axis order). `solid` = Box obstacle; see ArenaService.
	env_barrier_jersey = {
		meshId = "rbxassetid://83842095201437",
		size = Vector3.new(6, 2.75, 2),
		solid = true,
		surface = { material = Enum.Material.Concrete, color = Color3.fromRGB(124, 122, 116) }, -- concrete
		castShadow = false,
	},
	-- Three sandbag walls (COVER_H 4: vaultable), open top, open toward +Z (yaw 0).
	env_sandbag_bunker = {
		meshId = "rbxassetid://72798329648015",
		size = Vector3.new(12.8, 6.3, 10.8),
		solid = true,
		surface = { material = Enum.Material.Fabric, color = Color3.fromRGB(158, 131, 90) }, -- tan
		offset = Vector3.new(0, 3.15, 0),
		colliders = {
			{ size = Vector3.new(0.8, 4, 10.8), offset = Vector3.new(-6, 2, 0) },
			{ size = Vector3.new(0.8, 4, 10.8), offset = Vector3.new(6, 2, 0) },
			{ size = Vector3.new(12.8, 4, 0.8), offset = Vector3.new(0, 2, -5) },
		},
		castShadow = false,
	},
	-- Legs, deck at 14, rails with a gate on the ladder (+Z) side, roof slab, and a TrussPart
	-- ladder on the +Z face (Ladder collision group: the Infected never climb it).
	-- v3 (rail gate) uploaded.
	env_guard_tower = {
		meshId = "rbxassetid://85279268257603",
		size = Vector3.new(11, 27.25, 11),
		solid = true,
		offset = Vector3.new(0, 13.625, 0),
		colliders = {
			{ size = Vector3.new(0.7, 14, 0.7), offset = Vector3.new(-3.6, 7, -3.6) },
			{ size = Vector3.new(0.7, 14, 0.7), offset = Vector3.new(3.6, 7, -3.6) },
			{ size = Vector3.new(0.7, 14, 0.7), offset = Vector3.new(-3.6, 7, 3.6) },
			{ size = Vector3.new(0.7, 14, 0.7), offset = Vector3.new(3.6, 7, 3.6) },
			{ size = Vector3.new(9, 0.5, 9), offset = Vector3.new(0, 14.25, 0) },
			{ size = Vector3.new(0.25, 4, 9), offset = Vector3.new(-4.4, 16.5, 0) },
			{ size = Vector3.new(0.25, 4, 9), offset = Vector3.new(4.4, 16.5, 0) },
			{ size = Vector3.new(9, 4, 0.25), offset = Vector3.new(0, 16.5, -4.4) },
			{ size = Vector3.new(3.3, 4, 0.25), offset = Vector3.new(-2.85, 16.5, 4.4) },
			{ size = Vector3.new(3.3, 4, 0.25), offset = Vector3.new(2.85, 16.5, 4.4) },
			{ size = Vector3.new(11, 0.6, 11), offset = Vector3.new(0, 22.7, 0) },
			{ size = Vector3.new(2, 14, 2), offset = Vector3.new(0, 7.5, 5), class = "TrussPart" },
		},
	},
	-- Ruin v2: enterable ground floor (4 x 8 door in the -Z face, 6-wide breach
	-- in the +Z face at x +7, vaultable front windows sill 4 / head 9.4), first floor slab at
	-- 10.0 reached by mantling the one-storey back wall; no roof. `shell` seals it (5 parts)
	-- for the outer ruins. v2 uploaded.
	env_ruin_building = {
		meshId = "rbxassetid://72875984069129",
		size = Vector3.new(32.09, 23.6, 25.15),
		solid = true,
		offset = Vector3.new(0.847, 11.8, -0.517),
		colliders = {
			-- ground floor, front (-Z): sill bands, door lintel, head bands, jambs
			{ size = Vector3.new(13, 4, 1), offset = Vector3.new(-8.5, 2, -9.5) },
			{ size = Vector3.new(13, 4, 1), offset = Vector3.new(8.5, 2, -9.5) },
			{ size = Vector3.new(7, 2, 1), offset = Vector3.new(0, 9, -9.5) },
			{ size = Vector3.new(11.5, 0.6, 1), offset = Vector3.new(-9.25, 9.7, -9.5) },
			{ size = Vector3.new(11.5, 0.6, 1), offset = Vector3.new(9.25, 9.7, -9.5) },
			{ size = Vector3.new(1.2, 4, 1), offset = Vector3.new(-2.6, 6, -9.5) },
			{ size = Vector3.new(1.2, 4, 1), offset = Vector3.new(2.6, 6, -9.5) },
			-- ground floor sides (solid), back wall with the breach (x 4..10), its lintel
			{ size = Vector3.new(1, 10, 20), offset = Vector3.new(-14.5, 5, 0) },
			{ size = Vector3.new(1, 10, 20), offset = Vector3.new(14.5, 5, 0) },
			{ size = Vector3.new(19, 10, 1), offset = Vector3.new(-5.5, 5, 9.5) },
			{ size = Vector3.new(5, 10, 1), offset = Vector3.new(12.5, 5, 9.5) },
			{ size = Vector3.new(6.4, 2, 1), offset = Vector3.new(7, 9, 9.5) },
			-- slabs and the two interior pillars
			{ size = Vector3.new(30, 0.3, 20), offset = Vector3.new(0, 0.15, 0) },
			{ size = Vector3.new(30, 0.6, 20), offset = Vector3.new(0, 9.7, 0) },
			{ size = Vector3.new(1, 9.4, 1), offset = Vector3.new(-5, 4.7, 0) },
			{ size = Vector3.new(1, 9.4, 1), offset = Vector3.new(5, 4.7, 0) },
			-- first floor: front sill (chest cover) and head band with the parapet, corners
			{ size = Vector3.new(30, 3.2, 1), offset = Vector3.new(0, 11.6, -9.5) },
			{ size = Vector3.new(30, 1.8, 1), offset = Vector3.new(0, 19.5, -9.5) },
			{ size = Vector3.new(2.8, 5.4, 1), offset = Vector3.new(-13.6, 15.9, -9.5) },
			{ size = Vector3.new(2.8, 5.4, 1), offset = Vector3.new(13.6, 15.9, -9.5) },
			-- first floor sides: sill and head bands, back corner pillars
			{ size = Vector3.new(1, 3.2, 20), offset = Vector3.new(-14.5, 11.6, 0) },
			{ size = Vector3.new(1, 3.2, 20), offset = Vector3.new(14.5, 11.6, 0) },
			{ size = Vector3.new(1, 1.4, 20), offset = Vector3.new(-14.5, 19.3, 0) },
			{ size = Vector3.new(1, 1.4, 20), offset = Vector3.new(14.5, 19.3, 0) },
			{ size = Vector3.new(1, 5.4, 2.8), offset = Vector3.new(-14.5, 15.9, 8.6) },
			{ size = Vector3.new(1, 5.4, 2.8), offset = Vector3.new(14.5, 15.9, 8.6) },
		},
		shell = {
			{ size = Vector3.new(30, 20.4, 1), offset = Vector3.new(0, 10.2, -9.5) },
			{ size = Vector3.new(30, 10, 1), offset = Vector3.new(0, 5, 9.5) },
			{ size = Vector3.new(1, 20, 20), offset = Vector3.new(-14.5, 10, 0) },
			{ size = Vector3.new(1, 20, 20), offset = Vector3.new(14.5, 10, 0) },
			{ size = Vector3.new(30, 0.6, 20), offset = Vector3.new(0, 9.7, 0) },
		},
	},
	env_container_olive = {
		meshId = "rbxassetid://90739805417437",
		size = Vector3.new(22.1, 9.55, 9.2),
		solid = true,
		surface = { material = Enum.Material.Metal, color = Color3.fromRGB(99, 110, 66) }, -- olive
	},
	env_container_rust = {
		meshId = "rbxassetid://108583453603951",
		size = Vector3.new(22.1, 9.55, 9.2),
		solid = true,
		surface = { material = Enum.Material.CorrodedMetal, color = Color3.fromRGB(92, 50, 30) }, -- rust, darker
	},
	-- Three steps (nose toward -X): hood 4 (vault), cab 6.5 (climb), rear bed 4.8.
	env_wreck_humvee = {
		meshId = "rbxassetid://87433680532014",
		size = Vector3.new(17, 7.11, 8.1),
		solid = true,
		offset = Vector3.new(-0.25, 3.557, 0),
		colliders = {
			{ size = Vector3.new(6.1, 4, 7.8), offset = Vector3.new(-5.7, 2, 0) },
			{ size = Vector3.new(7.1, 6.5, 7.2), offset = Vector3.new(0.9, 3.25, 0) },
			{ size = Vector3.new(3.8, 4.8, 7), offset = Vector3.new(6.35, 2.4, 0) },
		},
	},
	env_twall = {
		meshId = "rbxassetid://107388028009682",
		size = Vector3.new(8.05, 12.5, 2.6),
		solid = true,
		surface = { material = Enum.Material.Concrete, color = Color3.fromRGB(124, 122, 116) }, -- concrete
	},
	env_hesco = {
		meshId = "rbxassetid://76249676881241",
		size = Vector3.new(6.22, 4.58, 4.72),
		solid = true,
		surface = { material = Enum.Material.Fabric, color = Color3.fromRGB(158, 131, 90) }, -- tan
		castShadow = false,
	},
	-- Two stacked units, 8.9 tall: Walkers (ClimbHeight 5) stop, Runners and players mantle.
	env_hesco_tall = {
		meshId = "rbxassetid://80810183774155",
		size = Vector3.new(6.32, 8.88, 4.72),
		solid = true,
		surface = { material = Enum.Material.Fabric, color = Color3.fromRGB(158, 131, 90) }, -- tan
	},
	-- Concrete cribbing under a lifted T-wall (the Gate "Scrapes"): 1.2 wide, 2.8 tall.
	env_crib_stack = {
		meshId = "rbxassetid://84277153513044",
		size = Vector3.new(1.2, 2.8, 2.6),
		solid = true,
		surface = { material = Enum.Material.Concrete, color = Color3.fromRGB(84, 82, 77) }, -- concrete_d
		castShadow = false,
	},
	-- Steel road plate between roofs: 12 x 5, walkable.
	env_deck_plate = {
		meshId = "rbxassetid://87378908913829",
		size = Vector3.new(12, 0.33, 5),
		solid = true,
		surface = { material = Enum.Material.DiamondPlate, color = Color3.fromRGB(99, 109, 119) }, -- gun
		castShadow = false,
	},
	env_comm_tower = {
		meshId = "rbxassetid://121850127656343",
		size = Vector3.new(8.04, 44.7, 8),
		solid = true,
		offset = Vector3.new(0.022, 22.35, 0),
		colliders = {
			{ size = Vector3.new(8, 1.5, 8), offset = Vector3.new(0, 0.75, 0) },
			{ size = Vector3.new(5.4, 43.2, 5.4), offset = Vector3.new(0, 23.1, 0) },
		},
	},
	-- Transit bus (docs/LEVELS.md B): Hocker-proof cover, a lane wide across a road.
	env_bus = {
		meshId = "rbxassetid://132803646952127",
		size = Vector3.new(42.9, 12.75, 10.9),
		solid = true,
	},
	-- Hull: the 4.5 walls (climbable) and two wedge roof slopes up to the ridge at 8.
	env_tent = {
		meshId = "rbxassetid://96064782371543",
		size = Vector3.new(19.2, 8.6, 12),
		solid = true,
		surface = { material = Enum.Material.Fabric, color = Color3.fromRGB(99, 110, 66) }, -- olive
		offset = Vector3.new(0, 4.3, 0),
		colliders = {
			{ size = Vector3.new(16, 4.5, 12), offset = Vector3.new(0, 2.25, 0) },
			{
				size = Vector3.new(16, 3.5, 6),
				offset = Vector3.new(0, 6.25, 3),
				yaw = 180,
				class = "WedgePart",
			},
			{
				size = Vector3.new(16, 3.5, 6),
				offset = Vector3.new(0, 6.25, -3),
				class = "WedgePart",
			},
		},
	},
	-- Booth (9 tall, climbable) with its roof, the boom arm (4.4: vaultable) on its posts.
	env_checkpoint = {
		meshId = "rbxassetid://71573561117915",
		size = Vector3.new(22.05, 9.5, 7.4),
		solid = true,
		offset = Vector3.new(7.325, 4.75, 0),
		colliders = {
			{ size = Vector3.new(6, 9, 6), offset = Vector3.new(0, 4.5, 0) },
			{ size = Vector3.new(7.4, 0.5, 7.4), offset = Vector3.new(0, 9.25, 0) },
			{ size = Vector3.new(14, 0.45, 0.45), offset = Vector3.new(11.2, 4.2, -2) },
			{ size = Vector3.new(0.8, 4.4, 0.8), offset = Vector3.new(4.2, 2.2, -2) },
			{ size = Vector3.new(0.3, 3.4, 0.3), offset = Vector3.new(18.2, 1.7, -2) },
		},
	},
	env_dead_tree = {
		meshId = "rbxassetid://103119294791056",
		size = Vector3.new(4.97, 13.98, 7.09),
		solid = true,
		fidelity = Enum.CollisionFidelity.Hull,
		surface = { material = Enum.Material.Wood, color = Color3.fromRGB(48, 53, 59) }, -- dark
	},
	env_lamp_post = {
		meshId = "rbxassetid://132474171948585",
		size = Vector3.new(4.9, 13, 1.2),
		solid = true,
		fidelity = Enum.CollisionFidelity.Hull,
		surface = { material = Enum.Material.Metal, color = Color3.fromRGB(99, 109, 119) }, -- gun
	},
	-- Delta props (assets/3d prop_*, not uploaded: meshId "" until the ids
	-- from assets/3d/ASSET_IDS.md land). Sizes are the build's Roblox dims. S = solid cover,
	-- D = decoration (no collision), T = see-through (solid, bullets pass).
	prop_cot = {
		meshId = "rbxassetid://111579390093659",
		size = Vector3.new(6.5, 2.1, 2.95),
		solid = true,
		castShadow = false,
	}, -- S
	prop_generator = {
		meshId = "rbxassetid://102465817431781",
		size = Vector3.new(8, 5.2, 4.5),
		solid = true,
	}, -- S
	prop_light_tower = {
		meshId = "rbxassetid://109327327787712",
		size = Vector3.new(4.7, 17.95, 3.9),
		solid = true,
		offset = Vector3.new(0.35, 8.975, 0),
	}, -- S
	prop_fuel_bladder = {
		meshId = "rbxassetid://104420152748932",
		size = Vector3.new(11, 3.03, 7.4),
		solid = true,
		castShadow = false,
	}, -- S
	prop_pallet = {
		meshId = "rbxassetid://85849726914721",
		size = Vector3.new(4.05, 0.57, 4),
		solid = true,
		castShadow = false,
	}, -- S
	prop_body_bag = {
		meshId = "rbxassetid://138563921819343",
		size = Vector3.new(6.6, 0.95, 2.2),
		offset = Vector3.new(0.1, 0.475, 0),
	}, -- D
	prop_dumpster = {
		meshId = "rbxassetid://135179607691394",
		size = Vector3.new(7.5, 4.4, 4.24),
		solid = true,
	}, -- S (a Walker step)
	prop_plank = {
		meshId = "rbxassetid://85743587635839",
		size = Vector3.new(10, 0.4, 2),
		solid = true,
		castShadow = false,
	}, -- S
	-- Vehicles v2 (assets/3d/build/props.py, 2026-11-08): built to the 5-stud figure, composite
	-- colliders (no mirrors or open doors in them, so the vault check sees the true width).
	-- Sedan and hatch: VAULT side-on (top 4.4-4.6). Pickup: stand in the bed (2.6), climb the
	-- cab (5.4). Van: CLIMB only (7.2, a Walker cannot reach the roof).
	prop_car_sedan = {
		meshId = "rbxassetid://133589928038621",
		size = Vector3.new(14.88, 4.57, 6.61),
		solid = true,
		offset = Vector3.new(0, 2.286, -0.098),
		colliders = {
			{ size = Vector3.new(14.4, 2.75, 6), offset = Vector3.new(0, 1.68, 0) },
			{ size = Vector3.new(7.4, 1.4, 5.2), offset = Vector3.new(0.7, 3.7, 0) },
		},
	}, -- S
	prop_car_hatch = {
		meshId = "rbxassetid://97663934153782",
		size = Vector3.new(12.88, 5.6, 8.24),
		solid = true,
		offset = Vector3.new(0, 2.8, -0.919),
		colliders = {
			{ size = Vector3.new(12.4, 2.7, 5.8), offset = Vector3.new(0, 1.65, 0) },
			{ size = Vector3.new(8.5, 1.6, 5), offset = Vector3.new(1.45, 3.8, 0) },
		},
	}, -- S
	prop_car_pickup = {
		meshId = "rbxassetid://117043997323617",
		size = Vector3.new(18.14, 5.4, 7),
		solid = true,
		offset = Vector3.new(0.38, 2.7, 0),
		colliders = {
			{ size = Vector3.new(16.9, 2.1, 6.4), offset = Vector3.new(0, 1.55, 0) }, -- body to the bed floor
			{ size = Vector3.new(6.65, 0.8, 6.4), offset = Vector3.new(-4.9, 3, 0) }, -- bonnet
			{ size = Vector3.new(2.8, 2.1, 5.8), offset = Vector3.new(-3, 4.35, 0) }, -- cab
			{ size = Vector3.new(9.85, 1.2, 0.3), offset = Vector3.new(3.3, 3, 3.05) }, -- bed rails
			{ size = Vector3.new(9.85, 1.2, 0.3), offset = Vector3.new(3.3, 3, -3.05) },
		},
	}, -- S
	prop_car_van = {
		meshId = "rbxassetid://107756699293007",
		size = Vector3.new(17.81, 7.2, 7.2),
		solid = true,
		offset = Vector3.new(0.467, 3.6, 0),
		colliders = {
			{ size = Vector3.new(14, 6.6, 6.6), offset = Vector3.new(1, 3.9, 0) },
			{ size = Vector3.new(2, 3, 6.6), offset = Vector3.new(-7, 2.1, 0) }, -- nose
		},
	}, -- S
	-- Army cargo truck (docs/LEVELS.md D1): cab CLIMB at 8, bed CLIMB at 5.7, and CRAWL-UNDER
	-- the bed between the axles (clearance 2.9): no collider fills that gap.
	prop_cargo_truck = {
		meshId = "rbxassetid://109079007816233",
		size = Vector3.new(24.28, 9.82, 9.75),
		solid = true,
		offset = Vector3.new(0.392, 4.912, 0),
		colliders = {
			{ size = Vector3.new(6.5, 7.7, 8.4), offset = Vector3.new(-7.75, 4.15, 0) }, -- cab
			{ size = Vector3.new(15.1, 0.8, 9), offset = Vector3.new(3.45, 3.3, 0) }, -- bed deck
			{ size = Vector3.new(15.1, 2, 0.35), offset = Vector3.new(3.45, 4.7, 4.33) }, -- bed sides
			{ size = Vector3.new(15.1, 2, 0.35), offset = Vector3.new(3.45, 4.7, -4.33) },
			{ size = Vector3.new(3, 2.9, 9), offset = Vector3.new(7.6, 1.45, 0) }, -- rear axle
		},
	}, -- S
	prop_portable_toilet = {
		meshId = "rbxassetid://106338287683599",
		size = Vector3.new(4.3, 8.45, 4.39),
		solid = true,
		offset = Vector3.new(0, 4.225, -0.045),
	}, -- S
	prop_chainlink_panel = {
		meshId = "rbxassetid://135724153731021",
		size = Vector3.new(12.06, 7, 0.3),
		solid = true,
		seeThrough = true,
		castShadow = false,
	}, -- T
	prop_concertina = {
		meshId = "rbxassetid://110184084591558",
		size = Vector3.new(12.13, 2.89, 2.93),
		solid = true,
		seeThrough = true,
		castShadow = false,
	}, -- T
	-- The distant city (assets/3d/build/city.py, 2026-11-08): skyline towers placed by
	-- SkyService 470-560 studs out, never collide or cast. Each `_lit` twin is the tower's
	-- lit windows on the same origin, rendered Neon (SkyService recolours sodium /
	-- fluorescent); `offset` is each mesh's bounds centre above the shared base.
	env_city_office = {
		meshId = "rbxassetid://99343457194346",
		size = Vector3.new(65.6, 178.5, 45.6),
		offset = Vector3.new(0, 89.25, 0),
		castShadow = false,
	},
	env_city_office_lit = {
		meshId = "rbxassetid://137262251701871",
		size = Vector3.new(64.34, 146.1, 44.34),
		offset = Vector3.new(0, 74.45, 0),
		surface = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 170, 90) }, -- sodium
		castShadow = false,
	},
	env_city_residential = {
		meshId = "rbxassetid://105255167927156",
		size = Vector3.new(52.2, 126.5, 37),
		offset = Vector3.new(0, 63.25, 0),
		castShadow = false,
	},
	env_city_residential_lit = {
		meshId = "rbxassetid://77011644815213",
		size = Vector3.new(50.34, 102.6, 32.34),
		offset = Vector3.new(0, 54, 0),
		surface = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 170, 90) }, -- sodium
		castShadow = false,
	},
	env_city_deco = {
		meshId = "rbxassetid://74663241301810",
		size = Vector3.new(58, 253, 58),
		offset = Vector3.new(0, 126.5, 0),
		castShadow = false,
	},
	env_city_deco_lit = {
		meshId = "rbxassetid://108427367633529",
		size = Vector3.new(56.34, 252.5, 56.34),
		offset = Vector3.new(0, 127.95, 0),
		surface = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 170, 90) }, -- sodium
		castShadow = false,
	},
	env_city_glass = {
		meshId = "rbxassetid://94468053772491",
		size = Vector3.new(51.39, 202.2, 51.39),
		offset = Vector3.new(0, 101.1, 0),
		castShadow = false,
	},
	env_city_glass_lit = {
		meshId = "rbxassetid://109060226686011",
		size = Vector3.new(48.34, 167.8, 48.34),
		offset = Vector3.new(0, 85, 0),
		surface = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 170, 90) }, -- sodium
		castShadow = false,
	},
	env_city_ruined = {
		meshId = "rbxassetid://91159310318208",
		size = Vector3.new(55.6, 132.64, 37.85),
		offset = Vector3.new(0, 66.32, -0.125),
		castShadow = false,
	},
	env_city_ruined_lit = {
		meshId = "rbxassetid://128244578925003",
		size = Vector3.new(53.47, 65.2, 29.47),
		offset = Vector3.new(-0.435, 35, 3.435),
		surface = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 170, 90) }, -- sodium
		castShadow = false,
	},
	env_city_midrise = {
		meshId = "rbxassetid://131802731205834",
		size = Vector3.new(93.2, 85, 43.2),
		offset = Vector3.new(0, 42.5, 0),
		castShadow = false,
	},
	env_city_midrise_lit = {
		meshId = "rbxassetid://92670539790330",
		size = Vector3.new(91.34, 58.1, 42.34),
		offset = Vector3.new(0.5, 30.25, 0),
		surface = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 170, 90) }, -- sodium
		castShadow = false,
	},
	-- The Chosen (assets/3d pc_<class>_<limb>): player bodies, swapped onto the player's R15
	-- rig by PlayerSetup via dressModel. Only Assault is uploaded; the other four classes are
	-- built in Blender (previews) and wait for a class system.
	-- The Warden v2 (assets/3d/build/warden.py): side-specific arms	-- and hands (`_l` / `_r`; dressModel looks the side up first) and six plates welded on	-- by IndexService (shoulder_l / shoulder_r are different meshes).
	inf_warden_head = {
		meshId = "rbxassetid://114272288507850",
		size = Vector3.new(1.030, 1.200, 1.100),
		offset = Vector3.new(0.015, 0.050, -0.050),
	},
	inf_warden_upper_torso = {
		meshId = "rbxassetid://129465433234843",
		size = Vector3.new(1.940, 2.600, 1.520),
		offset = Vector3.new(0.000, 0.450, 0.000),
	},
	inf_warden_lower_torso = {
		meshId = "rbxassetid://95229929171070",
		size = Vector3.new(2.240, 1.120, 1.090),
		offset = Vector3.new(-0.011, -0.350, -0.065),
	},
	inf_warden_upper_arm_l = {
		meshId = "rbxassetid://90178215038369",
		size = Vector3.new(0.920, 1.270, 0.920),
		offset = Vector3.new(0.000, -0.015, 0.000),
	},
	inf_warden_upper_arm_r = {
		meshId = "rbxassetid://114663756538931",
		size = Vector3.new(0.910, 1.320, 0.930),
		offset = Vector3.new(0.013, -0.040, 0.023),
	},
	inf_warden_lower_arm_l = {
		meshId = "rbxassetid://109428525195459",
		size = Vector3.new(0.960, 1.210, 0.960),
		offset = Vector3.new(0.000, -0.025, 0.000),
	},
	inf_warden_lower_arm_r = {
		meshId = "rbxassetid://108686202348825",
		size = Vector3.new(1.200, 1.170, 1.060),
		offset = Vector3.new(0.081, -0.025, -0.012),
	},
	inf_warden_hand_l = {
		meshId = "rbxassetid://87995320009567",
		size = Vector3.new(0.900, 0.360, 0.700),
		offset = Vector3.new(0.000, 0.000, 0.100),
	},
	inf_warden_hand_r = {
		meshId = "rbxassetid://118060365841446",
		size = Vector3.new(1.100, 0.440, 1.120),
		offset = Vector3.new(0.000, 0.000, -0.040),
	},
	inf_warden_upper_leg = {
		meshId = "rbxassetid://110518444449837",
		size = Vector3.new(0.850, 1.430, 1.000),
		offset = Vector3.new(0.000, -0.035, -0.078),
	},
	inf_warden_lower_leg = {
		meshId = "rbxassetid://83521572303302",
		size = Vector3.new(0.860, 1.300, 1.010),
		offset = Vector3.new(0.000, 0.000, -0.075),
	},
	inf_warden_foot = {
		meshId = "rbxassetid://108286072751669",
		size = Vector3.new(1.050, 0.340, 1.080),
		offset = Vector3.new(0.000, 0.020, -0.010),
	},
	inf_warden_plate_helmet = {
		meshId = "rbxassetid://131116560609697",
		size = Vector3.new(1.440, 1.460, 2.200),
		offset = Vector3.new(0.019, 0.060, 0.250),
	},
	inf_warden_plate_chest = {
		meshId = "rbxassetid://126497846796573",
		size = Vector3.new(1.560, 1.560, 0.590),
		offset = Vector3.new(0.000, -0.010, -0.755),
	},
	inf_warden_plate_back = {
		meshId = "rbxassetid://93038447341544",
		size = Vector3.new(1.590, 2.720, 0.570),
		offset = Vector3.new(-0.015, 0.590, 0.745),
	},
	inf_warden_plate_shoulder_l = {
		meshId = "rbxassetid://78932474946165",
		size = Vector3.new(1.660, 1.060, 1.660),
		offset = Vector3.new(0.000, 0.280, 0.000),
	},
	inf_warden_plate_shoulder_r = {
		meshId = "rbxassetid://94157814542903",
		size = Vector3.new(1.110, 0.300, 1.110),
		offset = Vector3.new(0.000, 0.480, 0.000),
	},
	inf_warden_plate_shield = {
		meshId = "rbxassetid://126685145123461",
		size = Vector3.new(0.480, 2.280, 4.280),
		offset = Vector3.new(-0.670, -0.200, 0.300),
	},
	pc_assault_head = {
		meshId = "rbxassetid://113120416771558",
		size = Vector3.new(1.340, 1.240, 1.540),
		offset = Vector3.new(0.000, 0.030, -0.060),
	},
	pc_assault_upper_torso = {
		meshId = "rbxassetid://109606627346841",
		size = Vector3.new(1.940, 1.700, 1.510),
		offset = Vector3.new(0.000, 0.000, -0.025),
	},
	pc_assault_lower_torso = {
		meshId = "rbxassetid://130324769107274",
		size = Vector3.new(2.010, 0.400, 1.120),
		offset = Vector3.new(0.000, 0.000, -0.050),
	},
	-- Tapered forearms/shins with elbow and knee pads, fist-sized hands: the
	-- rigid fallback for the skinned body, and the bots' body.
	pc_assault_upper_arm = {
		meshId = "rbxassetid://137615567202319",
		size = Vector3.new(1.040, 1.440, 1.100),
		offset = Vector3.new(0.000, -0.098, -0.030),
	},
	pc_assault_lower_arm = {
		meshId = "rbxassetid://135982743004456",
		size = Vector3.new(1.000, 1.120, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	pc_assault_hand = {
		meshId = "rbxassetid://78025074389286",
		size = Vector3.new(0.820, 0.330, 0.880),
		offset = Vector3.new(0.000, 0.000, -0.010),
	},
	pc_assault_upper_leg = {
		meshId = "rbxassetid://96325067678523",
		size = Vector3.new(1.080, 1.590, 1.090),
		offset = Vector3.new(0.043, -0.115, -0.058),
	},
	pc_assault_lower_leg = {
		meshId = "rbxassetid://131875477288797",
		size = Vector3.new(1.010, 1.300, 0.990),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	pc_assault_foot = {
		meshId = "rbxassetid://79144855233866",
		size = Vector3.new(1.010, 0.310, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	-- Skinned Weller gear (Config.Player.SkinnedGear): rigid helmet and Pike carrier built
	-- at the head / upper torso origin, welded onto the skinned body by PlayerSetup.
	pc_assault_gear_helmet = {
		meshId = "rbxassetid://106002887456604",
		size = Vector3.new(1.340, 1.110, 1.540),
		offset = Vector3.new(0.000, 0.095, -0.060),
		castShadow = true,
	},
	pc_assault_gear_carrier = {
		meshId = "rbxassetid://136938794151000",
		size = Vector3.new(1.530, 1.440, 1.510),
		offset = Vector3.new(-0.025, 0.120, -0.025),
		castShadow = true,
	},
	-- Gore pieces (assets/3d/build/gore.py; GoreService): the stump welded where a limb came
	-- off, and the three chunks GoreFX throws at body hits (copied to ReplicatedStorage).
	inf_gore_stump = {
		meshId = "rbxassetid://85306816428466",
		size = Vector3.new(0.42, 0.24, 0.44),
		offset = Vector3.new(0.014, 0.070, 0.000),
	},
	inf_gore_chunk_a = {
		meshId = "rbxassetid://114738807263836",
		size = Vector3.new(0.29, 0.32, 0.30),
	},
	inf_gore_chunk_b = {
		meshId = "rbxassetid://101420964172693",
		size = Vector3.new(0.36, 0.26, 0.27),
	},
	inf_gore_chunk_c = {
		meshId = "rbxassetid://120197171903263",
		size = Vector3.new(0.34, 0.18, 0.17),
	},
	-- Infected limb sets (assets/3d inf_<type>_<limb>): swapped onto the R15 rig by dressInfected.
	-- Built to docs/CHARACTERS.md (walker, runner, brute, hocker); skin v2 repaint
	-- (pallor / flesh / bruise / wound / pus rows, tapered limbs) uploaded the same day.
	inf_walker_head = {
		meshId = "rbxassetid://100515274220050",
		size = Vector3.new(1.220, 1.600, 1.480),
		offset = Vector3.new(-0.000, -0.115, -0.344),
	},
	inf_walker_upper_torso = {
		meshId = "rbxassetid://133210664116166",
		size = Vector3.new(2.000, 1.750, 1.200),
		offset = Vector3.new(0.000, 0.025, 0.000),
	},
	inf_walker_lower_torso = {
		meshId = "rbxassetid://78160694473395",
		size = Vector3.new(2.050, 1.510, 1.530),
		offset = Vector3.new(0.000, -0.535, 0.036),
	},
	inf_walker_upper_arm_l = {
		meshId = "rbxassetid://88373539845018",
		size = Vector3.new(0.920, 1.240, 0.920),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_upper_arm_r = {
		meshId = "rbxassetid://80180134149538",
		size = Vector3.new(0.920, 1.000, 0.920),
		offset = Vector3.new(0.000, -0.140, 0.000),
	},
	inf_walker_lower_arm = {
		meshId = "rbxassetid://119147668768706",
		size = Vector3.new(0.850, 1.120, 0.850),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_hand = {
		meshId = "rbxassetid://119988488149184",
		size = Vector3.new(0.980, 0.480, 1.030),
		offset = Vector3.new(0.000, 0.002, -0.002),
	},
	inf_walker_upper_leg = {
		meshId = "rbxassetid://100166126486572",
		size = Vector3.new(0.890, 1.400, 0.990),
		offset = Vector3.new(0.000, -0.020, -0.052),
	},
	inf_walker_lower_leg = {
		meshId = "rbxassetid://104774868957400",
		size = Vector3.new(0.990, 1.300, 0.970),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_foot = {
		meshId = "rbxassetid://79144855233866",
		size = Vector3.new(1.010, 0.310, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_runner_head = {
		meshId = "rbxassetid://115350210417323",
		size = Vector3.new(1.220, 1.360, 1.390),
		offset = Vector3.new(0.000, -0.320, -0.570),
	},
	inf_runner_upper_torso = {
		meshId = "rbxassetid://106499208970226",
		size = Vector3.new(1.980, 2.360, 1.770),
		offset = Vector3.new(0.000, 0.158, -0.260),
	},
	inf_runner_lower_torso = {
		meshId = "rbxassetid://88359244284243",
		size = Vector3.new(2.010, 0.400, 1.090),
		offset = Vector3.new(0.000, 0.000, -0.035),
	},
	inf_runner_upper_arm = {
		meshId = "rbxassetid://99272691499999",
		size = Vector3.new(0.890, 1.220, 0.900),
		offset = Vector3.new(0.000, 0.010, -0.460),
	},
	inf_runner_lower_arm = {
		meshId = "rbxassetid://125089922702221",
		size = Vector3.new(0.740, 1.670, 0.770),
		offset = Vector3.new(0.000, -0.275, -0.455),
	},
	inf_runner_hand = {
		meshId = "rbxassetid://117210071350373",
		size = Vector3.new(0.860, 0.880, 0.600),
		offset = Vector3.new(0.000, -0.860, -0.410),
	},
	inf_runner_upper_leg = {
		meshId = "rbxassetid://77353023411798",
		size = Vector3.new(0.920, 1.400, 1.050),
		offset = Vector3.new(0.000, -0.020, -0.063),
	},
	inf_runner_lower_leg = {
		meshId = "rbxassetid://77168222660520",
		size = Vector3.new(0.960, 1.300, 0.960),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_runner_foot = {
		meshId = "rbxassetid://101646860898946",
		size = Vector3.new(1.010, 0.320, 1.150),
		offset = Vector3.new(0.000, 0.008, 0.075),
	},
	inf_brute_head = {
		meshId = "rbxassetid://103853795558690",
		size = Vector3.new(1.270, 1.240, 1.300),
		offset = Vector3.new(0.015, -0.420, -0.110),
	},
	inf_brute_upper_torso = {
		meshId = "rbxassetid://99564421484824",
		size = Vector3.new(2.860, 3.110, 1.870),
		offset = Vector3.new(0.000, 0.566, 0.094),
	},
	inf_brute_lower_torso = {
		meshId = "rbxassetid://70399681157365",
		size = Vector3.new(2.400, 1.000, 1.280),
		offset = Vector3.new(0.000, -0.300, -0.040),
	},
	inf_brute_upper_arm_l = {
		meshId = "rbxassetid://128620933727692",
		size = Vector3.new(0.860, 1.260, 0.820),
		offset = Vector3.new(-0.420, 0.010, -0.001),
	},
	inf_brute_upper_arm_r = {
		meshId = "rbxassetid://109702256756531",
		size = Vector3.new(0.860, 1.260, 0.820),
		offset = Vector3.new(0.420, 0.010, -0.001),
	},
	inf_brute_lower_arm_l = {
		meshId = "rbxassetid://89240920651366",
		size = Vector3.new(1.190, 2.120, 1.010),
		offset = Vector3.new(-0.515, -0.500, -0.006),
	},
	inf_brute_lower_arm_r = {
		meshId = "rbxassetid://102739257900431",
		size = Vector3.new(1.190, 2.120, 1.010),
		offset = Vector3.new(0.515, -0.500, -0.006),
	},
	inf_brute_hand_l = {
		meshId = "rbxassetid://121604236987350",
		size = Vector3.new(0.980, 0.530, 1.050),
		offset = Vector3.new(-0.420, -1.145, -0.035),
	},
	inf_brute_hand_r = {
		meshId = "rbxassetid://99800347349644",
		size = Vector3.new(0.980, 0.530, 1.050),
		offset = Vector3.new(0.420, -1.145, -0.035),
	},
	inf_brute_upper_leg = {
		meshId = "rbxassetid://105750520943611",
		size = Vector3.new(1.040, 1.490, 1.130),
		offset = Vector3.new(0.030, -0.065, -0.076),
	},
	inf_brute_lower_leg = {
		meshId = "rbxassetid://88426621788507",
		size = Vector3.new(1.040, 1.320, 1.070),
		offset = Vector3.new(0.000, 0.010, -0.025),
	},
	inf_brute_foot = {
		meshId = "rbxassetid://129900549102552",
		size = Vector3.new(1.010, 0.370, 1.070),
		offset = Vector3.new(0.000, 0.027, -0.035),
	},
	inf_hocker_head = {
		meshId = "rbxassetid://108032089223800",
		size = Vector3.new(1.330, 1.600, 1.700),
		offset = Vector3.new(0.000, -0.029, 0.189),
	},
	inf_hocker_upper_torso = {
		meshId = "rbxassetid://72787016240114",
		size = Vector3.new(2.000, 1.770, 1.270),
		offset = Vector3.new(0.000, 0.035, -0.035),
	},
	inf_hocker_lower_torso = {
		meshId = "rbxassetid://78160694473395",
		size = Vector3.new(2.050, 1.510, 1.530),
		offset = Vector3.new(0.000, -0.535, 0.036),
	},
	inf_hocker_upper_arm = {
		meshId = "rbxassetid://126385736674962",
		size = Vector3.new(0.870, 1.240, 0.870),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_hocker_lower_arm = {
		meshId = "rbxassetid://76090964452945",
		size = Vector3.new(0.740, 1.120, 0.740),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_hocker_hand = {
		meshId = "rbxassetid://107899889726305",
		size = Vector3.new(0.980, 0.520, 1.150),
		offset = Vector3.new(0.000, -0.090, -0.067),
	},
	inf_hocker_upper_leg = {
		meshId = "rbxassetid://71651625363542",
		size = Vector3.new(0.890, 1.520, 1.230),
		offset = Vector3.new(0.000, 0.012, -0.235),
	},
	inf_hocker_lower_leg = {
		meshId = "rbxassetid://78707080286405",
		size = Vector3.new(0.990, 1.380, 1.110),
		offset = Vector3.new(0.000, -0.093, -0.074),
	},
	inf_hocker_foot = {
		meshId = "rbxassetid://79144855233866",
		size = Vector3.new(1.010, 0.310, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	-- The Fallow, the lobby ship (assets/3d/build/fallow.py; FallowArt places them). Built in
	-- ship coordinates: `offset` is the mesh centre on the ship (radar: from its turning axis;
	-- catwalk bays: from the hull face at deck height). Shells draw as Metal (`surface`),
	-- trims use the palette. Look only: every collider stays a Part in FallowBuilder.
	env_fallow_bow = {
		meshId = "rbxassetid://79486262325305",
		size = Vector3.new(84.00, 46.00, 67.00),
		offset = Vector3.new(0.000, 15.000, 173.500),
		surface = { material = Enum.Material.Metal, color = Color3.fromRGB(100, 106, 112) },
		render = Enum.RenderFidelity.Precise,
		castShadow = true,
	},
	env_fallow_bow_trim = {
		meshId = "rbxassetid://132397837700021",
		size = Vector3.new(108.38, 28.06, 40.35),
		offset = Vector3.new(0.000, 31.081, 167.025),
		castShadow = false,
	},
	env_fallow_mid_port = {
		meshId = "rbxassetid://122409690040918",
		size = Vector3.new(1.40, 47.60, 240.00),
		offset = Vector3.new(-35.000, 15.800, 20.000),
		surface = { material = Enum.Material.Metal, color = Color3.fromRGB(100, 106, 112) },
		render = Enum.RenderFidelity.Precise,
		castShadow = true,
	},
	env_fallow_mid_stbd = {
		meshId = "rbxassetid://88469209943203",
		size = Vector3.new(6.70, 47.60, 240.00),
		offset = Vector3.new(37.650, 15.800, 20.000),
		surface = { material = Enum.Material.Metal, color = Color3.fromRGB(100, 106, 112) },
		render = Enum.RenderFidelity.Precise,
		castShadow = true,
	},
	env_fallow_mid_trim = {
		meshId = "rbxassetid://89298549327422",
		size = Vector3.new(98.19, 47.71, 240.00),
		offset = Vector3.new(4.095, 22.856, 20.000),
		castShadow = false,
	},
	env_fallow_stern = {
		meshId = "rbxassetid://82182009942595",
		size = Vector3.new(82.00, 47.60, 80.60),
		offset = Vector3.new(-1.000, 15.800, -140.300),
		surface = { material = Enum.Material.Metal, color = Color3.fromRGB(100, 106, 112) },
		render = Enum.RenderFidelity.Precise,
		castShadow = true,
	},
	env_fallow_stern_trim = {
		meshId = "rbxassetid://73421811886287",
		size = Vector3.new(93.39, 46.11, 83.60),
		offset = Vector3.new(-7.495, 22.056, -141.800),
		castShadow = false,
	},
	env_fallow_island = {
		meshId = "rbxassetid://130312060133465",
		size = Vector3.new(23.50, 45.98, 60.00),
		offset = Vector3.new(32.250, 63.010, 20.000),
		surface = { material = Enum.Material.Metal, color = Color3.fromRGB(116, 122, 128) },
		render = Enum.RenderFidelity.Precise,
		castShadow = true,
	},
	env_fallow_island_trim = {
		meshId = "rbxassetid://77115099660902",
		size = Vector3.new(22.60, 75.90, 58.50),
		offset = Vector3.new(31.600, 78.050, 18.950),
		castShadow = false,
	},
	env_fallow_radar = {
		meshId = "rbxassetid://122770221853253",
		size = Vector3.new(7.30, 7.20, 2.12),
		offset = Vector3.new(0.000, 3.599, -0.122),
		castShadow = false,
	},
	env_fallow_catwalk = {
		meshId = "rbxassetid://84242427975777",
		size = Vector3.new(6.05, 4.35, 23.25),
		offset = Vector3.new(3.625, -1.725, 0.000),
		castShadow = false,
	},
	env_fallow_catwalk_rafts = {
		meshId = "rbxassetid://108793529856112",
		size = Vector3.new(6.05, 4.35, 23.25),
		offset = Vector3.new(3.625, -1.725, 0.000),
		castShadow = false,
	},
	-- Lantern, the lift bird (assets/3d/build/lantern.py; LanternBird places them). Body and
	-- trim offsets are in the helo frame (origin at the mast foot on the deck); the rotors'
	-- from their hubs. Look only: the colliders are Parts.
	veh_lantern_body = {
		meshId = "rbxassetid://96644034649925",
		size = Vector3.new(7.50, 11.50, 41.11),
		offset = Vector3.new(0.000, 7.551, -7.553),
		surface = { material = Enum.Material.Metal, color = Color3.fromRGB(104, 110, 80) },
		render = Enum.RenderFidelity.Precise,
		castShadow = true,
	},
	veh_lantern_trim = {
		meshId = "rbxassetid://120258286814432",
		size = Vector3.new(7.94, 11.65, 30.05),
		offset = Vector3.new(0.080, 5.825, -1.975),
		castShadow = false,
	},
	veh_lantern_rotor = {
		meshId = "rbxassetid://72210514497412",
		size = Vector3.new(38.01, 1.14, 38.01),
		offset = Vector3.new(0.000, -0.320, 0.000),
		castShadow = true,
	},
	veh_lantern_tail_rotor = {
		meshId = "rbxassetid://130131221968255",
		size = Vector3.new(0.40, 5.20, 0.60),
		offset = Vector3.new(0.000, 0.000, 0.000),
		castShadow = false,
	},
}

-- Swap in each pending entry's `fallback` (header): the earlier mesh at its own size, plain
-- solid collision, none of the new entry's colliders or offset.
do
	local standIns: { [string]: MeshDef } = {}
	for name, def in MESHES do
		local fallback = def.fallback
		if def.meshId == "" and fallback then
			standIns[name] = {
				meshId = fallback.meshId,
				size = fallback.size,
				fidelity = fallback.fidelity,
				solid = def.solid,
				surface = def.surface,
				castShadow = def.castShadow,
				seeThrough = def.seeThrough,
			}
		end
	end
	for name, def in standIns do
		MESHES[name] = def
	end
end

local templates: { [string]: MeshPart } = {}
local warned: { [string]: boolean } = {}

local function buildTemplate(folder: Folder, name: string, def: MeshDef)
	if def.meshId == "" then
		return -- registered, not uploaded yet (MeshAssets.isUploaded is false)
	end
	local ok, result = pcall(function()
		-- Positional form: (meshId, collisionFidelity, renderFidelity). The options-table
		-- form documented elsewhere fails here with "Argument 3 missing or nil".
		return InsertService:CreateMeshPartAsync(
			def.meshId,
			def.fidelity or Enum.CollisionFidelity.Box,
			def.render or Enum.RenderFidelity.Automatic
		)
	end)
	if not ok or typeof(result) ~= "Instance" then
		warn(`MeshAssets: could not build {name}: {tostring(result)}`)
		return
	end
	local part = result :: MeshPart
	part.Name = name
	part.Size = def.size
	local surface = def.surface
	if surface then
		part.TextureID = ""
		part.Material = surface.material
		part.Color = surface.color
	else
		part.TextureID = PALETTE_TEXTURE
		part.Material = Enum.Material.SmoothPlastic
		part.Color = PALETTE_FALLBACK
	end
	part.Anchored = true
	-- A piece with composite colliders only renders: the invisible Parts carry collision
	-- and raycasts (see addColliders). See-through pieces collide but let rays through.
	local physical = def.solid == true and def.colliders == nil
	part.CanCollide = physical
	part.CanQuery = physical and def.seeThrough ~= true
	part.CanTouch = false
	part.CastShadow = if def.castShadow ~= nil then def.castShadow else def.solid == true
	part.Parent = folder
	templates[name] = part
end

-- True when the entry has an asset id (a template will exist once it has loaded).
function MeshAssets.isUploaded(name: string): boolean
	local def = MESHES[name]
	return def ~= nil and def.meshId ~= ""
end

function MeshAssets.getSize(name: string): Vector3?
	local def = MESHES[name]
	return def and def.size
end

-- The mesh's bounds centre above its design origin (Roblox axes); the bottom-centre pivot
-- (half the height up) when the entry names none.
function MeshAssets.getOffset(name: string): Vector3
	local def = MESHES[name]
	if not def then
		return Vector3.zero
	end
	return def.offset or Vector3.new(0, def.size.Y / 2, 0)
end

-- A held gun's barrel tip relative to its grip (nil for a mesh that is not a gun).
function MeshAssets.getMuzzle(name: string): Vector3?
	local def = MESHES[name]
	return def and def.muzzle
end

-- Builds the composite colliders of a placed piece as invisible anchored Parts parented to
-- it (`useShell` picks the sealed fallback set). Returns how many were made. TrussParts go
-- in the "Ladder" collision group (registered by ArenaService) so no Infected climbs one.
function MeshAssets.addColliders(part: BasePart, name: string, useShell: boolean?): number
	local def = MESHES[name]
	if not def then
		return 0
	end
	local list: { Collider }? = if useShell and def.shell then def.shell else def.colliders
	if not list then
		return 0
	end
	local origin = def.offset or Vector3.new(0, def.size.Y / 2, 0)
	for index, collider in list do
		local box = Instance.new((collider.class or "Part") :: any) :: BasePart
		box.Name = `Collider{index}`
		box.Size = collider.size
		box.CFrame = part.CFrame
			* CFrame.new(collider.offset - origin)
			* CFrame.Angles(0, math.rad(collider.yaw or 0), 0)
		box.Anchored = true
		box.CanCollide = true
		box.CanQuery = true
		box.CanTouch = false
		box.CastShadow = false
		box.Transparency = 1
		if box:IsA("TrussPart") then
			box.CollisionGroup = "Ladder"
		end
		box.Parent = part
	end
	return #list
end

-- Yields until the template exists (or the timeout passes). For boot-time placement.
function MeshAssets.waitFor(name: string, timeoutSeconds: number): MeshPart?
	local deadline = os.clock() + timeoutSeconds
	while not templates[name] and os.clock() < deadline do
		task.wait(0.25)
	end
	return MeshAssets.clone(name)
end

-- Server only. Templates fill in asynchronously; clone() returns nil until a template is ready.
function MeshAssets.init()
	if not RunService:IsServer() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "MeshTemplates"
	folder.Parent = ServerStorage
	for name, def in MESHES do
		task.spawn(buildTemplate, folder, name, def)
	end
end

-- R15 limb part name -> limb mesh suffix (left/right share one mesh).
local LIMB_OF_PART: { [string]: string } = {
	Head = "head",
	UpperTorso = "upper_torso",
	LowerTorso = "lower_torso",
	LeftUpperArm = "upper_arm",
	RightUpperArm = "upper_arm",
	LeftLowerArm = "lower_arm",
	RightLowerArm = "lower_arm",
	LeftHand = "hand",
	RightHand = "hand",
	LeftUpperLeg = "upper_leg",
	RightUpperLeg = "upper_leg",
	LeftLowerLeg = "lower_leg",
	RightLowerLeg = "lower_leg",
	LeftFoot = "foot",
	RightFoot = "foot",
}

-- True once every limb template of a set (`inf_walker_`, `pc_assault_`...) is built.
-- The mesh a limb part wears from `prefix`: a side-specific `_l` / `_r` entry when the set
-- defines one for that part's side (the Warden's arms), else the shared limb mesh.
local function limbMeshName(prefix: string, partName: string): string?
	local limb = LIMB_OF_PART[partName]
	if not limb then
		return nil
	end
	local side = if string.sub(partName, 1, 4) == "Left"
		then "_l"
		elseif string.sub(partName, 1, 5) == "Right" then "_r"
		else ""
	if side ~= "" and MESHES[prefix .. limb .. side] then
		return prefix .. limb .. side
	end
	return prefix .. limb
end

function MeshAssets.hasSet(prefix: string): boolean
	for partName in LIMB_OF_PART do
		local name = limbMeshName(prefix, partName)
		if not name or not templates[name] then
			return false
		end
	end
	return true
end

function MeshAssets.hasInfectedSet(typeName: string): boolean
	return MeshAssets.hasSet(`inf_{string.lower(typeName)}_`)
end

-- Swaps every R15 limb of `model` for the `prefix` limb set (same part names, same centres,
-- attachments carried over), then rebuilds the joints from the attachments. Works on the
-- Infected templates and on live player characters (which must have no appearance loaded:
-- accessories and clothing are stripped here, body scales are left at 1).
function MeshAssets.dressModel(model: Model, prefix: string): boolean
	if not MeshAssets.hasSet(prefix) then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	for _, child in model:GetChildren() do
		-- BodyColors would tint the new limbs (bots came out black when the palette texture
		-- failed to load): the palette carries every colour.
		if
			child:IsA("Accoutrement")
			or child:IsA("Clothing")
			or child:IsA("ShirtGraphic")
			or child:IsA("BodyColors")
		then
			child:Destroy()
		end
	end
	for _, part in model:GetChildren() do
		local name = if part:IsA("BasePart") then limbMeshName(prefix, part.Name) else nil
		if not name or not part:IsA("BasePart") then
			continue
		end
		local def = MESHES[name]
		local replacement = (templates[name] :: MeshPart):Clone()
		local offset = def.offset or Vector3.zero
		replacement.Name = part.Name
		replacement.CFrame = part.CFrame * CFrame.new(offset)
		replacement.Anchored = false
		replacement.CanCollide = part.CanCollide
		replacement.CanQuery = part.CanQuery
		replacement.CanTouch = part.CanTouch
		replacement.CastShadow = true
		for _, child in part:GetChildren() do
			local originalSize = if child.Name == "OriginalSize" and child:IsA("Vector3Value")
				then child
				else nil
			if originalSize then
				-- The Humanoid resizes each part to OriginalSize x its body scales. Keep the
				-- ratio it applied to the old part so the mesh comes out at its own size.
				local old = originalSize.Value
				local ratio = Vector3.new(
					if old.X > 0 then part.Size.X / old.X else 1,
					if old.Y > 0 then part.Size.Y / old.Y else 1,
					if old.Z > 0 then part.Size.Z / old.Z else 1
				)
				originalSize.Value = replacement.Size / ratio
				originalSize.Parent = replacement
			elseif child:IsA("Attachment") then
				-- Keep the attachment at the same place in the limb: the new part centre moved.
				child.CFrame = child.CFrame - offset
				child.Parent = replacement
			elseif child:IsA("Motor6D") then
				child:Destroy()
			elseif not child:IsA("Decal") and not child:IsA("SpecialMesh") then
				child.Parent = replacement
			end
		end
		replacement.Parent = model
		part:Destroy()
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			descendant:Destroy()
		end
	end
	humanoid:BuildRigFromAttachments()
	return true
end

-- The mesh's bounds-centre offset from its design origin (nil when the mesh is not defined).
-- Skinned bodies: a Chosen as one skinned mesh. Two Model assets per body,
-- both uploaded from assets/3d/export: `body` (<name>.fbx) is the single skinned MeshPart
-- with the R15 bone tree; `parts` (<name>_parts.fbx) is the same geometry split into the 15
-- R15 limbs, with the Motor6Ds Studio's importer builds from the rig attachments. The
-- limbs stay invisible and carry what the game expects of an R15 character (joint names,
-- Head for headshots, RightHand for the rifle, UpperTorso for the gear); the skinned mesh
-- welds to the root and the Animator poses its bones by the same names as the motors, so
-- every clip plays on both at once and the skin follows the hidden rig exactly.
type SkinnedDef = { body: number, parts: number, hipHeight: number }
local SKINNED_BODIES: { [string]: SkinnedDef } = {
	pc_assault_skinned = { body = 87236345847400, parts = 89768415142935, hipHeight = 2.19 },
}
local IMPORT_SCALE = 0.01 -- the FBX pipeline writes centimetres; the importer keeps them as studs
local MOTOR_NAMES = { -- importer name (by Part1) -> stock R15 joint name (StanceService uses Root)
	LowerTorso = "Root",
	UpperTorso = "Waist",
	Head = "Neck",
	LeftUpperArm = "LeftShoulder",
	LeftLowerArm = "LeftElbow",
	LeftHand = "LeftWrist",
	RightUpperArm = "RightShoulder",
	RightLowerArm = "RightElbow",
	RightHand = "RightWrist",
	LeftUpperLeg = "LeftHip",
	LeftLowerLeg = "LeftKnee",
	LeftFoot = "LeftAnkle",
	RightUpperLeg = "RightHip",
	RightLowerLeg = "RightKnee",
	RightFoot = "RightAnkle",
}

-- Loads and assembles a skinned body as a character Model (Humanoid + Animator, R15 part
-- names, HumanoidRootPart). Yields on the asset fetch; nil (with a warning) when either
-- asset fails to load, so the caller keeps the limb-swap body.
function MeshAssets.buildSkinnedBody(name: string): Model?
	local def = SKINNED_BODIES[name]
	if not def then
		warn(`MeshAssets: no skinned body named {name}`)
		return nil
	end
	local okParts, partsWrap = pcall(InsertService.LoadAsset, InsertService, def.parts)
	local okBody, bodyWrap = pcall(InsertService.LoadAsset, InsertService, def.body)
	local rig = if okParts and typeof(partsWrap) == "Instance"
		then partsWrap:FindFirstChildWhichIsA("Model")
		else nil
	local bodyModel = if okBody and typeof(bodyWrap) == "Instance"
		then bodyWrap:FindFirstChildWhichIsA("Model")
		else nil
	local skin = bodyModel and bodyModel:FindFirstChildWhichIsA("MeshPart")
	local root = rig and rig:FindFirstChild("RootPart")
	if not rig or not bodyModel or not skin or not root or not root:IsA("BasePart") then
		warn(
			`MeshAssets: could not load skinned body {name}: {tostring(partsWrap)} / {tostring(
				bodyWrap
			)}`
		)
		if typeof(partsWrap) == "Instance" then
			partsWrap:Destroy()
		end
		if typeof(bodyWrap) == "Instance" then
			bodyWrap:Destroy()
		end
		return nil
	end
	rig.PrimaryPart = root
	rig:ScaleTo(IMPORT_SCALE)
	bodyModel:ScaleTo(IMPORT_SCALE)
	-- ScaleTo leaves the Model's scale factor at 0.01, and a Humanoid scales its movement
	-- forces by its character's scale: the body took over a second to reach walking speed
	-- and slid to a stop. Re-home the scaled parts in a fresh Model (scale 1, same sizes).
	local scaled = rig
	rig = Instance.new("Model")
	rig.Name = name
	for _, child in scaled:GetChildren() do
		child.Parent = rig
	end
	scaled:Destroy()
	rig.PrimaryPart = root
	for _, leftover in { "InitialPoses", "AnimationController" } do
		local child = rig:FindFirstChild(leftover)
		if child then
			child:Destroy()
		end
	end
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = false
	root.CanCollide = true
	for _, part in rig:GetChildren() do
		if part:IsA("MeshPart") then
			part.Transparency = 1
			part.CastShadow = false
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = true
			part.Massless = true
			local motor = part:FindFirstChildOfClass("Motor6D")
			if motor and MOTOR_NAMES[part.Name] then
				motor.Name = MOTOR_NAMES[part.Name]
			end
		end
	end
	-- The skin's root bone sits on the hidden rig's root node (both are the build origin).
	local rootBone = root:FindFirstChildOfClass("Bone")
	local skinBone = skin:FindFirstChildOfClass("Bone")
	local node = root.CFrame * (if rootBone then rootBone.CFrame else CFrame.identity)
	skin.CFrame = node * (if skinBone then skinBone.CFrame:Inverse() else CFrame.identity)
	skin.Name = "SkinnedBody"
	skin.TextureID = PALETTE_TEXTURE
	skin.Material = Enum.Material.SmoothPlastic
	skin.Anchored = false
	skin.CanCollide = false
	skin.CanQuery = false -- bullets hit the hidden limbs (headshots stay per part)
	skin.CanTouch = false
	skin.Massless = true
	skin.CastShadow = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = skin
	weld.Parent = skin
	skin.Parent = rig
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = def.hipHeight
	humanoid.Parent = rig
	Instance.new("Animator").Parent = humanoid
	rig.Parent = nil
	partsWrap:Destroy()
	bodyWrap:Destroy()
	return rig
end

function MeshAssets.offsetOf(name: string): Vector3?
	local def = MESHES[name]
	if not def then
		return nil
	end
	return def.offset or Vector3.zero
end

function MeshAssets.dressInfected(model: Model, typeName: string): boolean
	return MeshAssets.dressModel(model, `inf_{string.lower(typeName)}_`)
end

-- The shared palette texture every palette mesh uses (PaletteController re-applies it).
MeshAssets.PALETTE_TEXTURE = PALETTE_TEXTURE

function MeshAssets.clone(name: string): MeshPart?
	local template = templates[name]
	if template then
		return template:Clone()
	end
	if not warned[name] then
		warned[name] = true
		warn(`MeshAssets: template {name} not ready or missing; using placeholder`)
	end
	return nil
end

return MeshAssets
