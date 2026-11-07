--!strict
-- MeshAssets: low-poly MeshPart templates for the props/weapons/pickups built in Blender
-- (assets/3d). The server builds each template once at boot with
-- InsertService:CreateMeshPartAsync, which is the only path that gives a MeshPart its real
-- mesh bounds (a MeshPart created by setting MeshId through Rojo sync renders at the wrong
-- scale: MeshSize stays 0). Services call `MeshAssets.clone(name)` and fall back to their old
-- placeholder Part when it returns nil (template missing or still loading), so a slow asset
-- fetch never breaks gameplay. Asset ids are recorded in assets/3d/ASSET_IDS.md.
--
-- Composite colliders (Delta rework, 2026-11-07): a mesh with `colliders` renders only; its
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
local PALETTE_TEXTURE = "rbxassetid://115366221483568"

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
	seeThrough: boolean?, -- fences and wire: solid to walk into, bullets and sight pass
	-- The earlier upload that stands in while meshId is "" (see the header). At upload:
	-- paste the new meshId and delete the fallback.
	fallback: { meshId: string, size: Vector3, fidelity: Enum.CollisionFidelity? }?,
}

-- `size` is the in-game size in studs (the mesh is scaled to it). Blender sizes are in
-- assets/3d/README.md; rifle is 0.65x and drone 0.8x of the Blender size.
local MESHES: { [string]: MeshDef } = {
	pick_xp_orb = { meshId = "rbxassetid://95196197176639", size = Vector3.new(1, 1, 1) },
	prop_ammo_crate = {
		meshId = "rbxassetid://70908704628683",
		size = Vector3.new(2.86, 1.68, 1.92),
	},
	prop_repulsor_mine = {
		meshId = "rbxassetid://122106813224951",
		size = Vector3.new(1.9, 0.97, 2),
	},
	prop_drone = { meshId = "rbxassetid://132929388031760", size = Vector3.new(1.94, 0.43, 1.94) },
	prop_drone_beacon = {
		meshId = "rbxassetid://117405323536844",
		size = Vector3.new(1.56, 3.21, 1.36),
	},
	wpn_rifle = { meshId = "rbxassetid://86613539481097", size = Vector3.new(0.195, 0.84, 2.9) },
	-- 0.7x of the Blender size (tail included in the length).
	prop_plague_rat = {
		meshId = "rbxassetid://102065990394982",
		size = Vector3.new(0.47, 0.52, 1.88),
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
	-- v3 (rail gate) uploaded 2026-11-07.
	env_guard_tower = {
		meshId = "rbxassetid://115469907629978",
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
	-- Ruin v2 (2026-11-07): enterable ground floor (4 x 8 door in the -Z face, 6-wide breach
	-- in the +Z face at x +7, vaultable front windows sill 4 / head 9.4), first floor slab at
	-- 10.0 reached by mantling the one-storey back wall; no roof. `shell` seals it (5 parts)
	-- for the outer ruins. v2 uploaded 2026-11-07.
	env_ruin_building = {
		meshId = "rbxassetid://97636619216682",
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
		surface = { material = Enum.Material.CorrodedMetal, color = Color3.fromRGB(92, 50, 30) }, -- rust, darker (art pass 2026-11-07)
	},
	-- Three steps (nose toward -X): hood 4 (vault), cab 6.5 (climb), rear bed 4.8.
	env_wreck_humvee = {
		meshId = "rbxassetid://101500567016827",
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
		meshId = "rbxassetid://123453107626792",
		size = Vector3.new(8, 12.5, 2.6),
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
		meshId = "rbxassetid://87652619532508",
		size = Vector3.new(6.22, 8.88, 4.72),
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
		meshId = "rbxassetid://115848012015557",
		size = Vector3.new(42.9, 12.75, 10.9),
		solid = true,
	},
	-- Hull: the 4.5 walls (climbable) and two wedge roof slopes up to the ridge at 8.
	env_tent = {
		meshId = "rbxassetid://81822440803835",
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
	-- Delta props (assets/3d prop_*, built 2026-11-07, not uploaded: meshId "" until the ids
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
	prop_civilian_car = {
		meshId = "rbxassetid://131007713996765",
		size = Vector3.new(15.7, 4.8, 7.5),
		solid = true,
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
	-- The Chosen (assets/3d pc_<class>_<limb>): player bodies, swapped onto the player's R15
	-- rig by PlayerSetup via dressModel. Only Assault is uploaded; the other four classes are
	-- built in Blender (previews) and wait for a class system.
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
	-- Tapered forearms/shins with elbow and knee pads, fist-sized hands (2026-11-07): the
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
	-- Infected limb sets (assets/3d inf_<type>_<limb>): swapped onto the R15 rig by dressInfected.
	-- Rebuilt 2026-11-07 to docs/CHARACTERS.md (walker, runner, brute, hocker); skin v2 repaint
	-- (pallor / flesh / bruise / wound / pus rows, tapered limbs) uploaded the same day.
	inf_walker_head = {
		meshId = "rbxassetid://100636262646383",
		size = Vector3.new(1.220, 1.290, 1.310),
		offset = Vector3.new(-0.000, -0.016, -0.035),
	},
	inf_walker_upper_torso = {
		meshId = "rbxassetid://119661347321934",
		size = Vector3.new(2.000, 1.750, 1.200),
		offset = Vector3.new(0.000, 0.025, 0.000),
	},
	inf_walker_lower_torso = {
		meshId = "rbxassetid://115889571442634",
		size = Vector3.new(2.050, 0.430, 1.370),
		offset = Vector3.new(0.000, 0.005, -0.045),
	},
	inf_walker_upper_arm = {
		meshId = "rbxassetid://88373539845018",
		size = Vector3.new(0.920, 1.240, 0.920),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_lower_arm = {
		meshId = "rbxassetid://81627412669309",
		size = Vector3.new(0.780, 1.120, 0.780),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_hand = {
		meshId = "rbxassetid://119988488149184",
		size = Vector3.new(0.980, 0.480, 1.030),
		offset = Vector3.new(0.000, 0.002, -0.002),
	},
	inf_walker_upper_leg = {
		meshId = "rbxassetid://133917422037960",
		size = Vector3.new(1.000, 1.400, 1.130),
		offset = Vector3.new(0.000, -0.020, 0.016),
	},
	inf_walker_lower_leg = {
		meshId = "rbxassetid://129665594524599",
		size = Vector3.new(0.990, 1.300, 0.970),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_foot = {
		meshId = "rbxassetid://79144855233866",
		size = Vector3.new(1.010, 0.310, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_runner_head = {
		meshId = "rbxassetid://137864155811153",
		size = Vector3.new(1.220, 1.180, 1.260),
		offset = Vector3.new(0.000, 0.000, -0.050),
	},
	inf_runner_upper_torso = {
		meshId = "rbxassetid://80475549545734",
		size = Vector3.new(1.940, 1.810, 1.250),
		offset = Vector3.new(0.000, 0.055, -0.015),
	},
	inf_runner_lower_torso = {
		meshId = "rbxassetid://88359244284243",
		size = Vector3.new(2.010, 0.400, 1.090),
		offset = Vector3.new(0.000, 0.000, -0.035),
	},
	inf_runner_upper_arm = {
		meshId = "rbxassetid://123865928638635",
		size = Vector3.new(0.890, 1.220, 0.900),
		offset = Vector3.new(0.000, 0.010, -0.010),
	},
	inf_runner_lower_arm = {
		meshId = "rbxassetid://105743362905245",
		size = Vector3.new(0.740, 1.120, 0.770),
		offset = Vector3.new(0.000, 0.000, -0.005),
	},
	inf_runner_hand = {
		meshId = "rbxassetid://112441012464559",
		size = Vector3.new(0.980, 0.340, 1.180),
		offset = Vector3.new(0.000, 0.010, -0.080),
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
		meshId = "rbxassetid://111819664336015",
		size = Vector3.new(1.270, 1.240, 1.300),
		offset = Vector3.new(0.015, 0.030, -0.030),
	},
	inf_brute_upper_torso = {
		meshId = "rbxassetid://74874414531963",
		size = Vector3.new(2.100, 1.950, 1.470),
		offset = Vector3.new(0.000, 0.125, 0.034),
	},
	inf_brute_lower_torso = {
		meshId = "rbxassetid://123309828753718",
		size = Vector3.new(2.010, 0.400, 1.090),
		offset = Vector3.new(0.000, 0.000, -0.035),
	},
	inf_brute_upper_arm = {
		meshId = "rbxassetid://133254036749836",
		size = Vector3.new(0.820, 1.240, 0.780),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_brute_lower_arm = {
		meshId = "rbxassetid://131637342574392",
		size = Vector3.new(1.190, 1.120, 1.010),
		offset = Vector3.new(0.095, 0.000, -0.006),
	},
	inf_brute_hand = {
		meshId = "rbxassetid://139690589575020",
		size = Vector3.new(0.980, 0.410, 1.050),
		offset = Vector3.new(0.000, -0.005, -0.035),
	},
	inf_brute_upper_leg = {
		meshId = "rbxassetid://96003182956310",
		size = Vector3.new(1.020, 1.490, 1.130),
		offset = Vector3.new(0.020, -0.065, -0.076),
	},
	inf_brute_lower_leg = {
		meshId = "rbxassetid://104847318095639",
		size = Vector3.new(0.990, 1.300, 1.030),
		offset = Vector3.new(0.000, 0.000, -0.028),
	},
	inf_brute_foot = {
		meshId = "rbxassetid://129900549102552",
		size = Vector3.new(1.010, 0.370, 1.070),
		offset = Vector3.new(0.000, 0.027, -0.035),
	},
	inf_hocker_head = {
		meshId = "rbxassetid://126429750811463",
		size = Vector3.new(1.330, 1.580, 1.680),
		offset = Vector3.new(0.000, 0.002, -0.040),
	},
	inf_hocker_upper_torso = {
		meshId = "rbxassetid://136320366451034",
		size = Vector3.new(2.000, 1.750, 1.190),
		offset = Vector3.new(0.000, 0.025, 0.003),
	},
	inf_hocker_lower_torso = {
		meshId = "rbxassetid://115889571442634",
		size = Vector3.new(2.050, 0.430, 1.370),
		offset = Vector3.new(0.000, 0.005, -0.045),
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
		meshId = "rbxassetid://133917422037960",
		size = Vector3.new(1.000, 1.400, 1.130),
		offset = Vector3.new(0.000, -0.020, 0.016),
	},
	inf_hocker_lower_leg = {
		meshId = "rbxassetid://129665594524599",
		size = Vector3.new(0.990, 1.300, 0.970),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_hocker_foot = {
		meshId = "rbxassetid://79144855233866",
		size = Vector3.new(1.010, 0.310, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
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
			Enum.RenderFidelity.Automatic
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
	while templates[name] == nil and os.clock() < deadline do
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
function MeshAssets.hasSet(prefix: string): boolean
	for _, limb in LIMB_OF_PART do
		if not templates[prefix .. limb] then
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
		if child:IsA("Accoutrement") or child:IsA("Clothing") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	for _, part in model:GetChildren() do
		local limb = part:IsA("BasePart") and LIMB_OF_PART[part.Name]
		if not limb then
			continue
		end
		local name = prefix .. limb
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
			if child:IsA("Attachment") then
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
-- Skinned bodies (2026-11-07): a Chosen as one skinned mesh. Two Model assets per body,
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
	rig.Name = name
	rig.PrimaryPart = root
	rig:ScaleTo(IMPORT_SCALE)
	bodyModel:ScaleTo(IMPORT_SCALE)
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
