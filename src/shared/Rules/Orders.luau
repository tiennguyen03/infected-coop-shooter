--!strict
-- HARLAN Orders (loop sprint 4; design: docs/superpowers/specs/2026-11-20-game-loop-design.md
-- section 7; tests/Orders.spec.luau): one shared goal at a time for every server, e.g. "Push
-- Mile 14 to 50% by Sunday". Data rows (`Config.War.Orders`) with a window in os.time()
-- seconds, so a new order is a row, never code. While one runs its district's mission card is
-- gold on the Mission Board and its missions pay `PayBonus` more merits (MeritService).
-- Not built yet: the +merits for everyone when an order is reached (needs a claimed list on
-- the record).

local Orders = {}

export type Order = {
	Id: string,
	District: string, -- Config.Containment.Districts name
	Target: number, -- percent to reach
	From: number, -- os.time(): starts (included)
	To: number, -- os.time(): ends (excluded)
	PayBonus: number, -- 0.25 = +25% merits on its district's missions
	Text: string, -- Control's words on the board, plain
}

-- The order running at `now`, or nil.
function Orders.active(rows: { Order }, now: number): Order?
	for _, order in rows do
		if now >= order.From and now < order.To then
			return order
		end
	end
	return nil
end

-- The extra share of merits a mission in `district` earns under `order` (0 for none).
function Orders.bonus(order: Order?, district: string): number
	if order and order.District == district then
		return order.PayBonus
	end
	return 0
end

-- Whether the order's district stands at its target (`percent` from the war board).
function Orders.reached(order: Order, percent: number): boolean
	return percent >= order.Target
end

return Orders
