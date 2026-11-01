local json = require("praxo.json")

local M = {}

function M.parse(text)
  local content = {}
  local done = false
  for line in (text or ""):gmatch("([^\n]*)\n?") do
    local trimmed = line:match("^%s*(.-)%s*$")
    local chunk = trimmed:match("^data:%s*(.*)$")
    if chunk then
      if chunk == "[DONE]" then
        done = true
        break
      elseif chunk ~= "" then
        local ok, event = pcall(json.parse, chunk)
        if not ok then return nil, "MODEL_STREAM" end
        if type(event) == "table" then
          for _, choice in ipairs(event.choices or {}) do
            local delta = choice.delta or {}
            if type(delta.content) == "string" then
              content[#content + 1] = delta.content
            end
            if choice.finish_reason ~= nil and not json.is_null(choice.finish_reason) then
              done = true
            end
          end
        end
      end
    end
  end
  if not done then return nil, "MODEL_STREAM" end
  return table.concat(content)
end

return M
