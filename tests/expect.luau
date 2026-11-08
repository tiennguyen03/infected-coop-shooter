--!strict
-- Minimal assertions for the rule specs.

local expect = {}

function expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function expect.near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{label or "value"}: expected {expected} +- {tolerance}, got {actual}`, 2)
	end
end

return expect
