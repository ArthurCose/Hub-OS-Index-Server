require("scripts/index/constants")
math.randomseed()

local Direction = require("scripts/libs/direction")
local JSON = require("scripts/libs/json")
local Ampstr = require("scripts/index/ampstr")

-- server and warp data

---@class ServerInfo
---@field name string|nil
---@field message string|nil
---@field data string|nil
---@field last_online number
---@field link_date number

local area_id <const> = "default"
local default_message <const> = "No server is currently linked here."
local random_warp_message <const> = "Try your luck! This path links to a random server!"

---@type table<string, string>
--- warp name -> address
local warp_map = {}
---@type table<string, ServerInfo>
--- address -> ServerInfo
local server_info_map = {}
---@type table<string, number>
--- address -> number
local online_count_map = {}
---@type string[]
--- list of addresses
local active_servers = {}

Async.read_file(SAVE_PATH, function(data)
  if data and #data > 0 then
    server_info_map = JSON.decode(data)
  end
end)

-- updating data

local inactive_warp_gid <const> = Net.get_tileset(area_id, WARP_TILESET).first_gid
local active_warp_gid <const> = inactive_warp_gid + 1
local tile_object_data = {
  type = "tile",
  gid = 0,
}

local function iterate_uri_query(text)
  local last_index = 0

  return function()
    if last_index >= #text then
      return
    end

    local eq_index = string.find(text, "=", last_index)
    local amp_index = string.find(text, "&", eq_index)

    if amp_index == nil then
      amp_index = #text
    end

    local key = string.sub(text, last_index, eq_index - 1)
    local encoded_value = string.sub(text, eq_index + 1, amp_index - 1)

    last_index = amp_index + 1

    return key, encoded_value
  end
end

Net:on("server_message", function(event)
  local info = server_info_map[event.address]

  if not info then
    info = {
      link_date = os.time(),
      last_online = 0
    }

    server_info_map[event.address] = info
  end

  local online_count = 0

  for key, value in iterate_uri_query(event.data) do
    if key == "name" or key == "message" or key == "data" then
      info[key] = Net.decode_uri_component(value)
    elseif key == "online" then
      online_count = tonumber(value) or 0
    end
  end

  online_count_map[event.address] = online_count

  info.last_online = os.time()
end)

local function update_data()
  local time = os.time()
  active_servers = {}
  local latest_server = nil
  local latest_link_date = 0

  for key, info in pairs(server_info_map) do
    if info.last_online < time - SERVER_EXPIRATION then
      -- server tracking expired
      server_info_map[key] = nil
    elseif info.last_online > time - EXPECTED_POLL_RATE * 1.5 then
      -- server online
      active_servers[#active_servers + 1] = key

      if info.link_date > latest_link_date then
        latest_link_date = info.link_date
        latest_server = key
      end
    else
      -- drop online count as the server itself is considered offline
      online_count_map[key] = nil
    end
  end

  if #active_servers == 0 then
    -- no servers online
    warp_map = {}
    return
  end

  -- update active server warps
  table.sort(active_servers, function(a, b)
    return online_count_map[a] > online_count_map[b]
  end)

  local i = 1

  for _, name in ipairs(ACTIVE_SERVER_WARP_NAMES) do
    warp_map[name] = active_servers[i]
    i = i + 1
  end

  -- update newest server warp
  warp_map[NEWEST_SERVER_WARP_NAME] = latest_server
end

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
    local warp_id = Net.get_object_by_name(area_id, warp_name).id
    local address = warp_map[warp_name]

    if address then
      -- online
      local info = server_info_map[address]

      set_warp_active(warp_id, true)
      Net.set_object_custom_property(area_id, warp_id, "Address", address)
      Net.set_object_custom_property(area_id, warp_id, "Data", info.data or "")
    else
      -- offline
      set_warp_active(warp_id, false)
    end
  end

  local warp_id = Net.get_object_by_name(area_id, RANDOM_SERVER_WARP_NAME).id
  set_warp_active(warp_id, #active_servers ~= 0)
end

local function save_data()
  Async.write_file(SAVE_PATH, JSON.encode(server_info_map))
end

local function update_loop()
  Async.sleep(EXPECTED_POLL_RATE).and_then(update_loop)

  update_data()
  update_warps()
  save_data()
end

update_loop()

-- bots

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
  local a = Net.get_bot_position(event.actor_id)
  local b = Net.get_player_position(event.player_id)
  local direction = Direction.diagonal_from_points(a, b)
  Net.set_bot_direction(event.actor_id, direction)

  -- serious
  if Ampstr.serious(event.player_id) then return end

  -- message
  local message = default_message

  local info_key = warp_map[warp_name]
  local server_info = info_key and server_info_map[info_key]

  if server_info and warp_name == RANDOM_SERVER_WARP_NAME then
    message = random_warp_message
  elseif server_info and server_info.message then
    message = server_info.message
  end

  Ampstr.message_player(event.player_id, message)
end)

-- random warp

local RANDOM_WARP_OBJECT <const> = Net.get_object_by_name(area_id, RANDOM_SERVER_WARP_NAME)

Net:on("custom_warp", function(event)
  if event.object_id ~= RANDOM_WARP_OBJECT.id then return end

  local address = active_servers[math.random(#active_servers)]

  if address then
    -- transfer
    local info = server_info_map[address]
    Net.transfer_server(event.player_id, address, true, info.data or "")
  else
    -- warp back in
    local direction = RANDOM_WARP_OBJECT.custom_properties.Direction

    local x = RANDOM_WARP_OBJECT.x + RANDOM_WARP_OBJECT.height * 0.5
    local y = RANDOM_WARP_OBJECT.y + RANDOM_WARP_OBJECT.height * 0.5
    local z = RANDOM_WARP_OBJECT.z

    -- using Net.transfer_player to allow all players to see the warp
    -- need to still update warp handling through movement packets to improve this in the future
    Net.transfer_player(event.player_id, area_id, true, x, y, z, direction)

    -- let the player know what occurred
    local mugshot = Net.get_player_mugshot(event.player_id)
    local message = "We can find other servers from here."
    Net.message_player(event.player_id, message, mugshot.texture_path, mugshot.animation_path)
  end
end)
