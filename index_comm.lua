--- Custom Data:

local NAME = ""      -- This server's name (currently unused, but may be used in the future)
local MESSAGE = ""   -- Dialog for the ampstr
local WARP_DATA = "" -- What data should the warp from the index contain

--- Script (do not modify):

local INDEX_ADDRESS = "hubos.konstinople.dev"
local POLL_RATE = 5 * 60
local MESSAGE_CONSTANT =
    "name=" .. Net.encode_uri_component(NAME) ..
    "&message=" .. Net.encode_uri_component(MESSAGE) ..
    "&data=" .. WARP_DATA ..
    "&online="

local online_count = 0

Net:on("player_join", function()
  online_count = online_count + 1
end)

Net:on("player_disconnect", function()
  online_count = online_count - 1
end)

local function loop()
  Async.message_server(INDEX_ADDRESS, MESSAGE_CONSTANT .. online_count)

  Async.sleep(POLL_RATE).and_then(loop)
end

loop()
