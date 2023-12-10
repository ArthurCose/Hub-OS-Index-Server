local exports = {}

exports.serious = function(player_id, callback)
  if math.random(8) ~= 1 then
    return false
  end

  local message = "\u{1}..."
  local texture = AMPSTR_SERIOUS_MUG_TEXTURE
  local animation = AMPSTR_SERIOUS_MUG_ANIMATION

  if callback then
    Async.message_player(player_id, message, texture, animation)
        .and_then(callback)
  else
    Net.message_player(player_id, message, texture, animation)
  end

  return true
end

exports.message_player = function(player_id, message)
  return Net.message_player(
    player_id,
    message,
    AMPSTR_MUG_TEXTURE,
    AMPSTR_MUG_ANIMATION
  )
end

exports.message_player_async = function(player_id, message)
  return Async.message_player(
    player_id,
    message,
    AMPSTR_MUG_TEXTURE,
    AMPSTR_MUG_ANIMATION
  )
end

exports.question_player_async = function(player_id, question)
  return Async.question_player(
    player_id,
    question,
    AMPSTR_MUG_TEXTURE,
    AMPSTR_MUG_ANIMATION
  )
end

return exports
