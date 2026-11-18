--!strict
-- What a Carrier desk screen shows for one piece of kit (lobby DeskScreen; docs/STYLES.md
-- section 5 > The desk screens): on the record, BUY at its price (dimmed when short, still
-- pressable so the server answers in the desk's voice), or not for issue; the desk's answer to
-- a buy; and how its sections fall into the Loadout's columns. Pure: the server decides every
-- buy (RecordService, Rules/Record); this only words it. Spec: tests/DeskOffer.spec.luau.

local DeskOffer = {}

export type State = "owned" | "buy" | "short" | "closed"

export type Offer = {
	state: State,
	canBuy: boolean, -- the BUY button is shown and sends the buy
	dim: boolean, -- the BUY button is dimmed (short)
	button: string, -- the BUY button's words
	status: string, -- the inspect panel's status line
	badge: string, -- the row's corner badge
}

-- The lines a desk answers a buy with (LobbyDesks Talk; only these three are read).
export type Lines = { bought: string, short: string, refused: string }

export type Section = { title: string, ids: { string }, column: number }

-- `owned`: on the record (bought or issued free); `price`: merits, nil when not for sale.
function DeskOffer.offer(owned: boolean, price: number?, merits: number): Offer
	if owned or price == 0 then
		return {
			state = "owned",
			canBuy = false,
			dim = false,
			button = "ON YOUR RECORD",
			status = "ON YOUR RECORD",
			badge = "ON RECORD",
		}
	end
	if price == nil then
		return {
			state = "closed",
			canBuy = false,
			dim = false,
			button = "NOT FOR ISSUE",
			status = "NOT FOR ISSUE",
			badge = "NOT FOR ISSUE",
		}
	end
	local short = merits < price
	return {
		state = if short then "short" else "buy",
		canBuy = true,
		dim = short,
		button = if short then `BUY · {price} MERITS (SHORT)` else `BUY · {price} MERITS`,
		status = "NOT ON YOUR RECORD",
		badge = `{price} MERITS`,
	}
end

-- The desk's answer: `reason` nil is a buy that went through, "short" not enough merits,
-- anything else a refusal (save down, busy).
function DeskOffer.answer(lines: Lines?, reason: string?): string
	if reason == nil then
		return if lines then lines.bought else "On your record."
	elseif reason == "short" then
		return if lines then lines.short else "Not enough merits."
	end
	return if lines then lines.refused else "Try again in a minute."
end

-- Sections grouped by their `column` (the Loadout's: 1 primary, 2 sidearm and grenade,
-- 3 call-ins), in order, with empty sections and empty columns dropped.
function DeskOffer.columns(sections: { Section }): { { Section } }
	local byColumn: { [number]: { Section } } = {}
	local numbers: { number } = {}
	for _, section in sections do
		if #section.ids == 0 then
			continue
		end
		local list = byColumn[section.column]
		if not list then
			list = {}
			byColumn[section.column] = list
			table.insert(numbers, section.column)
		end
		table.insert(list, section)
	end
	table.sort(numbers)
	local out: { { Section } } = {}
	for _, number in numbers do
		table.insert(out, byColumn[number])
	end
	return out
end

return DeskOffer
