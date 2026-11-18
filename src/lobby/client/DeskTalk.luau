--!strict
-- The talk panel every Carrier desk opens with (F on its prompt; LobbyDesks `talk`): the desk
-- as a "//" header with who stands there, their line in quotes, and the three numbered choices
-- (1 their kit, 2 a question, 3 leave). One build for every host (DeskDialogUI, ArmsRackUI,
-- LoadmasterUI) in the menu style of the Loadout screen (docs/STYLES.md section 5 > The desk
-- screens): the near-black red field with a red 1 px box, rows that turn cream under the
-- mouse or a gamepad's selection. The host owns what the choices do and when it shows.

local HudTheme = require(script.Parent.HudTheme)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LobbyDesks = require(ReplicatedStorage.Lobby.LobbyDesks)

local DeskTalk = {}

local C = HudTheme.Color
local WIDTH = 560

export type Panel = {
	frame: Frame,
	title: TextLabel,
	line: TextLabel,
	choices: { TextButton },
	show: (desk: LobbyDesks.Desk) -> (), -- the header and the choices' words
	say: (text: string) -> (), -- their line, in quotes
}

local function choice(parent: Instance, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 40)
	b.LayoutOrder = order
	b.BackgroundColor3 = C.Track
	b.BackgroundTransparency = 0.35
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Font = HudTheme.Font.Line
	b.TextSize = 18
	b.TextColor3 = C.Text
	b.RichText = true
	b.TextXAlignment = Enum.TextXAlignment.Left
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.White
	stroke.Transparency = HudTheme.OutlineTransparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 14)
	inset.Parent = b
	-- Prototype 2's highlight: the row under the mouse or the gamepad's selection goes cream.
	local function lit(on: boolean)
		b.BackgroundColor3 = if on then C.MenuSelect else C.Track
		b.BackgroundTransparency = if on then 0 else 0.35
		b.TextColor3 = if on then C.MenuSelectText else C.Text
	end
	b.MouseEnter:Connect(function()
		lit(true)
	end)
	b.MouseLeave:Connect(function()
		lit(false)
	end)
	b.SelectionGained:Connect(function()
		lit(true)
	end)
	b.SelectionLost:Connect(function()
		lit(false)
	end)
	b.Parent = parent
	return b
end

function DeskTalk.new(gui: ScreenGui): Panel
	local frame = HudTheme.rect(gui, UDim2.fromOffset(WIDTH, 0), C.MenuBack, 0.06)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -200)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Red
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = frame

	local title = HudTheme.label(frame, { size = 22, font = HudTheme.Font.Headline, rich = true })
	title.LayoutOrder = 1
	local line = HudTheme.label(frame, { size = 18, font = HudTheme.Font.Body })
	line.LayoutOrder = 2
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Size = UDim2.fromScale(1, 0)
	line.TextWrapped = true
	local choices = { choice(frame, 3), choice(frame, 4), choice(frame, 5) }

	local function numbered(index: number, text: string): string
		return `{HudTheme.tint(`{index}.`, C.Yellow)}  {text}`
	end

	return {
		frame = frame,
		title = title,
		line = line,
		choices = choices,
		show = function(desk: LobbyDesks.Desk)
			title.Text = `//{desk.title}  {HudTheme.tint(string.upper(desk.who), C.TextDim)}`
			local said = desk.talk
			choices[1].Text = numbered(1, said.open)
			choices[2].Text = numbered(2, said.ask)
			choices[3].Text = numbered(3, said.leave)
		end,
		say = function(text: string)
			line.Text = `"{text}"`
		end,
	}
end

return DeskTalk
