local index_data = require("scripts/index/data")

local area_id = "default"

local inactive_warp_gid <const> = Net.get_tileset(area_id, WARP_TILESET).first_gid
local active_warp_gid <const> = inactive_warp_gid + 1
local tile_object_data = {
  type = "tile",
  gid = 0,
}

local function set_warp_active(warp_id, active)
  if active then
    tile_object_data.gid = active_warp_gid
  else
    tile_object_data.gid = inactive_warp_gid
  end

  Net.set_object_data(area_id, warp_id, tile_object_data)
end

local function update_warps()
  for _, warp_name in ipairs(WARP_NAMES) do
    local warp_object = Net.get_object_by_name(area_id, warp_name)
    local warp_id = warp_object.id
    local host = index_data.warp_map[warp_name]

    if host then
      -- online
      local info = index_data.server_info_map[host]

      set_warp_active(warp_id, true)
      Net.set_object_custom_property(area_id, warp_id, "Address", info.public_address)
      Net.set_object_custom_property(area_id, warp_id, "Data", info.data or "")
    else
      -- offline
      set_warp_active(warp_id, false)
    end
  end

  local warp_id = Net.get_object_by_name(area_id, RANDOM_SERVER_WARP_NAME).id
  set_warp_active(warp_id, #index_data.active_servers ~= 0)
end

return update_warps
