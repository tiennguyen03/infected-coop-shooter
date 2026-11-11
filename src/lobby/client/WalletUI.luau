--!strict
-- The wallet on the Carrier (owner, 2026-11-11): the soldier's merits and tabs, always on
-- screen, at the right end of the top bar. That strip is Roblox's own (ScreenInsets
-- TopbarSafeInsets: the free part of it, inside the device's safe area), so the readout sits
-- above every lobby screen (the rack's header, the desk panels, the Loadout's BACK, the
-- player list) and overlaps none of them. It follows the record (RecordClient) and counts
-- to a new balance when one changes (shared WalletReadout).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WalletReadout = require(ReplicatedStorage.Shared.WalletReadout)
local HudTheme = require(script.Parent.HudTheme)
local RecordClient = require(script.Parent.RecordClient)

local WalletUI = {}

function WalletUI.init()
	local gui = HudTheme.gui("WalletUI", 4)
	gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	gui.Enabled = false -- until the record arrives
	local readout = WalletReadout.new(gui)
	readout.frame.AnchorPoint = Vector2.new(1, 0.5)
	readout.frame.Position = UDim2.new(1, -HudTheme.Margin, 0.5, 0)
	HudTheme.parent(gui)

	local function refresh()
		if RecordClient.loaded() then
			readout.set(RecordClient.merits(), RecordClient.tabs())
			gui.Enabled = true
		end
	end
	RecordClient.Changed:Connect(refresh)
	refresh()
end

return WalletUI
