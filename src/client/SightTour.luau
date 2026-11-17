--!strict
-- Dev tool (Studio / creator only): the sight tour. F10, the dev panel's "Sight tour" row, or
-- `require(...Client.SightTour).start()` puts every gun in hand in turn (DevCommand
-- SetWeapon), in first person: a moment at the hip, then down its sights, held. A line at the
-- top names the gun and what its row says the view should be, so every sight picture can be
-- checked in about a minute. F10 again (or `stop()`) ends it and gives the first gun back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Attributes"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Sight =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Sight"))
local WeaponDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDefinitions"))
local CameraController = require(script.Parent.CameraController)
local WeaponController = require(script.Parent.WeaponController)

local CREATOR_USER_ID = 67169996
local KEY = Enum.KeyCode.F10
local HIP_SECONDS = 1.5 -- the new gun at the hip (its mesh loads, the swap settles)
local AIM_SECONDS = 4 -- down its sights
local HIP_FOV = 70

local SightTour = {}

local running = 0 -- the current tour's number; 0 = none (a newer tour or stop() ends an older)
local label: TextLabel? = nil

local function allowed(): boolean
	return RunService:IsStudio() or Players.LocalPlayer.UserId == CREATOR_USER_ID
end

local function line(): TextLabel
	local existing = label
	if existing then
		return existing
	end
	do
		local gui = Instance.new("ScreenGui")
		gui.Name = "SightTour"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 200
		local made = Instance.new("TextLabel")
		made.AnchorPoint = Vector2.new(0.5, 0)
		made.Position = UDim2.new(0.5, 0, 0, 70)
		made.Size = UDim2.fromOffset(900, 24)
		made.BackgroundTransparency = 1
		made.Font = Enum.Font.GothamBold
		made.TextSize = 16
		made.TextColor3 = Color3.fromRGB(240, 240, 240)
		made.TextStrokeTransparency = 0.55
		made.Parent = gui
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		label = made
		return made
	end
end

local function say(text: string?)
	local current = line()
	current.Text = text or ""
	current.Visible = text ~= nil
end

function SightTour.stop()
	if running == 0 then
		return
	end
	running = 0
	WeaponController.holdAim(false)
	say(nil)
end

function SightTour.start()
	if not allowed() then
		return
	end
	running += 1
	local tour = running
	local player = Players.LocalPlayer
	local remote = Remotes.get("DevCommand")
	local before = player:GetAttribute(Attributes.Weapon)
	local wasFirstPerson = CameraController.isFirstPerson()
	task.spawn(function()
		local ids = WeaponDefinitions.allIds()
		for index, id in ids do
			if running ~= tour then
				return
			end
			local weapon = WeaponDefinitions.get(id)
			local sight = weapon.Sight
			local about = string.format(
				"SIGHT TOUR %d/%d  %s (%s)  %s, %.2gx (FOV %.0f), eye %.2f behind the rear sight",
				index,
				#ids,
				weapon.Name,
				weapon.Designation,
				sight.Kind,
				sight.Zoom,
				Sight.fov(HIP_FOV, sight.Zoom),
				sight.EyeRelief
			)
			WeaponController.holdAim(false)
			remote:FireServer("SetWeapon", id)
			CameraController.setFirstPerson(true)
			say(about .. "  [hip]")
			task.wait(HIP_SECONDS)
			if running ~= tour then
				return
			end
			WeaponController.holdAim(true)
			say(about .. "  [sights]")
			task.wait(AIM_SECONDS)
		end
		if running ~= tour then
			return
		end
		SightTour.stop()
		if typeof(before) == "string" then
			remote:FireServer("SetWeapon", before)
		end
		CameraController.setFirstPerson(wasFirstPerson)
	end)
end

function SightTour.toggle()
	if running ~= 0 then
		SightTour.stop()
	else
		SightTour.start()
	end
end

function SightTour.init()
	if not allowed() then
		return
	end
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == KEY then
			SightTour.toggle()
		end
	end)
end

return SightTour
