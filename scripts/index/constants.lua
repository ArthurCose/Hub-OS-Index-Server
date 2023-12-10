SAVE_PATH                    = "_data.json"
SERVER_EXPIRATION            = 30 * 60 * 60 * 24 -- one month
EXPECTED_POLL_RATE           = 10 * 60           -- 10 mins
EXPECTED_POLL_RATE           = 5

ACTIVE_SERVER_WARP_NAMES     = {
  "Hot Server",
  "Active Server 1",
  "Active Server 2",
}
NEWEST_SERVER_WARP_NAME      = "Newest Server";
RANDOM_SERVER_WARP_NAME      = "Random Server";
WARP_NAMES                   = {
  NEWEST_SERVER_WARP_NAME,
  RANDOM_SERVER_WARP_NAME,
  table.unpack(ACTIVE_SERVER_WARP_NAMES),
}

WARP_TILESET                 = "/server/assets/tiles/warp.tsx"

AMPSTR_MUG_TEXTURE           = "/server/assets/bots/ampstr_mug.png"
AMPSTR_MUG_ANIMATION         = "/server/assets/bots/ampstr_mug.animation"
AMPSTR_SERIOUS_MUG_TEXTURE   = "/server/assets/bots/ampstr_serious_mug.png"
AMPSTR_SERIOUS_MUG_ANIMATION = "/server/assets/bots/ampstr_serious_mug.animation"
AMPSTR_TEXTURE               = "/server/assets/bots/ampstr.png"
AMPSTR_ANIMATION             = "/server/assets/bots/ampstr.animation"
