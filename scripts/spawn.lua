-- we're going to spawn players at a random position on the map
-- and considering only the first two tiles as safe locations to spawn the player

math.randomseed()

local spawn_locations = {}

local area_id = "default"

local w = Net.get_layer_width(area_id)
local h = Net.get_layer_height(area_id)
local tileset = Net.get_tileset(area_id, "/server/assets/tiles/floor.tsx")

for y = 1, h - 1, 1 do
  for x = 1, w - 1, 1 do
    local gid = Net.get_tile(area_id, x, y, 0).gid

    if gid == tileset.first_gid or gid == tileset.first_gid + 1 then
      spawn_locations[#spawn_locations + 1] = {
        x = x + 0.5,
        y = y + 0.5
      }
    end
  end
end

Net:on("player_request", function(event)
  local position = spawn_locations[math.random(#spawn_locations)]
  Net.transfer_player(event.player_id, "default", true, position.x, position.y, 0)
end)
