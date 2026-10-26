import json
from pathlib import Path


GROUPS = ("agent-loop", "memory", "context", "event", "checkpoint", "toolcall",
          "policy", "stream", "plugin", "jsonschema", "middleware")


def literal(text):
    parts, chunk = [], ""
    for byte in text.encode("utf-8"):
        if 32 <= byte < 127:
            chunk += chr(byte)
            continue
        if chunk:
            parts.append("'" + chunk.replace("'", "''") + "'")
            chunk = ""
        parts.append(f"char({byte})")
    if chunk:
        parts.append("'" + chunk.replace("'", "''") + "'")
    return "//".join(parts) if parts else "''"


def generate(root: Path, destination: Path):
    available = {path.stem for path in (root.parent / "spec" / "vectors").glob("*.json")}
    if set(GROUPS) != available:
        raise ValueError(f"vector group inventory changed: {sorted(available ^ set(GROUPS))}")
    lines = [
        "program fixture_tests", "use iso_fortran_env, only: int64",
        "use praxo_types", "use praxo_interfaces", "use praxo_agent",
        "use praxo_runtime", "use praxo_context", "use test_doubles",
        "use praxo_json", "use praxo_checkpoint", "use praxo_toolcall", "use praxo_policy",
        "use praxo_stream", "use praxo_plugin", "use praxo_schema", "use praxo_middleware",
        "implicit none", "integer :: assertions = 0",
    ]
    count = 0
    label = ""

    def check(expression):
        lines.append(f"call assert({expression}, {literal(label)})")

    def raw(value):
        return literal(json.dumps(value, separators=(",", ":"), ensure_ascii=False))

    def check_json(expression, expected):
        lines.append(f"call assert_json({expression}, {raw(expected)}, {literal(label)})")

    for group in GROUPS:
        data = json.loads((root.parent / "spec" / "vectors" / f"{group}.json").read_text(encoding="utf-8"))
        if data["specVersion"] != "0.2.0" or data["group"] != group:
            raise ValueError(f"unsupported contract: {group}")
        for vector in data["vectors"]:
            count += 1
            label = vector["id"]
            inp, expect = vector["input"], vector["expect"]
            lines.append("block")
            if group == "agent-loop":
                lines += [
                    "type(scripted_model), target :: provider",
                    *(["type(echo_tool) :: echo"] if inp.get("tools") else []),
                    "type(registry), target :: tools", "type(recording_sink), target :: sink",
                    "type(agent_options) :: options", "type(session) :: state",
                    "type(run_result) :: result", "type(sdk_error) :: error",
                    "integer, target :: invocations", "invocations = 0",
                    f"allocate(provider%script({len(inp['script'])}))",
                ]
                for i, step in enumerate(inp["script"], 1):
                    prefix = f"provider%script({i})"
                    lines += [
                        f"{prefix}%message = text_message('assistant', {literal(step.get('content', ''))})",
                        f"{prefix}%usage = usage({step.get('inputTokens', 0)}_int64, "
                        f"{step.get('outputTokens', 0)}_int64)",
                    ]
                    if step.get("toolCalls"):
                        lines += [f"deallocate({prefix}%message%tool_calls)",
                                  f"allocate({prefix}%message%tool_calls({len(step['toolCalls'])}))"]
                        for j, call in enumerate(step["toolCalls"], 1):
                            arguments = json.dumps(call.get("arguments"), separators=(",", ":"), ensure_ascii=False)
                            lines.append(f"{prefix}%message%tool_calls({j}) = tool_call("
                                         f"{literal(call.get('id', ''))}, {literal(call['name'])}, {literal(arguments)})")
                for item in inp.get("tools", []):
                    lines += [f"echo%spec = tool_spec({literal(item['name'])}, {literal(item.get('description', ''))})",
                              "echo%calls => invocations", "call tools%register(echo, error)"]
                    check(".not. error%failed()")
                lines += ["state%id = 's1'", "options%provider => provider", "options%tools => tools",
                          "options%events => sink", f"options%max_steps = {inp.get('maxSteps', 8)}",
                          f"options%max_tokens = {inp.get('maxTokens', 0)}_int64",
                          f"call run_agent(options, state, {literal(inp['prompt'])}, 'fixture-run', result, error)"]
                if expect.get("error"):
                    check(f"string_value(error%code) == {literal(expect['errorCode'])}")
                else:
                    check(".not. error%failed()")
                    check(f"result%output == {literal(expect['output'])}")
                    check(f"result%steps == {expect['steps']}")
                check(f"invocations == {expect['toolInvocations']}")
                check("allocated(sink%items)")
                check(f"size(sink%items) == {len(expect['events'])}")
                for i, kind in enumerate(expect["events"], 1):
                    check(f"sink%items({i})%kind == {literal(kind)}")
            elif group == "memory":
                lines += ["type(memory_store) :: store", "type(memory_record), allocatable :: records(:)"]
                for item in inp["puts"]:
                    record = item["record"]
                    fields = ", ".join(literal(record.get(key, "")) for key in ("id", "frame", "content", "createdAt"))
                    lines.append(f"call store%put({literal(item['session'])}, memory_record({fields}))")
                lines.append(f"records = store%search({literal(inp['session'])}, {literal(inp['query'])}, {inp['limit']})")
                check(f"size(records) == {len(expect['ids'] or [])}")
                for i, (identity, content) in enumerate(zip(expect["ids"] or [], expect["contents"] or [], strict=True), 1):
                    check(f"records({i})%id == {literal(identity)}")
                    check(f"records({i})%content == {literal(content)}")
            elif group == "context":
                lines.append("type(message), allocatable :: messages(:)")
                if inp["operation"] == "compact":
                    lines += ["type(message), allocatable :: output(:)",
                              "type(context_budget) :: budget", "logical :: ok"]
                lines.append(f"allocate(messages({len(inp['messages'])}))")
                for i, item in enumerate(inp["messages"], 1):
                    lines.append(f"messages({i}) = text_message({literal(item['role'])}, {literal(item['content'])})")
                if inp["operation"] == "estimate":
                    check(f"estimate_tokens(messages) == {expect['tokens']}")
                elif inp["operation"] == "compact":
                    budget = inp["budget"]
                    lines += [f"budget = context_budget({budget['maxTokens']}_int64, {budget['keepRecent']})",
                              "call budget%compact(messages, output, ok)"]
                    check("ok" if expect["ok"] else ".not. ok")
                    if expect["ok"]:
                        check(f"estimate_tokens(output) == {expect['tokens']}")
                        check(f"size(output) == {len(expect['messages'])}")
                        for i, item in enumerate(expect["messages"], 1):
                            check(f"output({i})%role == {literal(item['role'])}")
                            check(f"output({i})%content == {literal(item['content'])}")
                else:
                    raise ValueError(f"unknown context operation: {inp['operation']}")
            elif group == "event":
                lines += ["type(recording_sink), allocatable, target :: sinks(:)",
                          "type(multi_sink) :: multi" if inp["sink"] == "multi" else "type(filter_sink) :: filter",
                          "type(event) :: item"]
                sink_count = max(1, inp.get("sinkCount", 1)) if inp["sink"] == "multi" else 1
                lines.append(f"allocate(sinks({sink_count}))")
                if inp["sink"] == "multi":
                    for i in range(1, sink_count + 1):
                        lines.append(f"call multi%add(sinks({i}))")
                elif inp["sink"] == "filter":
                    lines.append("filter%target => sinks(1)")
                    if "predicateTypes" in inp:
                        kinds = inp["predicateTypes"]
                        width = max([1, *map(len, kinds)])
                        lines.append(f"filter%kinds = [character({width}) :: {', '.join(map(literal, kinds))}]")
                else:
                    raise ValueError(f"unknown sink: {inp['sink']}")
                for kind in inp["events"]:
                    lines += [f"item = event({literal(kind)}, 's1', 'r1', '', '')",
                              f"call {'multi' if inp['sink'] == 'multi' else 'filter'}%emit(item)"]
                deliveries = expect["perSink"] if inp["sink"] == "multi" else [expect["delivered"] or []]
                for i, kinds in enumerate(deliveries, 1):
                    if not kinds:
                        check(f".not. allocated(sinks({i})%items)")
                        continue
                    check(f"allocated(sinks({i})%items)")
                    check(f"size(sinks({i})%items) == {len(kinds)}")
                    for j, kind in enumerate(kinds, 1):
                        check(f"sinks({i})%items({j})%kind == {literal(kind)}")
            elif group == "checkpoint":
                lines += ["type(checkpoint_allowlist) :: allowlist", "type(sdk_error) :: error",
                          "character(:), allocatable :: envelope, output"]
                for name in inp.get("registered", []):
                    lines.append(f"call allowlist%register({literal(name)}, error)")
                    check(".not. error%failed()")
                if inp["operation"] == "unmarshal":
                    lines.append(f"envelope = {raw({'type': inp['type'], 'data': inp['value']})}")
                    lines.append("output = allowlist%unmarshal(envelope, error)")
                else:
                    lines.append(f"envelope = allowlist%marshal({literal(inp['type'])}, {raw(inp['value'])}, error)")
                    if inp["operation"] == "roundtrip":
                        check(".not. error%failed()")
                        lines.append("output = allowlist%unmarshal(envelope, error)")
                    elif inp["operation"] == "marshal":
                        lines.append("output = envelope")
                    else:
                        raise ValueError(f"unknown checkpoint operation: {inp['operation']}")
                if "errorCode" in expect:
                    check(f"string_value(error%code) == {literal(expect['errorCode'])}")
                else:
                    check(".not. error%failed()")
                    check_json("output", expect["value"])
            elif group == "toolcall":
                if inp["operation"] == "strip":
                    check(f"strip_markup({literal(inp['content'])}) == {literal(expect['text'])}")
                elif inp["operation"] == "parse":
                    lines += ["type(parsed_tool_call) :: item", f"item = parse_tool_call({literal(inp['content'])})"]
                    check(".not. item%found" if expect.get("nil") else "item%found")
                    if not expect.get("nil"):
                        check(f"item%name == {literal(expect['name'])}")
                        check_json("item%input", expect["input"])
                else:
                    raise ValueError(f"unknown toolcall operation: {inp['operation']}")
            elif group == "policy":
                lines += ["type(path_checker) :: checker", "type(decision) :: verdict", "type(sdk_error) :: error",
                          f"allocate(checker%grants({len(inp['grants'])}))"]
                for i, grant in enumerate(inp["grants"], 1):
                    lines.append(f"checker%grants({i}) = path_grant({literal(grant['root'])}, {literal(grant['access'])})")
                lines.append(f"verdict = checker%check({literal(inp['target'])}, {literal(inp['need'])}, error)")
                if expect.get("error"):
                    check("error%failed()")
                else:
                    check(".not. error%failed()")
                    check("verdict%allowed" if expect["allowed"] else ".not. verdict%allowed")
            elif group == "stream":
                check(f"size(stream_kinds) == {len(expect['kinds'])}")
                for i, kind in enumerate(expect["kinds"], 1):
                    check(f"stream_kinds({i}) == {literal(kind)}")
            elif group == "plugin":
                lines += ["type(plugin_manifest) :: manifest", "type(sdk_error) :: error"]
                text = literal(inp["raw"]) if "raw" in inp else raw(inp["manifest"])
                lines.append(f"call parse_manifest({text}, manifest, error)")
                check(".not. error%failed()" if expect["valid"] else "error%failed()")
                for key in ("id", "kind"):
                    if key in expect:
                        check(f"manifest%{key} == {literal(expect[key])}")
            elif group == "jsonschema":
                lines += ["type(validation_error), allocatable :: errors(:)", "type(sdk_error) :: error"]
                if expect.get("errorPaths"):
                    lines.append("integer :: k")
                lines.append(f"call validate_schema({raw(inp['schema'])}, {raw(inp['data'])}, errors, error)")
                check(".not. error%failed()")
                check(f"size(errors) == {len(expect.get('errorPaths', []))}")
                if not expect["valid"] and not expect.get("errorPaths"):
                    raise ValueError("invalid schema fixture must declare error paths")
                for path in expect.get("errorPaths", []):
                    check(f"any([(errors(k)%path == {literal(path)}, k = 1, size(errors))])")
            elif group == "middleware":
                op = inp["operation"]
                if op == "pii":
                    check(f"redact_email({literal(inp['text'])}) == {literal(expect['text'])}")
                elif op == "pii-value":
                    lines += ["character(:), allocatable :: output", "type(sdk_error) :: error",
                              f"output = redact_json_email({raw(inp['value'])}, error)"]
                    check(".not. error%failed()")
                    check_json("output", expect["value"])
                elif op == "structured":
                    lines += ["character(:), allocatable :: output", "type(sdk_error) :: error"]
                    repair = ""
                    if "repairOutput" in inp:
                        lines.append(f"repair_content = {literal(inp['repairOutput'])}")
                        repair = ", repair_fixture"
                    lines.append(f"output = structured_output({raw(inp['schema'])}, {literal(inp['output'])}, "
                                 f"{inp['maxRepairs']}, error{repair})")
                    if expect["ok"]:
                        check(".not. error%failed()")
                        check(f"output == {literal(expect['output'])}")
                    else:
                        check(f"string_value(error%code) == {literal(expect['errorCode'])}")
                elif op == "call-limit":
                    lines += ["type(call_limit) :: limits", "type(sdk_error) :: error",
                              f"limits%model_limit = {inp['modelLimit']}", f"limits%tool_limit = {inp['toolLimit']}"]
                    for kind, outcome in zip(inp["calls"], expect["outcomes"], strict=True):
                        lines.append(f"call limits%check('r1', {literal(kind)}, error)")
                        check(".not. error%failed()" if outcome == "ok" else
                              f"string_value(error%code) == {literal(outcome)}")
                elif op == "tool-selection":
                    lines += ["type(tool_selection) :: selection", "type(tool_spec), allocatable :: specs(:), filtered(:)",
                              "type(sdk_error) :: error", f"allocate(selection%selected({len(inp['selected'])}))",
                              f"allocate(specs({len(inp['tools'])}))"]
                    for i, name in enumerate(inp["selected"], 1):
                        lines.append(f"selection%selected({i})%value = {literal(name)}")
                    for i, name in enumerate(inp["tools"], 1):
                        lines.append(f"specs({i}) = tool_spec({literal(name)}, '')")
                    lines.append("filtered = selection%advertised(specs)")
                    check(f"size(filtered) == {len(expect['advertised'])}")
                    for i, name in enumerate(expect["advertised"], 1):
                        check(f"filtered({i})%name == {literal(name)}")
                    lines.append(f"call selection%check({literal(inp['requested'])}, error)")
                    check(f"string_value(error%code) == {literal(expect['reject'])}")
                elif op == "fallback":
                    lines += ["type(scripted_model), target :: primary, secondary", "type(fallback_model) :: adapted",
                              "type(request) :: req", "type(response) :: res", "type(sdk_error) :: error",
                              "primary%fail_at = 1", "allocate(secondary%script(1))",
                              f"secondary%script(1)%message = text_message('assistant', {literal(inp['fallbackContent'])})",
                              "adapted%primary => primary", "adapted%fallback => secondary",
                              "call adapted%generate(req, res, error)"]
                    check(".not. error%failed()")
                    check(f"res%message%content == {literal(expect['output'])}")
                else:
                    raise ValueError(f"unknown middleware operation: {op}")
            else:
                raise ValueError(f"unsupported vector group: {group}")
            lines.append("end block")
    lines += [f"print '(a)', 'PASS: {count} vectors in {len(GROUPS)}/11 groups'",
              "contains", "subroutine assert(ok, label)", "logical, intent(in) :: ok",
              "character(*), intent(in) :: label", "assertions = assertions + 1", "if (ok) return",
              "print '(a)', 'FAIL: '//label", "error stop 1", "end subroutine",
              "subroutine assert_json(actual, expected, label)",
              "character(*), intent(in) :: actual, expected, label",
              "type(json_document) :: a, b", "type(sdk_error) :: error",
              "call parse_json(actual, a, error)", "call assert(.not. error%failed(), label//': actual JSON')",
              "call parse_json(expected, b, error)", "call assert(.not. error%failed(), label//': expected JSON')",
              "call assert(json_equal(a, 1, b, 1), label//': JSON equality')", "end subroutine", "end program"]
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
