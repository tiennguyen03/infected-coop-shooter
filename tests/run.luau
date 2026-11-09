--!strict
-- Unit tests for the pure game rules (docs/ARCHITECTURE.md F5), run outside Studio:
--   lune run tests/run
-- Every tests/*.spec.luau returns { [testName]: () -> () }; a test fails by erroring.
-- The runner prints each failure and exits 1 when any test failed (CI reads the code).

local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0
local files = fs.readDir("tests")
table.sort(files)
for _, file in files do
	if string.sub(file, -10) == ".spec.luau" then
		local name = string.sub(file, 1, -6)
		local ok, specs = pcall(require, "./" .. name)
		if not ok then
			failed += 1
			print(`FAIL {file}: could not load: {specs}`)
			continue
		end
		local names = {}
		for testName in specs :: { [string]: () -> () } do
			table.insert(names, testName)
		end
		table.sort(names)
		for _, testName in names do
			local testOk, err = pcall((specs :: any)[testName])
			if testOk then
				passed += 1
			else
				failed += 1
				print(`FAIL {name} > {testName}: {err}`)
			end
		end
	end
end

print(`{passed} passed, {failed} failed`)
-- No specs found (a moved folder, a wrong working directory) is a failure, not a pass.
process.exit(if failed > 0 or passed == 0 then 1 else 0)
