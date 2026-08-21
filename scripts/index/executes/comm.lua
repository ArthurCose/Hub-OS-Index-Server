---@class PendingVerification
---@field host string
---@field code number
---@field server_info IndexServer.ServerInfo
---@field creation_time number

local VERIFICATION_EXPIRE_S = 5

local URI = require("scripts/libs/schemeless-uri")
local index_data = require("scripts/index/data")

---@type table<string, boolean>
--- event.address -> bool
local blocked_map = {}
---@type table<string, PendingVerification>
--- event.address -> PendingVerification
local pending_verification = {}

-- updating data

local server_message_handlers = {
  index_analytics = function(event, data)
    local host = index_data.host_map[event.address]

    if not host then
      local pending = pending_verification[event.address]

      if not pending or os.difftime(os.time(), pending.creation_time) > VERIFICATION_EXPIRE_S then
        -- request server info if we haven't already
        Async.message_server(event.address, "index_request:register")
      end

      return
    end

    local data = URI.parse_query(data)

    if data.online then
      index_data.online_count_map[host] = tonumber(data.online) or 0
      index_data.server_info_map[host].last_online = os.time()
    end
  end,
  index_register = function(event, data)
    local data = URI.parse_query(data)

    if tonumber(data.protocol) ~= Net.protocol_version() then
      return
    end

    local warp_address = Net.decode_uri_component(data.address)
    local host = URI.get_host(warp_address)
    local port = URI.get_port(warp_address)

    if port then
      -- append if a port is set
      host = host .. ":" .. port
    end

    local time = os.time()

    local server_info = {
      public_address = host .. URI.get_data(warp_address),
      name = Net.decode_uri_component(data.name),
      message = Net.decode_uri_component(data.message),
      data = Net.decode_uri_component(data.data),
      link_date = time,
      last_online = 0
    }

    if index_data.host_map[event.address] == host then
      -- server info must already exist if we've mapped the address
      -- we'll just update it
      local existing_info = index_data.server_info_map[host]
      existing_info.public_address = server_info.public_address
      existing_info.name = server_info.name
      existing_info.data = server_info.data
      existing_info.message = server_info.message
      return
    end

    -- require verification to update server info
    local pending = pending_verification[event.address]

    if not pending or os.difftime(time, pending.creation_time) > VERIFICATION_EXPIRE_S then
      local code = Net.system_random()

      pending_verification[event.address] = {
        host = host,
        code = code,
        server_info = server_info,
        creation_time = time,
      }

      -- message the server using the warp address to verify the public address
      Async.message_server(host, "index_verify:" .. code)
    end
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
    index_data.host_map[event.address] = host


    print("verified " .. event.address .. " as " .. host)

    -- map host -> server_info
    local existing_info = index_data.server_info_map[host]

    if not existing_info then
      -- set server info and return early
      index_data.server_info_map[host] = server_info
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
