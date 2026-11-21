--!strict
-- What the two currencies pay (owner, 2026-11-10; docs/OWNER.md): merits for a mission's
-- outcome (MeritService on the match; never per kill) and tabs for a Robux pack (TabsService
-- in the lobby). Pure, unit-tested with Lune (tests/Economy.spec.luau); the amounts are the
-- caller's Config rows (Config.Merits, Config.Tabs.Products).

local Economy = {}

export type MeritPay = { Win: number, Partial: number, Loss: number, Secondary: number }
export type TabPack = { ProductId: number, Tabs: number }

-- Merits for one mission: its outcome (Rules/Handoff.outcome: "win" | "partial" | "loss";
-- anything else pays as a loss) plus the bonus for each Secondary done.
function Economy.missionMerits(outcome: string, secondaries: number, pay: MeritPay): number
	local base = if outcome == "win"
		then pay.Win
		elseif outcome == "partial" then pay.Partial
		else pay.Loss
	local done = if secondaries == secondaries then math.max(0, math.floor(secondaries)) else 0
	return math.max(0, math.floor(base + done * pay.Secondary))
end

-- The pay table for one mission: the base (Config.Merits) with the mission's own Win and
-- Partial (MissionCatalog row `Pay`), all of it times `securedShare` (rounded down) when the
-- mission's district is Secured on the city war board (loop sprint 4). The base is not changed.
function Economy.payFor(
	base: MeritPay,
	override: { Win: number?, Partial: number? }?,
	secured: boolean,
	securedShare: number
): MeritPay
	local pay: MeritPay = {
		Win = if override and override.Win then override.Win else base.Win,
		Partial = if override and override.Partial then override.Partial else base.Partial,
		Loss = base.Loss,
		Secondary = base.Secondary,
	}
	if secured then
		pay.Win = math.floor(pay.Win * securedShare)
		pay.Partial = math.floor(pay.Partial * securedShare)
		pay.Loss = math.floor(pay.Loss * securedShare)
		pay.Secondary = math.floor(pay.Secondary * securedShare)
	end
	return pay
end
-- A mission's merits with a HARLAN Order's bonus (Rules/Orders.bonus: 0.25 = +25%), rounded down.
function Economy.boosted(amount: number, bonus: number): number
	return math.floor(amount * (1 + math.max(0, bonus)))
end

-- The tabs a developer product pays, or nil when no pack has that id. ProductId 0 marks a
-- pack not created on Roblox yet and never matches.
function Economy.tabsFor(productId: number, packs: { TabPack }): number?
	if productId == 0 then
		return nil
	end
	for _, pack in packs do
		if pack.ProductId == productId then
			local tabs = pack.Tabs
			if tabs > 0 and tabs < math.huge and tabs == math.floor(tabs) then
				return tabs
			end
			return nil
		end
	end
	return nil
end

return Economy
