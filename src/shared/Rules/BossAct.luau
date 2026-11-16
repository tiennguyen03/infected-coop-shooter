--!strict
-- The Warden as the main objective's last act (docs/PROGRESSION.md > The Warden in the main
-- objective): when he comes, what is left, when the mission is done. Pure, unit-tested with
-- Lune (tests/BossAct.spec.luau). ObjectiveService feeds it the objective's progress, the
-- row's `Boss` block and Config.Objectives.Boss.

local BossAct = {}

export type Step = "work" | "blocked" | "kill"

-- The row's Boss block over the defaults, field by field (a row names only what differs).
function BossAct.resolve(block: { [string]: any }?, defaults: { [string]: any }): { [string]: any }
	local settings = table.clone(defaults)
	if block then
		for key, value in block do
			settings[key] = value
		end
	end
	return settings
end

-- 0..1 of the objective's work (0 when it has nothing to count yet).
function BossAct.share(done: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.clamp(done / total, 0, 1)
end

-- Whether he comes now: once, when the work reaches `at` of its share, or at the latest when
-- the work is finished.
function BossAct.shouldCome(at: number, share: number, workDone: boolean, came: boolean): boolean
	if came then
		return false
	end
	return workDone or share >= at
end

-- The mission is complete only when the objective's work is finished and he is down.
function BossAct.complete(workDone: boolean, bossDown: boolean): boolean
	return workDone and bossDown
end

-- What the HUD says now: the objective's own step, that he is stopping it, or only him left.
function BossAct.step(workDone: boolean, bossDown: boolean, contested: boolean): Step
	if workDone and not bossDown then
		return "kill"
	end
	if contested and not bossDown then
		return "blocked"
	end
	return "work"
end

-- Whether (bx, bz) stands within `radius` of (ax, az) on the ground plane (radius 0: never).
function BossAct.inside(ax: number, az: number, bx: number, bz: number, radius: number): boolean
	if radius <= 0 then
		return false
	end
	local dx, dz = bx - ax, bz - az
	return dx * dx + dz * dz <= radius * radius
end

-- A carried item's share: how much of the way from the start (`full` studs) is behind it
-- (`left` studs still to go).
function BossAct.carried(full: number, left: number): number
	if full <= 0 then
		return 1
	end
	return math.clamp(1 - left / full, 0, 1)
end

-- Whether a moment at `at` (os.clock; 0 = never) is within `hold` seconds of `now`.
function BossAct.recently(now: number, at: number, hold: number): boolean
	return at > 0 and now - at <= hold
end

return BossAct
