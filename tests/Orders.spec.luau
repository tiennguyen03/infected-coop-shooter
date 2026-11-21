--!strict
-- HARLAN Orders (src/shared/Rules/Orders.luau; loop sprint 4): one shared goal at a time,
-- data rows with a window. Its district's missions pay a bonus while it runs.

local Orders = require("../src/shared/Rules/Orders")

local function eq(actual: unknown, expected: unknown, what: string)
	if actual ~= expected then
		error(`{what}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local ROWS: { Orders.Order } = {
	{
		Id = "a",
		District = "MILE 14",
		Target = 50,
		From = 100,
		To = 200,
		PayBonus = 0.25,
		Text = "Push Mile 14 to 50%.",
	},
	{
		Id = "b",
		District = "DELTA",
		Target = 75,
		From = 200,
		To = 300,
		PayBonus = 0.25,
		Text = "Hold Delta.",
	},
}

return {
	["the order running now"] = function()
		eq(Orders.active(ROWS, 150) and (Orders.active(ROWS, 150) :: any).Id, "a", "a")
		eq(Orders.active(ROWS, 250) and (Orders.active(ROWS, 250) :: any).Id, "b", "b")
	end,

	["none before, between or after"] = function()
		eq(Orders.active(ROWS, 50), nil, "before")
		eq(Orders.active(ROWS, 300), nil, "at the end")
		eq(Orders.active({}, 150), nil, "no rows")
	end,

	["the window includes its start and excludes its end"] = function()
		eq(Orders.active(ROWS, 100) and (Orders.active(ROWS, 100) :: any).Id, "a", "start")
		eq(
			Orders.active(ROWS, 200) and (Orders.active(ROWS, 200) :: any).Id,
			"b",
			"a's end is b's start"
		)
	end,

	["the bonus is for the order's district only"] = function()
		local order = Orders.active(ROWS, 150)
		eq(Orders.bonus(order, "MILE 14"), 0.25, "mile 14")
		eq(Orders.bonus(order, "DELTA"), 0, "delta")
		eq(Orders.bonus(nil, "MILE 14"), 0, "no order")
	end,

	["reached when the district is at the target"] = function()
		local order = Orders.active(ROWS, 150) :: Orders.Order
		eq(Orders.reached(order, 49.9), false, "short")
		eq(Orders.reached(order, 50), true, "at")
	end,
}
