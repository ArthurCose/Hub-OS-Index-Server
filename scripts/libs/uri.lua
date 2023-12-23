local exports = {}

exports.iterate_query = function(text)
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

--- Converts `"a=1&b=c"` a lua table
--- to
--- ```lua
--- { a = 1, b = "c" }
--- ```
exports.parse_query = function(text)
  local result = {}

  for key, value in exports.iterate_query(text) do
    result[key] = value
  end

  return result
end

--- `"website.com:1234/data"` -> `"website.com"`
exports.get_host = function(text)
  local end_index = string.find(text, "[:/?#]") or (#text + 1)

  return string.sub(text, 1, end_index - 1)
end

--- `"website.com:1234/data"` -> `1234`
exports.get_port = function(text)
  local port_start = string.find(text, ":")

  if not port_start then return end

  local port_end = string.find(text, "[/?#]") or (#text + 1)

  return tonumber(string.sub(text, port_start + 1, port_end - 1))
end

--- resolves the path, hash, and search/query part of the URI
--- `"website.com:1234/data"` -> `"/data"`
exports.get_data = function(text)
  local data_index = string.find(text, "[/?#]") or (#text + 1)

  return string.sub(text, data_index, #text)
end

return exports
