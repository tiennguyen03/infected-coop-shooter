--!strict
-- MeshAssets: low-poly MeshPart templates for the props/weapons/pickups built in Blender
-- (assets/3d). The server builds each template once at boot with
-- InsertService:CreateMeshPartAsync, which is the only path that gives a MeshPart its real
-- mesh bounds (a MeshPart created by setting MeshId through Rojo sync renders at the wrong
-- scale: MeshSize stays 0). Services call `MeshAssets.clone(name)` and fall back to their old
-- placeholder Part when it returns nil (template missing or still loading), so a slow asset
-- fetch never breaks gameplay. Asset ids are recorded in assets/3d/ASSET_IDS.md.

local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MeshAssets = {}

-- Shared palette texture (assets/3d/palette.png as an Image asset).
local PALETTE_TEXTURE = "rbxassetid://87519201884536"

-- `solid` = a static obstacle: CanCollide + CastShadow on (buildings, barriers).
-- `offset` = the mesh's bounds centre relative to its design origin (Infected limbs are
-- designed around the R15 limb centre; a MeshPart is centred on its bounds).
type MeshDef = {
	meshId: string,
	size: Vector3,
	solid: boolean?,
	offset: Vector3?,
	fidelity: Enum.CollisionFidelity?, -- default Box; thin/open pieces use a tighter hull
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
	},
	env_sandbag_bunker = {
		meshId = "rbxassetid://72798329648015",
		size = Vector3.new(12.8, 6.3, 10.8),
		solid = true,
	},
	env_guard_tower = {
		meshId = "rbxassetid://140295675948906",
		size = Vector3.new(11, 27.25, 11),
		solid = true,
	},
	env_ruin_building = {
		meshId = "rbxassetid://112569589520919",
		size = Vector3.new(32.73, 24.6, 25.35),
		solid = true,
	},
	env_container_olive = {
		meshId = "rbxassetid://90739805417437",
		size = Vector3.new(22.1, 9.55, 9.2),
		solid = true,
	},
	env_container_rust = {
		meshId = "rbxassetid://108583453603951",
		size = Vector3.new(22.1, 9.55, 9.2),
		solid = true,
	},
	env_wreck_humvee = {
		meshId = "rbxassetid://101500567016827",
		size = Vector3.new(17, 7.11, 8.1),
		solid = true,
	},
	env_twall = {
		meshId = "rbxassetid://123453107626792",
		size = Vector3.new(8, 12.5, 2.6),
		solid = true,
	},
	env_hesco = {
		meshId = "rbxassetid://76249676881241",
		size = Vector3.new(6.22, 4.58, 4.72),
		solid = true,
	},
	env_comm_tower = {
		meshId = "rbxassetid://121850127656343",
		size = Vector3.new(8.04, 44.7, 8),
		solid = true,
	},
	env_tent = {
		meshId = "rbxassetid://81822440803835",
		size = Vector3.new(19.2, 8.6, 12),
		solid = true,
	},
	env_checkpoint = {
		meshId = "rbxassetid://71573561117915",
		size = Vector3.new(22.05, 9.5, 7.4),
		solid = true,
		fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition, -- the boom arm, not a block
	},
	env_dead_tree = {
		meshId = "rbxassetid://103119294791056",
		size = Vector3.new(4.97, 13.98, 7.09),
		solid = true,
		fidelity = Enum.CollisionFidelity.Hull,
	},
	env_lamp_post = {
		meshId = "rbxassetid://132474171948585",
		size = Vector3.new(4.9, 13, 1.2),
		solid = true,
		fidelity = Enum.CollisionFidelity.Hull,
	},
	-- The Chosen (assets/3d pc_<class>_<limb>): player bodies, swapped onto the player's R15
	-- rig by PlayerSetup via dressModel. Only Assault is uploaded; the other four classes are
	-- built in Blender (previews) and wait for a class system.
	pc_assault_head = {
		meshId = "rbxassetid://95005339350582",
		size = Vector3.new(1.34, 1.25, 1.48),
		offset = Vector3.new(0.000, 0.035, -0.090),
	},
	pc_assault_upper_torso = {
		meshId = "rbxassetid://86706465408743",
		size = Vector3.new(1.94, 1.7, 1.44),
		offset = Vector3.new(0.000, 0.000, -0.060),
	},
	pc_assault_lower_torso = {
		meshId = "rbxassetid://138634306069937",
		size = Vector3.new(2.01, 0.4, 1.12),
		offset = Vector3.new(0.000, 0.000, -0.050),
	},
	pc_assault_upper_arm = {
		meshId = "rbxassetid://76463628405742",
		size = Vector3.new(1.04, 1.24, 1.09),
		offset = Vector3.new(0.000, 0.000, -0.025),
	},
	pc_assault_lower_arm = {
		meshId = "rbxassetid://111242427197801",
		size = Vector3.new(1.04, 1.12, 1.04),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	pc_assault_hand = {
		meshId = "rbxassetid://133846130665573",
		size = Vector3.new(0.98, 0.33, 1.03),
		offset = Vector3.new(0.000, 0.000, -0.002),
	},
	pc_assault_upper_leg = {
		meshId = "rbxassetid://99577988454218",
		size = Vector3.new(1.08, 1.36, 1.09),
		offset = Vector3.new(0.043, 0.000, -0.058),
	},
	pc_assault_lower_leg = {
		meshId = "rbxassetid://87884254546571",
		size = Vector3.new(1.01, 1.3, 0.99),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	pc_assault_foot = {
		meshId = "rbxassetid://79144855233866",
		size = Vector3.new(1.01, 0.31, 1.0),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	-- Infected limb sets (assets/3d inf_<type>_<limb>): swapped onto the R15 rig by dressInfected.
	inf_walker_head = {
		meshId = "rbxassetid://125036021688938",
		size = Vector3.new(1.300, 1.220, 1.510),
		offset = Vector3.new(0.000, 0.020, -0.115),
	},
	inf_walker_upper_torso = {
		meshId = "rbxassetid://73526825074456",
		size = Vector3.new(2.000, 1.700, 1.190),
		offset = Vector3.new(0.030, 0.000, -0.095),
	},
	inf_walker_lower_torso = {
		meshId = "rbxassetid://90864407049648",
		size = Vector3.new(1.990, 0.400, 1.080),
		offset = Vector3.new(0.000, 0.000, -0.040),
	},
	inf_walker_upper_arm = {
		meshId = "rbxassetid://130641385322566",
		size = Vector3.new(1.000, 1.240, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_lower_arm = {
		meshId = "rbxassetid://106641376979082",
		size = Vector3.new(1.000, 1.120, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_hand = {
		meshId = "rbxassetid://101524032490960",
		size = Vector3.new(0.980, 0.330, 1.035),
		offset = Vector3.new(0.000, 0.000, -0.002),
	},
	inf_walker_upper_leg = {
		meshId = "rbxassetid://97365267283514",
		size = Vector3.new(0.990, 1.360, 1.085),
		offset = Vector3.new(0.000, 0.000, -0.058),
	},
	inf_walker_lower_leg = {
		meshId = "rbxassetid://97366869131440",
		size = Vector3.new(0.990, 1.300, 0.970),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_walker_foot = {
		meshId = "rbxassetid://79144855233866",
		size = Vector3.new(1.010, 0.310, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_runner_head = {
		meshId = "rbxassetid://85607611852070",
		size = Vector3.new(1.200, 1.220, 1.260),
		offset = Vector3.new(0.000, 0.020, -0.030),
	},
	inf_runner_upper_torso = {
		meshId = "rbxassetid://116304103046435",
		size = Vector3.new(2.000, 1.700, 1.190),
		offset = Vector3.new(0.030, 0.000, -0.095),
	},
	inf_runner_lower_torso = {
		meshId = "rbxassetid://94511863005066",
		size = Vector3.new(1.990, 0.400, 1.080),
		offset = Vector3.new(0.000, 0.000, -0.040),
	},
	inf_runner_upper_arm = {
		meshId = "rbxassetid://119560986493213",
		size = Vector3.new(1.000, 1.240, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_runner_lower_arm = {
		meshId = "rbxassetid://109736917953704",
		size = Vector3.new(1.000, 1.120, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_runner_hand = {
		meshId = "rbxassetid://84025375138002",
		size = Vector3.new(0.980, 0.330, 1.035),
		offset = Vector3.new(0.000, 0.000, -0.002),
	},
	inf_runner_upper_leg = {
		meshId = "rbxassetid://93056587028938",
		size = Vector3.new(0.990, 1.360, 1.085),
		offset = Vector3.new(0.000, 0.000, -0.058),
	},
	inf_runner_lower_leg = {
		meshId = "rbxassetid://132251690624078",
		size = Vector3.new(0.990, 1.300, 0.970),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_runner_foot = {
		meshId = "rbxassetid://79144855233866",
		size = Vector3.new(1.010, 0.310, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_brute_head = {
		meshId = "rbxassetid://140393473012009",
		size = Vector3.new(1.300, 1.240, 1.360),
		offset = Vector3.new(0.000, 0.030, -0.030),
	},
	inf_brute_upper_torso = {
		meshId = "rbxassetid://105779397180273",
		size = Vector3.new(2.000, 1.700, 1.440),
		offset = Vector3.new(0.030, 0.000, 0.030),
	},
	inf_brute_lower_torso = {
		meshId = "rbxassetid://88192737666842",
		size = Vector3.new(1.990, 0.400, 1.080),
		offset = Vector3.new(0.000, 0.000, -0.040),
	},
	inf_brute_upper_arm = {
		meshId = "rbxassetid://73003273286253",
		size = Vector3.new(1.160, 1.240, 1.160),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_brute_lower_arm = {
		meshId = "rbxassetid://121529679833263",
		size = Vector3.new(1.000, 1.120, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_brute_hand = {
		meshId = "rbxassetid://80232071254581",
		size = Vector3.new(0.980, 0.330, 1.035),
		offset = Vector3.new(0.000, 0.000, -0.002),
	},
	inf_brute_upper_leg = {
		meshId = "rbxassetid://140452804420046",
		size = Vector3.new(0.990, 1.360, 1.085),
		offset = Vector3.new(0.000, 0.000, -0.058),
	},
	inf_brute_lower_leg = {
		meshId = "rbxassetid://101498519950030",
		size = Vector3.new(0.990, 1.300, 0.970),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
	inf_brute_foot = {
		meshId = "rbxassetid://110603242759494",
		size = Vector3.new(1.010, 0.310, 1.000),
		offset = Vector3.new(0.000, 0.000, 0.000),
	},
}

local templates: { [string]: MeshPart } = {}
local warned: { [string]: boolean } = {}

local function buildTemplate(folder: Folder, name: string, def: MeshDef)
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
	part.TextureID = PALETTE_TEXTURE
	part.Size = def.size
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = def.solid == true
	part.CanQuery = def.solid == true
	part.CanTouch = false
	part.CastShadow = def.solid == true
	part.Parent = folder
	templates[name] = part
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
