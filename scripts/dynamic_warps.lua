require("scripts/index/constants")
math.randomseed()

local Direction = require("scripts/libs/direction")
local JSON = require("scripts/libs/json")
local URI = require("scripts/libs/schemeless-uri")
local Ampstr = require("scripts/index/ampstr")

-- server and warp data

---@class ServerInfo
---@field public_address string|nil
---@field name string|nil
---@field message string|nil
---@field data string|nil
---@field last_online number
---@field link_date number

---@class PendingVerification
---@field host string
---@field code number
---@field server_info ServerInfo

local area_id <const> = "default"
local unlinked_warp_message <const> = "No server is currently linked here."
local default_warp_message <const> = "I'm not sure where this path leads!"
local random_warp_message <const> = "Try your luck! This path links to a random server!"

---@type table<string, string>
--- event.address -> host
local host_map = {}
---@type table<string, boolean>
--- event.address -> bool
local blocked_map = {}
---@type table<string, PendingVerification>
--- event.address -> PendingVerification
local pending_verification = {}
---@type table<string, string>
--- warp name -> host
local warp_map = {}
---@type table<string, ServerInfo>
--- host -> ServerInfo
local server_info_map = {}
---@type table<string, number>
--- host -> number
local online_count_map = {}
---@type string[]
--- list of hosts
local active_servers = {}

Async.read_file(SAVE_PATH).and_then(function(data)
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

local server_message_handlers = {
  index_analytics = function(event, data)
    local host = host_map[event.address]

    if not host then
      -- request server info
      Async.message_server(event.address, "index_query:info")
      return
    end

    local data = URI.parse_query(data)

    if data.online then
      online_count_map[host] = tonumber(data.online) or 0
      server_info_map[host].last_online = os.time()
    end
  end,
  index_response = function(event, data)
    local data = URI.parse_query(data)

    if not data.address then
      return
    end

    local warp_address = Net.decode_uri_component(data.address)
    local host = URI.get_host(warp_address)
    local port = URI.get_port(event.address)

    if port ~= 8765 then
      -- append if the default port is not used
      host = host .. ":" .. port
    end

    local code = Net.system_random()

    pending_verification[event.address] = {
      host = host,
      code = code,
      server_info = {
        public_address = host .. URI.get_data(warp_address),
        name = Net.decode_uri_component(data.name),
        message = Net.decode_uri_component(data.message),
        data = Net.decode_uri_component(data.data),
        link_date = os.time(),
        last_online = 0
      }
    }

    -- message the server using the warp address to verify the public address
    Async.message_server(host, "index_verify:" .. code)
  end,
  index_verify = function(event, data)
    local pending = pending_verification[event.address]

    if not pending then
      return
    end

    pending_verification[event.address] = nil

    if pending.code ~= tonumber(data) then
      -- wrong code received, ignore future messages from this server
      -- prevents brute force guessing
      print("blocking " .. event.address .. " for failed verification")
      blocked_map[event.address] = true
      return
    end

    local host = pending.host
    local server_info = pending.server_info

    -- map address -> host
    host_map[event.address] = host


    print("verified " .. event.address .. " as " .. host)

    -- map host -> server_info
    local existing_info = server_info_map[host]

    if not existing_info then
      -- set server info and return early
      server_info_map[host] = server_info
      return
    end

    -- update only warp + display relevant fields
    existing_info.public_address = server_info.public_address
    existing_info.name = server_info.name
    existing_info.data = server_info.data
    existing_info.message = server_info.message
  end
}

Net:on("server_message", function(event)
  if blocked_map[event.address] then
    return
  end

  local colon_index = string.find(event.data, ":", 1, true)

  if not colon_index then
    -- invalid messsage
    return
  end

  local prefix = string.sub(event.data, 1, colon_index - 1)
  local handler = server_message_handlers[prefix]

  if handler then
    handler(event, string.sub(event.data, colon_index + 1))
  end
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
    local host = warp_map[warp_name]

    if host then
      -- online
      local info = server_info_map[host]

      set_warp_active(warp_id, true)
      Net.set_object_custom_property(area_id, warp_id, "Address", info.public_address)
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
  local message

  local info_key = warp_map[warp_name]
  local server_info = info_key and server_info_map[info_key]

  if warp_name == RANDOM_SERVER_WARP_NAME and #active_servers ~= 0 then
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

-- random warp

local RANDOM_WARP_OBJECT <const> = Net.get_object_by_name(area_id, RANDOM_SERVER_WARP_NAME)

Net:on("custom_warp", function(event)
  if event.object_id ~= RANDOM_WARP_OBJECT.id then return end

  local host = active_servers[math.random(#active_servers)]

  if host then
    -- transfer
    local info = server_info_map[host]
    Net.transfer_server(event.player_id, info.public_address, true, info.data or "")
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
    local message = "The warp closed\x01..."
    Net.message_player(event.player_id, message, mugshot.texture_path, mugshot.animation_path)
  end
end)
