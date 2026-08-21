local index_data = require("scripts/index/data")

local area_id = "default"

local RANDOM_WARP_OBJECT <const> = Net.get_object_by_name(area_id, RANDOM_SERVER_WARP_NAME)

Net:on("custom_warp", function(event)
  if event.object_id ~= RANDOM_WARP_OBJECT.id then return end

  local host = index_data.active_servers[math.random(#index_data.active_servers)]

  if host then
    -- transfer
    local info = index_data.server_info_map[host]
    Net.transfer_server(event.player_id, info.public_address, true, info.data or "")
  else
    -- warp back in
    local direction = RANDOM_WARP_OBJECT.custom_properties.Direction

    local x = RANDOM_WARP_OBJECT.x + RANDOM_WARP_OBJECT.height * 0.5
    local y = RANDOM_WARP_OBJECT.y + RANDOM_WARP_OBJECT.height * 0.5
    local z = RANDOM_WARP_OBJECT.z

    -- using Net.transfer_player to allow all players to see the warp
    -- need to still update warp handling through movement packets to improve this in the future
    Net.transfer_actor(event.player_id, area_id, true, x, y, z, direction)

    -- let the player know what occurred
    local mugshot = Net.get_player_mugshot(event.player_id)
    local message = "The warp closed\x01..."
    Net.message_player(event.player_id, message, mugshot.texture_path, mugshot.animation_path)
  end
end)
