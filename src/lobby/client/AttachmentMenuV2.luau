--!strict
-- The Loadmaster's EDIT for a gun on attachment system v2 (Nova, 2026-11-20; the M16A4 first):
-- the right-hand column of GunsmithUI, extended from one or two slots to every slot the gun
-- takes (WeaponDefinitions.slots: Optic, Barrel, Muzzle, Magazine, Ammo type, Underbarrel,
-- Stock). Same look as the optic list it grew from (HudTheme, GunsmithUI's buttons):
--   "X/Y ATTACHMENTS UNLOCKED" for the gun at the top, then a scrolling list of slot rows: the
--   slot, what is fitted, and its own "X/Y". Click a slot to open its options: each shows its
--   name, what it changes ("+15% range, +10% recoil"; an ammo type its round), and EQUIPPED,
--   OWNED, or greyed out with its merit price and BUY.
-- Everything goes through the server on the `Attachment` remote (AttachmentService): the list
-- changes only when it answers, and a refusal (a clash, not enough merits) is said under the
-- gun. Stats only: the gun's model does not change yet (but the optic and the suppressor show,
-- as before). Rows are all built at once and shown or hidden, so GunsmithUI's ZIndex pass
-- covers them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmmoTypes = require(ReplicatedStorage.Shared.Attachments.AmmoTypes)
local AttachmentMerge = require(ReplicatedStorage.Shared.Rules.AttachmentMerge)
local AttachmentOptions = require(ReplicatedStorage.Shared.Attachments.Options)
local AttachmentUnlock = require(ReplicatedStorage.Shared.Rules.AttachmentUnlock)
local GunCompatibility = require(ReplicatedStorage.Shared.Rules.GunCompatibility)
local Schema = require(ReplicatedStorage.Shared.Attachments.Schema)
local Messages = require(ReplicatedStorage.Shared.Messages)
local Record = require(ReplicatedStorage.Shared.Rules.Record)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local HudTheme = require(script.Parent.HudTheme)

local AttachmentMenuV2 = {}

export type Args = {
	parent: Instance,
	gunId: string,
	position: Vector2,
	size: Vector2,
	fitted: { [string]: string }, -- [slot] = id, kept up to date as the server answers
	describe: TextLabel, -- the line under the gun
	onFitted: (slot: string) -> (), -- after the server fitted something (show the gun again)
}

local C = HudTheme.Color
local SLOT_ROW = 34
local OPTION_ROW = 44
local BUY_WIDTH = 92

-- What a refusal says (AttachmentService / Rules/AttachmentUnlock reasons).
local REFUSED: { [string]: string } = {
	short = "Not enough merits for that one yet.",
	owned = "Already on your record.",
	locked = "Unlock it first.",
	["incompatible gun"] = "That does not fit this gun.",
	["wrong slot"] = "That does not go there.",
	["wrong caliber"] = "Wrong caliber for this gun.",
	loading = "Your record is still loading. Try again in a moment.",
	busy = "The Loadmaster is busy. Try again in a moment.",
	unknown = "The Loadmaster does not know that one.",
}

local function nameOf(id: string): string
	local option = AttachmentOptions.get(id)
	if option then
		return option.displayName
	end
	local ammo = AmmoTypes.get(id)
	return if ammo then ammo.displayName else id
end

local function rowOf(id: string): any
	return AttachmentOptions.get(id) or AmmoTypes.get(id)
end

-- `id` was refused for `reason`: a clash says why when either row does (its ClashReasons, the
-- Mossberg's choke and slugs), and what to take off.
local function refusal(id: unknown, reason: string?): string
	local text = tostring(reason)
	local other = string.match(text, "^incompatible:(.+)$")
	if other then
		local why = if typeof(id) == "string"
			then AttachmentMerge.clashReason(rowOf(id), rowOf(other))
			else nil
		local fix = `Take the {nameOf(other)} off first.`
		return if why then `{why} {fix}` else `Does not fit with the {nameOf(other)}. {fix}`
	end
	return REFUSED[text] or `Refused ({text}).`
end

local function button(parent: Instance, text: string, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Size = size
	b.BackgroundColor3 = C.Track
	b.BackgroundTransparency = 0.35
	b.BorderSizePixel = 0
	b.Font = HudTheme.Font.Line
	b.TextSize = 14
	b.TextColor3 = C.Text
	b.Text = text
	b.Parent = parent
	return b
end

-- Builds the column; returns a function that disconnects it (GunsmithUI destroys the frame).
function AttachmentMenuV2.build(args: Args): () -> ()
	local gunId = args.gunId
	local fitted = args.fitted
	local describe = args.describe
	local catalog = WeaponDefinitions.attachmentCatalog()
	local remote = Remotes.get("Attachment")
	local slots = WeaponDefinitions.slots(gunId)
	local family = WeaponDefinitions.get(gunId).Family

	-- What the server says is on the record (nil until it answers).
	local owned: { string }? = nil
	local function record(): Record.Record
		local r = Record.new(0)
		r.owned = owned or {}
		return r
	end

	local total = HudTheme.label(args.parent, { text = "", size = 12, color = C.TextDim })
	total.Position = UDim2.fromOffset(args.position.X, args.position.Y)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(args.position.X, args.position.Y + 20)
	scroll.Size = UDim2.fromOffset(args.size.X, args.size.Y - 20)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = C.TextDim
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = args.parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	local width = args.size.X - 8
	local painters: { () -> () } = {}
	local function repaint()
		for _, paint in painters do
			paint()
		end
	end
	local open: string? = nil
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	for _, slot in slots do
		local ids = AttachmentUnlock.idsIn(catalog, gunId, slot.id)
		local hasBase = false
		for _, id in ids do
			local entry = AttachmentOptions.get(id) or AmmoTypes.get(id)
			hasBase = hasBase or (entry ~= nil and entry.base)
		end
		-- A slot without an issued part (the Optic, the Underbarrel) starts with NONE.
		local list: { string } = if hasBase then {} else { "" }
		for _, id in ids do
			table.insert(list, id)
		end

		-- The slot row: name, what is fitted, X/Y.
		local head = button(scroll, "", UDim2.fromOffset(width, SLOT_ROW))
		head.LayoutOrder = nextOrder()
		head.TextXAlignment = Enum.TextXAlignment.Left
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.Parent = head
		local count = HudTheme.label(head, { text = "", size = 12, color = C.TextDim })
		count.AnchorPoint = Vector2.new(1, 0.5)
		count.Position = UDim2.new(1, -10, 0.5, 0)
		head.Activated:Connect(function()
			open = if open == slot.id then nil else slot.id
			repaint()
		end)
		table.insert(painters, function()
			local current = fitted[slot.id]
			local shown = if current
				then nameOf(current)
				elseif hasBase then (function(): string
					for _, id in ids do
						local entry = AttachmentOptions.get(id) or AmmoTypes.get(id)
						if entry and entry.base then
							return entry.displayName
						end
					end
					return "None"
				end)()
				else "None"
			local arrow = if open == slot.id then "v" else ">"
			head.Text = `{arrow}  {string.upper(Schema.nameOn(slot, family))}  ·  {shown}`
			local have, all = AttachmentUnlock.unlockedIn(record(), gunId, slot.id, catalog)
			count.Text = if owned then `{have}/{all}` else `-/{all}`
			local isOpen = open == slot.id
			head.BackgroundColor3 = if isOpen then C.MenuSelect else C.Track
			head.BackgroundTransparency = if isOpen then 0 else 0.35
			head.TextColor3 = if isOpen then C.MenuSelectText else C.Text
		end)

		-- Its options, shown while the slot is open.
		for _, id in list do
			local option = AttachmentOptions.get(id)
			local ammo = AmmoTypes.get(id)
			local cost = if option then option.meritCost elseif ammo then ammo.meritCost else 0
			local row = button(scroll, "", UDim2.fromOffset(width, OPTION_ROW))
			row.LayoutOrder = nextOrder()
			row.Visible = false
			local name = HudTheme.label(row, {
				text = if id == "" then "NONE" else string.upper(nameOf(id)),
				size = 14,
				color = C.Text,
			})
			name.Position = UDim2.fromOffset(22, 5)
			local line = HudTheme.label(row, {
				text = if option
					then AttachmentOptions.summary(option)
					elseif ammo then AmmoTypes.summary(ammo)
					else "Nothing fitted.",
				size = 11,
				color = C.TextDim,
			})
			line.Position = UDim2.fromOffset(22, 24)
			local tag = HudTheme.label(row, { text = "", size = 12, color = C.TextDim })
			tag.AnchorPoint = Vector2.new(1, 0.5)
			tag.Position = UDim2.new(1, -10, 0.5, 0)
			local buy: TextButton? = nil
			if cost > 0 then
				local b = button(row, `BUY · {cost}`, UDim2.fromOffset(BUY_WIDTH, OPTION_ROW - 14))
				b.AnchorPoint = Vector2.new(1, 0.5)
				b.Position = UDim2.new(1, -6, 0.5, 0)
				b.BackgroundColor3 = C.Red
				b.BackgroundTransparency = 0
				b.TextSize = 12
				b.Activated:Connect(function()
					describe.Text = `Signing the {nameOf(id)} to your record...`
					remote:FireServer(Messages.Attachment.Unlock, id)
				end)
				buy = b
			end
			row.MouseEnter:Connect(function()
				local entry = option or ammo
				describe.Text = if entry
					then `{entry.description}{if cost > 0
						then ` {cost} merits, yours for good.`
						else ""}`
					else `Nothing on the {string.lower(Schema.nameOn(slot, family))}.`
			end)
			row.Activated:Connect(function()
				if
					id ~= ""
					and AttachmentUnlock.state(record(), fitted[slot.id], id, catalog)
						== "locked"
				then
					describe.Text = `Locked: {cost} merits. Press BUY.`
					return
				end
				remote:FireServer(Messages.Attachment.Equip, gunId, slot.id, id)
			end)
			table.insert(painters, function()
				row.Visible = open == slot.id
				local state: AttachmentUnlock.State = if id ~= ""
					then AttachmentUnlock.state(record(), fitted[slot.id], id, catalog)
					elseif fitted[slot.id] == nil then "equipped"
					else "owned"
				local locked = state == "locked"
				local lit = state == "equipped"
				row.BackgroundColor3 = if lit then C.MenuSelect else C.Track
				row.BackgroundTransparency = if lit then 0 elseif locked then 0.6 else 0.35
				name.TextColor3 = if lit
					then C.MenuSelectText
					elseif locked then C.TextDim
					else C.Text
				line.TextColor3 = if lit then C.MenuSelectText else C.TextDim
				tag.Text = if lit then "EQUIPPED" elseif locked then "" else "OWNED"
				tag.TextColor3 = if lit then C.MenuSelectText else C.TextDim
				if buy then
					buy.Visible = locked and owned ~= nil
				end
			end)
		end
	end

	-- The gun's total.
	table.insert(painters, function()
		local have, all = 0, 0
		for _, slot in slots do
			local h, a = AttachmentUnlock.unlockedIn(record(), gunId, slot.id, catalog)
			have += h
			all += a
		end
		total.Text = if owned
			then `{have}/{all} ATTACHMENTS UNLOCKED`
			else `-/{all} ATTACHMENTS UNLOCKED`
	end)

	local events = remote.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if kind == Messages.Attachment.Owned and typeof(a) == "table" then
			owned = a
			repaint()
		elseif kind == Messages.Attachment.Equipped and a == gunId and typeof(b) == "string" then
			local now: string? = if typeof(c) == "string" and c ~= "" then c else nil
			(fitted :: any)[b] = now
			local said = if now then `{nameOf(now)} fitted.` else "Back to the issued part."
			-- Allowed but worth a word (Rules/GunCompatibility: subsonic without a suppressor).
			local warnings = GunCompatibility.warnings(gunId, fitted, catalog :: any)
			describe.Text = if #warnings > 0 then `{said} {table.concat(warnings, " ")}` else said
			args.onFitted(b)
			repaint()
		elseif kind == Messages.Attachment.Refused then
			describe.Text = refusal(a, b)
		end
	end)
	remote:FireServer(Messages.Attachment.Owned)
	repaint()

	return function()
		events:Disconnect()
	end
end

return AttachmentMenuV2
