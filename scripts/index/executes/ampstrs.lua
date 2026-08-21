local Direction = require("scripts/libs/direction")
local Ampstr = require("scripts/index/ampstr")

local index_data = require("scripts/index/data")

local area_id <const> = "default"

local unlinked_warp_message <const> = "No server is currently linked here."
local default_warp_message <const> = "I'm not sure where this path leads!"
local random_warp_message <const> = "Try your luck! This path links to a random server!"

local bot_id_to_warp_name = {}

for _, warp_name in ipairs(WARP_NAMES) do
  local warp_object = Net.get_object_by_name(area_id, warp_name)
  local bot_spawn_object = Net.get_object_by_name(area_id, warp_name .. " Bot")

  local direction = "DOWN LEFT"

  if string.upper(warp_object.custom_properties.Direction or "") == "DOWN RIGHT" then
    direction = "DOWN RIGHT"
  end

  local bot_id = Net.create_bot({
    name = "Ampstr",
    x = bot_spawn_object.x,
    y = bot_spawn_object.y,
    texture_path = AMPSTR_TEXTURE,
    animation_path = AMPSTR_ANIMATION,
    direction = direction,
    solid = true
  })

  bot_id_to_warp_name[bot_id] = warp_name
end

Net:on("tile_interaction", function(event)
  if event.button == 1 then
    local mugshot = Net.get_player_mugshot(event.player_id)
    local message = "We can find other servers from here."
    Net.message_player(event.player_id, message, mugshot.texture_path, mugshot.animation_path)
  end
end)

Net:on("actor_interaction", function(event)
  if event.button ~= 0 then return end

  local warp_name = bot_id_to_warp_name[event.actor_id]

  if not warp_name then return end

  -- face player
  local a = Net.get_actor_position(event.actor_id)
  local b = Net.get_actor_position(event.player_id)
  local direction = Direction.diagonal_from_points(a, b)
  Net.set_actor_direction(event.actor_id, direction)

  -- serious
  -- if Ampstr.serious(event.player_id) then return end

  -- message
  local message

  local info_key = index_data.warp_map[warp_name]
  local server_info = info_key and index_data.server_info_map[info_key]

  if warp_name == RANDOM_SERVER_WARP_NAME and #index_data.active_servers ~= 0 then
    message = random_warp_message
  elseif not server_info then
    message = unlinked_warp_message
  elseif server_info.message then
    message = server_info.message
  else
    message = default_warp_message
  end

  Ampstr.message_player(event.player_id, message)
end)
