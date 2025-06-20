local ScriptNodes = require("scripts/libs/script_nodes")

local scripts = ScriptNodes:new()

for _, area_id in ipairs(Net.list_areas()) do
  scripts:load(area_id)
end
