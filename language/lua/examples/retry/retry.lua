local function run(failures, max_attempts)
  for attempt = 1, max_attempts do
    if attempt > failures then
      return "status: green", attempt
    end
  end
  return nil, "MODEL_UNAVAILABLE", max_attempts
end

local output, calls = run(2, 3)
assert(output == "status: green" and calls == 3)
local failed, error_code, exhausted = run(3, 3)
assert(failed == nil and error_code == "MODEL_UNAVAILABLE" and exhausted == 3)

print("Lua retry example passed")
