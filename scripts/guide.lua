require("scripts/index/constants")
math.randomseed()

local Direction = require("scripts/libs/direction")
local Ampstr = require("scripts/index/ampstr")

local area_id = "default"
local BOT_SPEED = 1 / 16

local start_point <const> = Net.get_object_by_name(area_id, "Guide Path")
local target_point = Net.get_object_by_id(area_id, start_point.custom_properties.Next)

local position = { x = start_point.x, y = start_point.y, z = 0 }
local bot_id = Net.create_bot({
  name = "Ampstr",
  x = position.x,
  y = position.y,
  texture_path = AMPSTR_TEXTURE,
  animation_path = AMPSTR_ANIMATION,
  direction = Direction.diagonal_from_points(start_point, target_point),
  solid = true
})

local conversation_count = 0
local conversation_map = {}

local function conversation_end(player_id)
  if conversation_map[player_id] then
    conversation_count = conversation_count - 1
    conversation_map[player_id] = nil
  end
end


Net:on("tick", function()
  -- movement update

  if conversation_count > 0 then
    -- don't move while having a conversation
    return
  end

  -- see if a player is in the way
  for _, player_id in ipairs(Net.list_players(area_id)) do
    local player_position = Net.get_player_position(player_id)

    local player_diff_x = player_position.x - position.x
    local player_diff_y = player_position.y - position.y
    local player_sqr_dist = player_diff_x * player_diff_x + player_diff_y * player_diff_y

    if player_sqr_dist < 0.3 * 0.3 then
      -- block movement
      return
    end
  end

  local diff_x = target_point.x - position.x
  local diff_y = target_point.y - position.y
  local direction = Direction.diagonal_from_offset(diff_x, diff_y)

  local movement = Direction.unit_vector(direction)

  position.x = position.x + movement.x * BOT_SPEED
  position.y = position.y + movement.y * BOT_SPEED

  Net.move_bot(bot_id, position.x, position.y, 0)

  if diff_x * diff_x + diff_y * diff_y < BOT_SPEED * BOT_SPEED * 2 then
    target_point = Net.get_object_by_id(area_id, target_point.custom_properties.Next)
  end
end)

-- guide logic

local guide_list = {
  {
    slide_time = 1.3,
    target = Net.get_object_by_name(area_id, ACTIVE_SERVER_WARP_NAMES[1]),
    message = "The orange link leads to the most active server."
  },
  {
    slide_time = 0.7,
    target = Net.get_object_by_name(area_id, ACTIVE_SERVER_WARP_NAMES[2]),
    message = "The green links lead other active servers."
  },
  {
    slide_time = 1.8,
    target = Net.get_object_by_name(area_id, NEWEST_SERVER_WARP_NAME),
    message = "The blue link leads to the most recently linked server."
  },
  {
    slide_time = 1.5,
    target = Net.get_object_by_name(area_id, RANDOM_SERVER_WARP_NAME),
    message = "The purple link will bring you to a random server."
  },
  {
    slide_time = 1.5,
    message = "We hope you find what you're looking for!"
  }
}

local guide = Async.create_function(function(player_id)
  Async.await(Ampstr.message_player_async(player_id, "I'll show you around!"))

  local index = 1
  local start_position = Net.get_player_position(player_id)
  local wait_time = 0.45

  while index <= #guide_list do
    local item = guide_list[index]
    local target = item.target

    local z = 0

    if not target then
      target = start_position
      z = 0
    else
      z = target.z - 1.5
    end

    -- move camera
    Net.slide_player_camera(player_id, target.x, target.y, z, item.slide_time)
    Async.await(Async.sleep(item.slide_time + wait_time))

    -- display information
    local promise = Ampstr.message_player_async(player_id, item.message)
    Async.await(promise)

    index = index + 1
  end

  Net.unlock_player_camera(player_id)

  conversation_end(player_id)
end)

Net:on("actor_interaction", function(event)
  if event.button ~= 0 or event.actor_id ~= bot_id then
    return
  end

  -- face the player
  local player_position = Net.get_player_position(event.player_id)
  Net.set_bot_direction(bot_id, Direction.diagonal_from_points(position, player_position))

  -- serious
  local conversation_end_callback = function()
    conversation_end(event.player_id)
  end

  if Ampstr.serious(event.player_id, conversation_end_callback) then
    return
  end

  -- track conversation
  conversation_count = conversation_count + 1
  conversation_map[event.player_id] = true

  -- begin flow
  local promise = Ampstr.question_player_async(event.player_id, "Have you been to the index before?")

  promise.and_then(function(response)
    if response == 1 then
      Ampstr.message_player_async(
        event.player_id,
        "We hope you find what you're looking for!"
      ).and_then(conversation_end_callback)
    else
      guide(event.player_id)
    end
  end)
end)
