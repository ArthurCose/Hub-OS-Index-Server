local JSON = require("scripts/libs/json")

---@class IndexServer.ServerInfo
---@field public_address string|nil
---@field name string|nil
---@field message string|nil
---@field data string|nil
---@field last_online number
---@field link_date number

---@class IndexServer.Data
---@field host_map table<string, string> event.address -> host
---@field warp_map table<string, string> warp name -> host
---@field server_info_map table<string, IndexServer.ServerInfo> host -> ServerInfo
---@field online_count_map table<string, number> host -> number
---@field active_servers string[] list of hosts
local Data = {
  host_map = {},
  warp_map = {},
  server_info_map = {},
  online_count_map = {},
  active_servers = {},
}

local save_loaded = false

Async.read_file(SAVE_PATH).and_then(function(data)
  save_loaded = true

  if data and #data > 0 then
    Data.server_info_map = JSON.decode(data)
  end
end)

function Data.save()
  if save_loaded then
    Async.write_file(SAVE_PATH, JSON.encode(Data.server_info_map))
  end
end

function Data.update_server_list()
  local time = os.time()
  Data.active_servers = {}
  local latest_server = nil
  local latest_link_date = 0

  for key, info in pairs(Data.server_info_map) do
    if info.last_online < time - SERVER_EXPIRATION then
      -- server tracking expired
      Data.server_info_map[key] = nil
    elseif info.last_online > time - EXPECTED_POLL_RATE * 1.5 then
      -- server online
      Data.active_servers[#Data.active_servers + 1] = key

      if info.link_date > latest_link_date then
        latest_link_date = info.link_date
        latest_server = key
      end
    else
      -- drop online count as the server itself is considered offline
      Data.online_count_map[key] = nil
    end
  end

  if #Data.active_servers == 0 then
    -- no servers online
    Data.warp_map = {}
    return
  end

  -- update active server warps
  table.sort(Data.active_servers, function(a, b)
    return Data.online_count_map[a] > Data.online_count_map[b]
  end)

  local i = 1

  for _, name in ipairs(ACTIVE_SERVER_WARP_NAMES) do
    Data.warp_map[name] = Data.active_servers[i]
    i = i + 1
  end

  -- update newest server warp
  Data.warp_map[NEWEST_SERVER_WARP_NAME] = latest_server
end

---@type IndexServer.Data
return Data
