local starter = dofile("examples/consumer-lua/starter.lua")

local output, calls, code = starter.run_scenario("public")
assert(code == nil and output == "recorded" and calls == 1, "allow verification failed")

local _, deny_calls, deny_code = starter.run_scenario("private")
assert(deny_code == "AGENT_POLICY_DENIED" and deny_calls == 0, "deny verification failed")

print("lua consumer tests passed")
