--!strict
-- The rack behind the Quartermaster's cage (owner, 2026-11-09: "somewhere to store the guns"): a
-- board on the hangar wall with every gun, sidearm and grenade the Arms Room catalog lists,
-- hung in catalog order (ArmsRoom.catalog). Each piece is a Model named by its weapon id;
-- ArmsRackUI (client) finds them by name, slides the one under the cursor forward and frames
-- the one clicked. Nothing is bought here yet (merits wait for F9).
--
-- Gun models: stand-in block silhouettes per id (SILHOUETTES) until the gun meshes arrive;
-- an id whose MeshAssets mesh is uploaded (MESH) is swapped for it once loaded. A new gun
-- model goes in by adding its mesh name to MESH (and its MeshAssets entry).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmsRoom = require(ReplicatedStorage.Shared.ArmsRoom)
local Config = require(ReplicatedStorage.Shared.Config)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Build = require(script.Parent.Build)
local Layout = require(script.Parent.FallowLayout)

local ArmsRack = {}

local BOARD = Color3.fromRGB(40, 42, 44)
local PEG = Color3.fromRGB(99, 109, 119)
local DARK = Color3.fromRGB(48, 53, 59)
local GREY = Color3.fromRGB(75, 81, 89)
local OLIVE = Color3.fromRGB(99, 110, 66)
local WOOD = Color3.fromRGB(110, 90, 60)

-- Real gun meshes by weapon id (MeshAssets names). The rest use their silhouette.
local MESH: { [string]: string } = {
	service_rifle = "wpn_rifle",
}

type Block = { size: Vector3, at: Vector3, color: Color3, ball: boolean? }

local function b(sx: number, sy: number, x: number, y: number, color: Color3, sz: number?): Block
	return { size = Vector3.new(sx, sy, sz or 0.2), at = Vector3.new(x, y, 0), color = color }
end

-- Silhouettes in the gun's own frame: +X the muzzle, +Y up, Z the gun's thickness.
local SILHOUETTES: { [string]: { Block } } = {
	service_rifle = {
		b(1.0, 0.35, 0, 0, DARK),
		b(0.7, 0.25, 0.75, 0, GREY, 0.22),
		b(0.9, 0.09, 1.1, 0.05, DARK, 0.09),
		b(0.75, 0.3, -0.85, -0.05, DARK, 0.18),
		b(0.18, 0.5, 0.15, -0.4, GREY, 0.15),
		b(0.15, 0.35, -0.3, -0.3, DARK, 0.15),
		b(0.5, 0.1, 0, 0.25, DARK, 0.1),
		b(0.06, 0.25, 1.05, 0.2, DARK, 0.06),
	},
	smg = {
		b(0.8, 0.3, 0, 0, DARK),
		b(0.35, 0.08, 0.55, 0.05, DARK, 0.08),
		b(0.5, 0.12, -0.62, 0, GREY, 0.12),
		b(0.15, 0.45, 0.22, -0.35, GREY, 0.14),
		b(0.15, 0.3, -0.15, -0.28, DARK, 0.15),
	},
	lmg = {
		b(1.1, 0.42, 0, 0, OLIVE, 0.26),
		b(0.6, 0.28, 0.85, 0, DARK, 0.24),
		b(1.3, 0.1, 1.45, 0.05, DARK, 0.1),
		b(0.8, 0.32, -0.95, -0.05, OLIVE, 0.2),
		b(0.4, 0.4, 0.1, -0.4, OLIVE, 0.3),
		b(0.8, 0.05, 1.4, -0.15, GREY, 0.05),
		b(0.5, 0.1, 0, 0.3, DARK, 0.1),
	},
	shotgun = {
		b(0.8, 0.3, 0, 0, DARK),
		b(1.5, 0.1, 1.15, 0.07, DARK, 0.1),
		b(1.3, 0.09, 1.05, -0.07, GREY, 0.09),
		b(0.5, 0.18, 0.85, -0.07, WOOD, 0.18),
		b(0.9, 0.3, -0.85, -0.05, WOOD, 0.18),
		b(0.15, 0.3, -0.25, -0.25, DARK, 0.15),
	},
	dmr = {
		b(1.0, 0.35, 0, 0, DARK),
		b(0.8, 0.26, 0.85, 0, GREY, 0.22),
		b(1.3, 0.09, 1.3, 0.05, DARK, 0.09),
		b(0.85, 0.32, -0.9, -0.03, DARK, 0.18),
		b(0.8, 0.16, 0, 0.35, DARK, 0.16),
		b(0.18, 0.3, 0.15, -0.3, GREY, 0.15),
		b(0.15, 0.35, -0.3, -0.3, DARK, 0.15),
	},
	pistol = {
		b(0.7, 0.18, 0.05, 0.08, DARK, 0.12),
		b(0.55, 0.1, 0.02, -0.05, GREY, 0.11),
		b(0.18, 0.42, -0.2, -0.27, DARK, 0.12),
	},
	frag = {
		{ size = Vector3.new(0.4, 0.4, 0.4), at = Vector3.zero, color = OLIVE, ball = true },
		b(0.14, 0.1, 0, 0.24, GREY, 0.14),
		b(0.08, 0.32, 0.13, 0.12, GREY, 0.05),
	},
}

-- The gun's frame on the board: its +X along the wall toward the bow (+Z world), +Y up.
local function frameAt(y: number, z: number): CFrame
	local rack = Layout.ArmsRack
	local position = Vector3.new(rack.board.x1 + rack.out, y, z)
	return CFrame.fromMatrix(position, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
end

local function quiet(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.CanQuery = true -- the client's cursor ray picks the gun
end

local function buildSilhouette(model: Model, id: string, frame: CFrame)
	for index, block in SILHOUETTES[id] or SILHOUETTES.service_rifle do
		local part =
			Build.part(model, "Piece", block.size, frame * CFrame.new(block.at), block.color, {
				material = Enum.Material.SmoothPlastic,
				shape = if block.ball then Enum.PartType.Ball else nil,
			})
		quiet(part)
		if index == 1 then
			model.PrimaryPart = part
		end
	end
end

-- Swaps the silhouette for the real mesh once its template has loaded.
local function useMesh(model: Model, meshName: string, frame: CFrame)
	task.spawn(function()
		local mesh = MeshAssets.waitFor(meshName, Config.Lobby.Ship.TemplateWait)
		if not mesh then
			return
		end
		for _, child in model:GetChildren() do
			child:Destroy()
		end
		-- The held rifle's mesh runs along its Z, muzzle to -Z: turn it so the muzzle points
		-- along the gun frame's +X, like the silhouettes.
		mesh.CFrame = frame * CFrame.Angles(0, -math.pi / 2, 0)
		quiet(mesh)
		mesh.Parent = model
		model.PrimaryPart = mesh
	end)
end

function ArmsRack.build(parent: Instance)
	local rack = Layout.ArmsRack
	local folder = Build.folder(parent, "ArmsRack")
	local board = Build.box(
		folder,
		"RackBoard",
		Vector3.new(rack.board.x0, rack.board.y0, rack.board.z0),
		Vector3.new(rack.board.x1, rack.board.y1, rack.board.z1),
		BOARD,
		{ material = Enum.Material.DiamondPlate }
	)
	board.CanQuery = false

	local catalog = ArmsRoom.catalog()
	local long = catalog.primaries
	local side: { string } = table.clone(catalog.secondaries)
	for _, id in catalog.grenades do
		table.insert(side, id)
	end
	local function hang(ids: { string }, rows: { number }, z: number)
		for index, id in ids do
			local y = rows[index]
			if not y then
				warn(`[ArmsRack] no room on the rack for {id}`)
				continue
			end
			local frame = frameAt(y, z)
			local model = Instance.new("Model")
			model.Name = id
			buildSilhouette(model, id, frame)
			-- Two pegs under it.
			for _, along in { -0.45, 0.45 } do
				local peg = Build.part(
					folder,
					"Peg",
					Vector3.new(rack.out + 0.1, 0.08, 0.08),
					CFrame.new(rack.board.x1 + (rack.out + 0.1) / 2, y - 0.25, z + along),
					PEG,
					{ collide = false, shadow = false }
				)
				peg.CanQuery = false
			end
			model.Parent = folder
			local meshName = MESH[id]
			if meshName and MeshAssets.isUploaded(meshName) then
				useMesh(model, meshName, frame)
			end
		end
	end
	hang(long, rack.longRows, rack.longZ)
	hang(side, rack.sideRows, rack.sideZ)
end

return ArmsRack
