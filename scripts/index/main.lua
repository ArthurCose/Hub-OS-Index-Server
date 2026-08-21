require("scripts/index/executes/constants")
require("scripts/index/executes/guide")
require("scripts/index/executes/ampstrs")
require("scripts/index/executes/random_warp")
require("scripts/index/executes/comm")

local index_data = require("scripts/index/data")
local update_warps = require("scripts/index/update_warps")

local function update_loop()
  Async.sleep(EXPECTED_POLL_RATE).and_then(update_loop)

  index_data.update_server_list()
  update_warps()
  index_data.save()
end

update_loop()
