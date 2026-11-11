--!strict
-- The objective modules (docs/PROGRESSION.md > Objective pools): one file per objective in
-- this folder, each returning a Types.Module, found by the `Module` name on its row in
-- ObjectiveDefinitions. Kit holds what they share (markers, prompts, marked Infected).

local Types = require(script.Types)

local Objectives = {}

local NOT_OBJECTIVES = { Types = true, Kit = true }

-- The module called `name`, or nil (ObjectiveService then skips that objective).
function Objectives.module(name: string): Types.Module?
	local child = script:FindFirstChild(name)
	if child and child:IsA("ModuleScript") and not NOT_OBJECTIVES[name] then
		return (require :: any)(child) :: Types.Module
	end
	return nil
end

return Objectives
