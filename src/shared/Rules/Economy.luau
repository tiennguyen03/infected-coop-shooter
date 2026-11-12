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
