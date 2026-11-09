--!strict
-- The magazine rules (docs/ARCHITECTURE.md F5): pure, no Roblox APIs, unit-tested with Lune
-- (tests/Magazine.spec.luau). LoadoutService owns the per-player state and calls these.

local Magazine = {}

-- A shot needs a round loaded and no reload running.
function Magazine.canFire(mag: number, reloading: boolean): boolean
	return not reloading and mag > 0
end

-- A reload starts only when it would load something.
function Magazine.canReload(mag: number, reserve: number, size: number, reloading: boolean): boolean
	return not reloading and mag < size and reserve > 0
end

-- The rounds after a reload: tops the magazine up from the reserve. Returns (mag, reserve).
function Magazine.reload(mag: number, reserve: number, size: number): (number, number)
	local taken = math.min(size - mag, reserve)
	return mag + taken, reserve - taken
end

return Magazine
