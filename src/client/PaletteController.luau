--!strict
-- Every low-poly mesh (players, bots, the Infected, props) is coloured by one shared palette
-- texture (MeshAssets.PALETTE_TEXTURE). Roblox can refuse that image the first time a client
-- asks for it ("Asset content representation is being generated"), and a MeshPart never
-- retries a failed texture: the bodies then show their bare base colour (owner report: black
-- bots, a ghost player, in a separate-window playtest). This keeps asking until the image
-- loads, then re-applies it once to every part already using it; parts made later load it
-- normally because the image is ready by then.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MeshAssets"))

local PaletteController = {}

local RETRY_SECONDS = 2
local MAX_TRIES = 30

local function loaded(texture: string): boolean
	local probe = Instance.new("Decal")
	probe.Texture = texture
	local ok = false
	pcall(function()
		ContentProvider:PreloadAsync({ probe }, function(_, status)
			ok = status == Enum.AssetFetchStatus.Success
		end)
	end)
	probe:Destroy()
	return ok
end

-- Re-assigning the same id does not refetch; clearing it first does.
local function reapply(texture: string): number
	local count = 0
	for _, part in workspace:GetDescendants() do
		if part:IsA("MeshPart") and part.TextureID == texture then
			part.TextureID = ""
			part.TextureID = texture
			count += 1
		end
	end
	return count
end

function PaletteController.init()
	task.spawn(function()
		local texture = MeshAssets.PALETTE_TEXTURE
		for _ = 1, MAX_TRIES do
			if loaded(texture) then
				-- Give the first characters and dressing a moment to exist, then refresh.
				task.wait(1)
				reapply(texture)
				return
			end
			task.wait(RETRY_SECONDS)
		end
		warn("[PaletteController] the palette texture never loaded; bodies show their base colour")
	end)
end

return PaletteController
