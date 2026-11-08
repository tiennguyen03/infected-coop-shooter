-- Test runner: `lune run tests/run` from the repository root (CI does this on every push).
-- Runs every tests/*.test.luau file; each returns a function that takes the harness `t`.
-- Exits 1 when any check fails or any test file errors.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("./lib/harness")

local names = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.test%.luau$") then
		table.insert(names, name)
	end
end
table.sort(names)

local totalChecks, totalFailures = 0, 0
for _, name in names do
	local t = Harness.new(name)
	local module = string.gsub(name, "%.luau$", "")
	local ok, err = pcall(function()
		local test = require(`./{module}`)
		test(t)
	end)
	if not ok then
		table.insert(t.failures, `test errored: {err}`)
	end
	totalChecks += t.checks
	totalFailures += #t.failures
	local status = if #t.failures == 0 then "PASS" else "FAIL"
	print(`{status} {name} ({t.checks} checks)`)
	for _, failure in t.failures do
		print(`  - {failure}`)
	end
end

print(`{totalChecks} checks, {totalFailures} failures in {#names} test files`)
if totalFailures > 0 or #names == 0 then
	process.exit(1)
end
