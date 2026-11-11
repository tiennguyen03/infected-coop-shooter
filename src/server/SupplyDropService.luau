--!strict
-- Supply call-ins (CallInService): Lantern's crew kicks a bundle out of the door and it
-- falls onto the throw (Config.CallIns.Drop). Quiet: no lure, no wave (the pallet's
-- loud landing stays the Resupply flare's).
--   Speedball (ammo bundle, Config.CallIns.Speedball): each living player walking within
--     Radius is re-armed (LoadoutService.refillAmmo, the pallet's ammo box without cards),
--     Visits times in all; the same player again only after stepping out.
--   Aid Bag (medical drop, Config.CallIns.AidBag): every soldier (players and bots) within
--     Radius, once each: full heal, stims refilled (LoadoutService.refillStims once the
--     soldier kit has it), +Plate shield on players.
-- Both go when used up or after Lifetime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GroundUtil = require(ReplicatedStorage.Shared.GroundUtil)
local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StrikePattern = require(ReplicatedStorage.Shared.Rules.StrikePattern)
local LoadoutService = require(script.Parent.LoadoutService)
local PauseService = require(script.Parent.PauseService)
local Squad = require(script.Parent.Squad)
local Lifecycle = require(script.Parent.Lifecycle)
local WorldSounds = require(script.Parent.WorldSounds)

type Kind = "speedball" | "aid_bag"

type Drop = {
	kind: Kind,
	part: BasePart,
	label: TextLabel,
	position: Vector3,
	landed: boolean,
	expiresAt: number,
	visitsLeft: number, -- Speedball only
	inside: { [Player]: boolean }, -- Speedball: in the radius since the last re-arm
	served: { [string]: boolean }, -- Aid Bag: Squad member ids treated
}

local SupplyDropService = {}

local folder: Folder
local noticeRemote: RemoteEvent
local drops: { Drop } = {}
local lastStep = 0
local aidListeners: { (member: Squad.Member) -> () } = {}

-- Runs for every squad member an Aid Bag treats (BotService: a bot's stims back).
function SupplyDropService.onAidBag(listener: (member: Squad.Member) -> ())
	table.insert(aidListeners, listener)
end

local function remove(index: number)
	drops[index].part:Destroy()
	table.remove(drops, index)
end

local function label(part: BasePart, text: string, color: Color3): TextLabel
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(110, 24)
	board.StudsOffset = Vector3.new(0, 2.4, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 200
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = board
	board.Parent = part
	return textLabel
end

local function plain(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Material = Enum.Material.Fabric
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function speedballBody(): BasePart
	local part: BasePart = MeshAssets.clone("prop_ammo_crate") or Instance.new("Part")
	if part:IsA("Part") then
		part.Size = Vector3.new(2.6, 1.6, 1.8)
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(107, 122, 74)
	end
	return part
end

-- An olive bag with a white patch and a red cross on top (Parts; no mesh yet).
local function aidBagBody(): BasePart
	local bag = plain("AidBag", Vector3.new(2.2, 1.1, 1.5), Color3.fromRGB(92, 98, 66))
	local patch = plain("Patch", Vector3.new(1, 0.05, 1), Color3.fromRGB(230, 230, 224))
	local barA = plain("Cross", Vector3.new(0.7, 0.06, 0.22), Color3.fromRGB(176, 38, 52))
	local barB = plain("Cross", Vector3.new(0.22, 0.06, 0.7), Color3.fromRGB(176, 38, 52))
	for _, piece in { patch, barA, barB } do
		piece.Parent = bag
	end
	return bag
end

-- Moves a body and the pieces parented to it (the bag's patch) together.
local function place(part: BasePart, cframe: CFrame)
	local pieces: { [BasePart]: CFrame } = {}
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			pieces[child] = CFrame.new(0, part.Size.Y / 2 + 0.03, 0)
		end
	end
	part.CFrame = cframe
	for piece, offset in pieces do
		piece.CFrame = cframe * offset
	end
end

local function land(drop: Drop)
	drop.landed = true
	WorldSounds.at(drop.position, "callins", "pallet_land", 0.6)
end

-- CallInService: a bundle of `kind` falls onto `point`.
function SupplyDropService.drop(kind: Kind, point: Vector3, facing: Vector3): boolean
	local dropCfg = Config.CallIns.Drop
	local ground = GroundUtil.GetGroundPosition(point, 0)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local part = if kind == "speedball" then speedballBody() else aidBagBody()
	part.Name = if kind == "speedball" then "Speedball" else "AidBag"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local rest = CFrame.lookAt(ground, ground + flat) * CFrame.new(0, part.Size.Y / 2, 0)
	place(part, rest + Vector3.new(0, dropCfg.Height, 0))
	part.Parent = folder

	local cfg = if kind == "speedball" then Config.CallIns.Speedball else Config.CallIns.AidBag
	local drop: Drop = {
		kind = kind,
		part = part,
		label = label(
			part,
			if kind == "speedball" then `AMMO x{Config.CallIns.Speedball.Visits}` else "AID BAG",
			if kind == "speedball"
				then Color3.fromRGB(232, 181, 75)
				else Color3.fromRGB(230, 120, 120)
		),
		position = ground,
		landed = false,
		expiresAt = os.clock() + dropCfg.FallTime + cfg.Lifetime,
		visitsLeft = Config.CallIns.Speedball.Visits,
		inside = {},
		served = {},
	}
	table.insert(drops, drop)

	-- The fall: the body tweens, its pieces follow each frame until it lands.
	local value = Instance.new("CFrameValue")
	value.Value = part.CFrame
	value.Changed:Connect(function(cframe)
		place(part, cframe)
	end)
	local fall = TweenService:Create(
		value,
		TweenInfo.new(dropCfg.FallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = rest }
	)
	fall.Completed:Once(function()
		value:Destroy()
		if part.Parent then
			land(drop)
		end
	end)
	fall:Play()
	return true
end

local function notify(player: Player, text: string)
	noticeRemote:FireClient(player, text, Messages.Notice.Pickup)
end

local function stepSpeedball(drop: Drop)
	local radius = Config.CallIns.Speedball.Radius
	for _, player in Squad.livingOwners() do
		local member = Squad.fromPlayer(player)
		local root = member and member.root
		local near = root ~= nil and (root.Position - drop.position).Magnitude <= radius
		if not near then
			drop.inside[player] = nil
		elseif not drop.inside[player] then
			local left, served = StrikePattern.visit(drop.visitsLeft)
			if served then
				drop.visitsLeft = left
				drop.inside[player] = true
				LoadoutService.refillAmmo(player)
				notify(player, "RE-ARMED")
				drop.label.Text = `AMMO x{left}`
			end
		end
	end
end

local function stepAidBag(drop: Drop)
	local cfg = Config.CallIns.AidBag
	local refillStims = (LoadoutService :: any).refillStims
	for _, member in Squad.living() do
		local root = member.root
		local humanoid = member.humanoid
		if drop.served[member.id] or not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		if (root.Position - drop.position).Magnitude > cfg.Radius then
			continue
		end
		drop.served[member.id] = true
		humanoid.Health = humanoid.MaxHealth
		for _, listener in aidListeners do
			listener(member)
		end
		local owner = member.owner
		if owner then
			if typeof(refillStims) == "function" then
				refillStims(owner)
			end
			LoadoutService.addShield(owner, cfg.Plate)
			notify(owner, "PATCHED UP")
		end
	end
end

local function step()
	local now = os.clock()
	if PauseService.isPaused() then
		local shift = now - lastStep
		for _, drop in drops do
			drop.expiresAt += shift
		end
		lastStep = now
		return
	end
	lastStep = now
	for index = #drops, 1, -1 do
		local drop = drops[index]
		if now >= drop.expiresAt or not drop.part.Parent then
			remove(index)
		elseif drop.landed then
			if drop.kind == "speedball" then
				stepSpeedball(drop)
				if drop.visitsLeft <= 0 then
					remove(index)
				end
			else
				stepAidBag(drop)
			end
		end
	end
end

-- Bundles on the ground or falling (dev tools).
function SupplyDropService.count(): number
	return #drops
end

function SupplyDropService.reset()
	table.clear(drops)
	if folder then
		folder:ClearAllChildren()
	end
end

function SupplyDropService.init()
	Lifecycle.register("SupplyDropService", {
		onRunStart = SupplyDropService.reset,
		onPlayerRemoving = function(player: Player)
			for _, drop in drops do
				drop.inside[player] = nil
			end
		end,
	})
	folder = Instance.new("Folder")
	folder.Name = "SupplyDrops"
	folder.Parent = workspace
	noticeRemote = Remotes.get("BuffNotice")
	lastStep = os.clock()
	RunService.Heartbeat:Connect(step)
end

return SupplyDropService
