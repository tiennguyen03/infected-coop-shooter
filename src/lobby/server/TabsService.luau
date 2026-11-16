--!strict
-- Tabs bought with Robux (owner 2026-11-10; docs/OWNER.md: tabs are the hard currency, they
-- buy cosmetics and conveniences, never power). Foundation only: nothing prompts a purchase
-- and nothing is sold for tabs yet. The packs are Config.Tabs.Products, one developer product
-- each (ProductId 0 = not created on Roblox yet, never paid).
--
-- Roblox calls ProcessReceipt for every developer-product purchase until it is answered
-- PurchaseGranted, and may call it more than once for one purchase. A receipt is paid through
-- RecordService.grantReceipt: the PurchaseId is written onto the saved record together with
-- the tabs, so a repeat pays nothing, and PurchaseGranted is only answered once that save
-- succeeded. Anything else (the soldier left, the record is still loading, the save failed,
-- an unknown product) answers NotProcessedYet and Roblox offers the receipt again later.
-- The lobby is the only place that sets this callback: a receipt left open is paid the next
-- time the soldier is on the Carrier.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Rules.Economy)
local RecordService = require(script.Parent.RecordService)

local TabsService = {}

type Receipt = { PlayerId: number, ProductId: number, PurchaseId: string }

local function process(receipt: Receipt): Enum.ProductPurchaseDecision
	local tabs = Economy.tabsFor(receipt.ProductId, Config.Tabs.Products)
	if not tabs then
		warn(`[TabsService] receipt for product {receipt.ProductId}, which is no tabs pack`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if RecordService.grantReceipt(player, receipt.PurchaseId, tabs) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function TabsService.init()
	MarketplaceService.ProcessReceipt = function(receipt: any): Enum.ProductPurchaseDecision
		local ok, decision = pcall(process, receipt)
		if not ok then
			warn(`[TabsService] receipt {receipt.PurchaseId} failed: {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end
end

return TabsService
