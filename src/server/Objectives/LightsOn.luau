--!strict
-- Lights On (shared side objective): hold E at the generator; the nearest lamp posts light
-- for the rest of the mission (row.MaxLamps within row.Radius, no shadows: STYLES light
-- budget). Bots guard the player at the generator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local LightsOn = {}

local LAMP_POST = "env_lamp_post" -- the dressing piece (Missions, MeshAssets)

function LightsOn.new(context: Types.Context): Types.Objective
	local row = context.row
	local switch = Kit.point(context.folder, "GeneratorSwitch", context.position)
	Kit.marker(switch, context, nil, 6)
	local lit: { Instance } = {} -- lights hang on the map's own lamp posts, not in the folder

	local function light()
		local posts: { BasePart } = {}
		local dressing = workspace:FindFirstChild("Dressing")
		for _, item in if dressing then dressing:GetDescendants() else {} do
			if
				item:IsA("BasePart")
				and item.Name == LAMP_POST
				and (item.Position - context.position).Magnitude <= (row.Radius or 320)
			then
				table.insert(posts, item)
			end
		end
		table.sort(posts, function(a, b)
			return (a.Position - context.position).Magnitude
				< (b.Position - context.position).Magnitude
		end)
		for index = 1, math.min(#posts, row.MaxLamps or 5) do
			local post = posts[index]
			local head = Instance.new("Attachment")
			head.Name = "ObjectiveLamp"
			head.Position = Vector3.new(0, post.Size.Y / 2 - 0.6, 0)
			local lamp = Instance.new("PointLight")
			lamp.Color = Config.Objectives.LampColor
			lamp.Range = row.LampRange or 48
			lamp.Brightness = row.LampBrightness or 1.6
			lamp.Shadows = false
			lamp.Parent = head
			head.Parent = post
			table.insert(lit, head)
		end
	end

	Kit.prompt(switch, "Start the generator", "Generator", row.Hold or 8, function()
		for _, child in switch:GetChildren() do
			child:Destroy()
		end
		light()
		context.complete()
	end)

	return {
		begin = function() end,
		step = function() end,
		progress = function(): Types.Progress
			return {
				step = `Hold {Kit.InteractLabel} at the generator for {row.Hold or 8}s`,
				done = 0,
				total = 0,
				unit = "",
			}
		end,
		position = function()
			return context.position
		end,
		cleanup = function()
			for _, head in lit do
				head:Destroy()
			end
			table.clear(lit)
		end,
	}
end

return LightsOn
