local M = {}

function M.raise(code, message)
  error({ code = code, message = message })
end

function M.code(error_value)
  if type(error_value) == "table" and error_value.code then
    return error_value.code
  end
  return ""
end

return M
