-- Minimal test harness for Lune (tests/run.luau). A test file returns a function that
-- receives `t` and calls t.check(condition, message) for every rule it enforces.

local Harness = {}

export type T = {
	name: string,
	checks: number,
	failures: { string },
	check: (condition: any, message: string) -> (),
}

function Harness.new(name: string): T
	local t = {
		name = name,
		checks = 0,
		failures = {},
	} :: any
	function t.check(condition: any, message: string)
		t.checks += 1
		if not condition then
			table.insert(t.failures, message)
		end
	end
	return t
end

return Harness
