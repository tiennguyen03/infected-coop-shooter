--!strict
-- Resolves animation ids for the clip names in Config.Animations. A published clip has its
-- asset id in Config; an unpublished one is previewed in Studio from the retargeted clip
-- table (AnimationBuilder), registered once on the server and handed to clients through
-- attributes on ReplicatedStorage.Shared. Outside Studio an unpublished clip has no id and
-- callers fall back to whatever they did before (stock walk, no clip).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(script.Parent.Attributes)
local Config = require(script.Parent.Config)

local Animations = {}

local previewIds: { [string]: string } = {}

local function shared(): Instance
	return ReplicatedStorage:WaitForChild("Shared")
end

-- The id to play for a clip name, or nil when nothing is available.
function Animations.getId(clip: string): string?
	local id = Config.Animations.Ids[clip]
	if id and id ~= "" then
		return id
	end
	if previewIds[clip] then
		return previewIds[clip]
	end
	local attribute = shared():GetAttribute(Attributes.animPreview(clip))
	if typeof(attribute) == "string" and attribute ~= "" then
		return attribute
	end
	return nil
end

-- Loads a clip onto an Animator. Returns nil when the clip has no id.
function Animations.load(
	animator: Animator,
	clip: string,
	priority: Enum.AnimationPriority?
): AnimationTrack?
	local id = Animations.getId(clip)
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.Name = clip
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	if priority then
		track.Priority = priority
	end
	return track
end

-- Server, Studio only: registers every unpublished clip for preview and publishes the
-- temporary ids to clients.
function Animations.init()
	if not RunService:IsServer() or not RunService:IsStudio() then
		return
	end
	local AnimationBuilder = require(script.Parent.AnimationBuilder)
	for clip: string, id: string in Config.Animations.Ids :: { [string]: string } do
		if id ~= "" then
			continue
		end
		local ok, previewId = pcall(AnimationBuilder.previewId, clip)
		if ok and previewId then
			previewIds[clip] = previewId
			shared():SetAttribute(Attributes.animPreview(clip), previewId)
		else
			warn(`[Animations] no preview for clip "{clip}": {tostring(previewId)}`)
		end
	end
end

return Animations
