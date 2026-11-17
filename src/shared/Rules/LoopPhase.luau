--!strict
-- Marks on a looping clip (a footfall at 0 and 0.5 of the walk loop): pure, unit-tested
-- with Lune (tests/LoopPhase.spec.luau). FootstepController asks it each frame whether the
-- dominant locomotion clip passed a footfall phase (Config.Audio.Footsteps.Phases).

local LoopPhase = {}

-- True when a loop that was at phase `from` last frame and is at `to` now (both 0..1)
-- passed `mark` on the way: after `from`, up to and including `to`. `to` below `from` means
-- the loop wrapped between the frames.
function LoopPhase.crossed(from: number, to: number, mark: number): boolean
	if to >= from then
		return from < mark and mark <= to
	end
	-- The loop wrapped between frames.
	return mark > from or mark <= to
end

return LoopPhase
