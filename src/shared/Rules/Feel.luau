--!strict
-- Pure maths for the satisfying pass (docs/superpowers/plans/2026-11-09-satisfying-pass.md):
-- blast shake falloff, low-health intensity and its fade, the killing push and the flinch cooldown. No
-- Roblox APIs, so tests/Feel.spec.luau runs it in Lune.

local Feel = {}

export type KnockbackConfig = { Blast: number, PerDamage: number, Max: number }

-- Shake amplitude (degrees) of a blast `distance` studs away: `power` at the centre, linear
-- falloff to nothing at `radius`.
function Feel.shake(power: number, distance: number, radius: number): number
	if radius <= 0 then
		return 0
	end
	return power * math.max(1 - distance / radius, 0)
end

-- Two blasts in one frame add up, but never past `cap`.
function Feel.addShake(current: number, added: number, cap: number): number
	return math.min(current + added, cap)
end

-- 0 at or above `start` (a health fraction), 1 at zero health, linear between.
function Feel.lowHealth(fraction: number, start: number): number
	if start <= 0 then
		return 0
	end
	return math.clamp(1 - fraction / start, 0, 1)
end

-- One frame of a linear fade from `shown` toward `goal` (LowHealthFX): a full 0 -> 1 swing
-- takes `ease` seconds (0 jumps straight there), never passing the goal. Fading out to 0, a
-- value at or under `off` snaps to 0.
function Feel.easeToward(shown: number, goal: number, dt: number, ease: number, off: number): number
	local stepSize = if ease > 0 then dt / ease else 1
	if goal > shown then
		shown = math.min(shown + stepSize, goal)
	else
		shown = math.max(shown - stepSize, goal)
	end
	if shown <= off and goal == 0 then
		shown = 0
	end
	return shown
end

-- Launch speed (studs/s) of a body killed by a hit of `kind` doing `damage`.
function Feel.knockback(kind: string, damage: number, cfg: KnockbackConfig): number
	if kind == "Blast" then
		return cfg.Blast
	end
	return math.min(damage * cfg.PerDamage, cfg.Max)
end

function Feel.canFlinch(now: number, lastAt: number?, cooldown: number): boolean
	return lastAt == nil or now - lastAt >= cooldown
end

-- The kill-confirm tick: one blast killing several Infected in the same instant ticks once,
-- kills at least `gap` seconds apart each tick.
function Feel.canKillConfirm(now: number, lastAt: number?, gap: number): boolean
	return lastAt == nil or now - lastAt >= gap
end

return Feel
