--- Custom Data:

local NAME = ""         -- This server's name (currently unused, but may be used in the future)
local MESSAGE = ""      -- Dialog for the ampstr
local WARP_ADDRESS = "" -- What address should the warp link to (port is ignored)
local WARP_DATA = ""    -- What data should the warp from the index contain

--- Script (do not modify):

local INDEX_ADDRESS = "hubos.konstinople.dev"
local POLL_RATE = 5 * 60

local online_count = 0

Net:on("player_join", function()
  online_count = online_count + 1
end)

Net:on("player_disconnect", function()
  online_count = online_count - 1
end)

local function send_analytics()
  Async.message_server(INDEX_ADDRESS, "index_analytics:online=" .. online_count)
end

local server_message_handlers = {
  index_query = function(event)
    local response = "index_response:name=" .. Net.encode_uri_component(NAME) ..
        "&message=" .. Net.encode_uri_component(MESSAGE) ..
        "&address=" .. Net.encode_uri_component(WARP_ADDRESS) ..
        "&data=" .. Net.encode_uri_component(WARP_DATA)

    Async.message_server(event.address, response)
  end,
  index_verify = function(event, data)
    Async.message_server(event.address, "index_verify:" .. data)
    send_analytics()
  end
}

Net:on("server_message", function(event)
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

local function loop()
  send_analytics()
  Async.sleep(POLL_RATE).and_then(loop)
end

loop()
