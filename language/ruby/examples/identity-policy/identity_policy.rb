require 'praxo'

M = Praxo::Models

def authorize(principal, action)
  return M.decision(allowed: false, reason: 'trusted principal is missing') if principal.nil?
  return M.decision(allowed: false, reason: 'trusted principal is inactive') unless principal[:active]
  return M.decision(allowed: true) if action[:kind] == 'model.generate'
  return M.decision(allowed: false, reason: 'role is not permitted') unless principal[:role] == 'operator'
  return M.decision(allowed: false, reason: 'tenant mismatch') unless action[:tenant] == principal[:tenant]
  return M.decision(allowed: false, reason: 'operation is not permitted') unless action[:tool] == 'record'

  M.decision(allowed: true)
end

principal = { tenant: 'acme', role: 'operator', active: true }
raise 'model should be allowed' unless authorize(principal, kind: 'model.generate')[:allowed]
raise 'record should be allowed' unless authorize(
  principal, kind: 'tool.invoke', tool: 'record', tenant: 'acme'
)[:allowed]
raise 'viewer should be denied' if authorize(
  { tenant: 'acme', role: 'viewer', active: true },
  kind: 'tool.invoke', tool: 'record', tenant: 'acme'
)[:allowed]
raise 'tenant mismatch should be denied' if authorize(
  principal, kind: 'tool.invoke', tool: 'record', tenant: 'other'
)[:allowed]
raise 'missing principal should be denied' if authorize(
  nil, kind: 'model.generate'
)[:allowed]

puts 'Ruby identity policy example passed'
