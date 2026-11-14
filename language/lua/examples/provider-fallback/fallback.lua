local function run(primary, fallback)
  local ok, result = pcall(primary)
  if ok then
    return result
  end
  local fallback_ok, fallback_result = pcall(fallback)
  if fallback_ok then
    return fallback_result
  end
  error(result)
end

local fallback_calls = 0
assert(run(function() return "primary" end, function()
  fallback_calls = fallback_calls + 1
  return "fallback"
end) == "primary")
assert(fallback_calls == 0)

assert(run(function() error("MODEL_UNAVAILABLE") end, function()
  return "fallback"
end) == "fallback")

local ok, err = pcall(function()
  run(function() error("MODEL_UNAVAILABLE") end,
      function() error("MODEL_UNAVAILABLE") end)
end)
assert(not ok and tostring(err):find("MODEL_UNAVAILABLE", 1, true))

print("Lua provider fallback example passed")
