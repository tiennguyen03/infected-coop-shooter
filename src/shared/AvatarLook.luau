--!strict
-- A figure's look as Roblox catalog items (Nova, 2026-11-11: the crew "default r15 models" with
-- "clothing/attributes as needed on each", and the soldier's new look in the lobby and the
-- match). A look is body colours plus a list of catalog asset ids; each id's kind (a 3D layered
-- shirt, a hat, a front accessory like a plate carrier, a classic 2D shirt...) is looked up
-- once on the server (MarketplaceService) and put in the right slot of a HumanoidDescription.
-- Catalog items applied this way need no ownership. Server only (the lookup and the apply).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local AvatarLook = {}

export type Look = {
	items: { number }?, -- catalog asset ids, any kind
	skin: Color3?, -- head and arms
	shirt: Color3?, -- torso, under any clothing
	trousers: Color3?, -- legs, under any clothing
	faceOf: number?, -- a player's user id: their own head, face and skin tone go on instead
}

-- Asset type id -> rigid accessory slot.
local RIGID: { [number]: Enum.AccessoryType } = {
	[8] = Enum.AccessoryType.Hat,
	[41] = Enum.AccessoryType.Hair,
	[42] = Enum.AccessoryType.Face,
	[43] = Enum.AccessoryType.Neck,
	[44] = Enum.AccessoryType.Shoulder,
	[45] = Enum.AccessoryType.Front,
	[46] = Enum.AccessoryType.Back,
	[47] = Enum.AccessoryType.Waist,
}
-- Asset type id -> layered (3D) clothing slot, and the order it wraps in (inner first). Shirts
-- go over pants (Nova, 2026-11-11: layers poking through; the waist read wrong with the pants
-- wrapped outside the shirt).
local LAYERED: { [number]: { kind: Enum.AccessoryType, order: number } } = {
	[64] = { kind = Enum.AccessoryType.TShirt, order = 1 },
	[66] = { kind = Enum.AccessoryType.Pants, order = 2 },
	[69] = { kind = Enum.AccessoryType.Shorts, order = 2 },
	[65] = { kind = Enum.AccessoryType.Shirt, order = 3 },
	[72] = { kind = Enum.AccessoryType.DressSkirt, order = 4 },
	[68] = { kind = Enum.AccessoryType.Sweater, order = 5 },
	[67] = { kind = Enum.AccessoryType.Jacket, order = 6 },
	[70] = { kind = Enum.AccessoryType.LeftShoe, order = 7 },
	[71] = { kind = Enum.AccessoryType.RightShoe, order = 7 },
}
local SHIRT_2D, PANTS_2D, FACE = 11, 12, 18
local DEFAULT_SKIN = Color3.fromRGB(176, 140, 112)

local kinds: { [number]: number } = {} -- asset id -> asset type id (0: unknown)

local function kindOf(id: number): number
	local known = kinds[id]
	if known then
		return known
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
	end)
	local kind = if ok
			and typeof(info) == "table"
			and typeof(info.AssetTypeId) == "number"
		then info.AssetTypeId
		else 0
	if kind == 0 then
		warn(`[AvatarLook] catalog item {id}: no asset type ({info})`)
	end
	kinds[id] = kind
	return kind
end

-- Looks up the kinds of `items` ahead of time (a bot's rig is built at the run's start, while
-- the insertion cutscene plays: the less it waits, the sooner it stands on its pad).
function AvatarLook.prefetch(items: { number })
	for _, id in items do
		task.spawn(kindOf, id)
	end
end

-- The look as a HumanoidDescription (yields while item kinds are looked up).
function AvatarLook.describe(look: Look): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local skin = look.skin or DEFAULT_SKIN
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = look.shirt or skin
	description.LeftLegColor = look.trousers or skin
	description.RightLegColor = look.trousers or skin
	-- A player's own face (their avatar's head and face, and its skin tone on the head and arms
	-- so they match). A failed lookup (Studio's test players, a service hiccup) keeps the default.
	if look.faceOf and look.faceOf > 0 then
		local userId = look.faceOf
		local ok, own = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		if ok and own then
			description.Head = own.Head
			description.Face = own.Face
			description.HeadColor = own.HeadColor
			description.LeftArmColor = own.LeftArmColor
			description.RightArmColor = own.RightArmColor
		end
	end
	local accessories: { any } = {}
	local items: { number } = look.items or {}
	for index, id in items do
		local kind = kindOf(id)
		local layered = LAYERED[kind]
		if layered then
			table.insert(accessories, {
				AccessoryType = layered.kind,
				AssetId = id,
				IsLayered = true,
				Order = layered.order * 10 + index,
			})
		elseif RIGID[kind] then
			table.insert(
				accessories,
				{ AccessoryType = RIGID[kind], AssetId = id, IsLayered = false }
			)
		elseif kind == SHIRT_2D then
			description.Shirt = id
		elseif kind == PANTS_2D then
			description.Pants = id
		elseif kind == FACE then
			description.Face = id
		elseif kind ~= 0 then
			warn(`[AvatarLook] catalog item {id}: asset type {kind} is not something a body wears`)
		end
	end
	if #accessories > 0 then
		local ok, err = pcall(function()
			description:SetAccessories(accessories, true)
		end)
		if not ok then
			warn(`[AvatarLook] the accessories did not fit: {err}`)
		end
	end
	return description
end

-- Puts `look` on the Humanoid's body (yields). False when Roblox refused it.
function AvatarLook.apply(humanoid: Humanoid, look: Look): boolean
	local description = AvatarLook.describe(look)
	local ok, err = pcall(function()
		humanoid:ApplyDescriptionAsync(description)
	end)
	if not ok then
		warn(
			`[AvatarLook] {humanoid.Parent and humanoid.Parent.Name or "?"}: the look did not apply ({err})`
		)
	end
	return ok
end

-- A new R15 rig wearing `look` (yields), or nil when the avatar service fails.
function AvatarLook.rig(look: Look): Model?
	local description = AvatarLook.describe(look)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		return result
	end
	warn(`[AvatarLook] no rig: {result}`)
	return nil
end

return AvatarLook
