import json
from pathlib import Path

GROUPS = ("agent-loop", "checkpoint", "context", "event", "jsonschema",
          "memory", "middleware", "plugin", "policy", "stream", "toolcall")


def literal(text):
    data = text.encode("utf-8")
    if not data:
        return "spaces"
    if all(32 <= byte < 127 for byte in data):
        return "'" + text.replace("'", "''") + "'"
    return 'x"' + data.hex() + '"'


def dump(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def emit_checks(lines, label, conditions):
    for condition in conditions:
        lines += ["move 0 to assertion-ok",
                  f"if {condition} move 1 to assertion-ok end-if",
                  f"move {literal(label)} to assertion-label",
                  "perform assert-ok"]


def emit_init(lines, *records):
    lines.append("initialize " + " ".join(records))


def generate_group(root, destination, group, data):
    lines = [
        "       >>source format free",
        "identification division.",
        f"program-id. fixture-{group.replace('-', '-')}.",
        "environment division.",
        "configuration section.",
        "repository. function all intrinsic.",
        "data division.",
        "working-storage section.",
        "01 failures binary-long value 0.",
        "01 checks binary-long value 0.",
        "01 assertion-ok pic 9.",
        "01 assertion-label pic x(160).",
        "01 i binary-long.",
        "01 j binary-long.",
        'copy "' + {
            "agent-loop": "agent-vector.cpy",
            "checkpoint": "checkpoint.cpy",
            "context": "context.cpy",
            "event": "event.cpy",
            "jsonschema": "schema.cpy",
            "memory": "memory.cpy",
            "middleware": "middleware.cpy",
            "plugin": "plugin.cpy",
            "policy": "policy.cpy",
            "stream": "stream.cpy",
            "toolcall": "toolcall.cpy",
        }[group] + '".',
        "procedure division.",
    ]
    for vector in data["vectors"]:
        label = vector["id"]
        inp, expect = vector["input"], vector["expect"]
        lines.append(f"*> {label}")
        if group == "agent-loop":
            lines += ["initialize px-agent-vector-request px-agent-vector-result"]
            lines += [f"move {literal(inp['prompt'])} to px-av-prompt",
                      f"move {len(inp['prompt'].encode())} to px-av-prompt-length"]
            lines.append(f"move {len(inp['script'])} to px-av-script-count")
            for i, step in enumerate(inp["script"], 1):
                content = step.get("content", "")
                lines += [f"move {literal(content)} to px-av-content({i})",
                          f"move {len(content.encode())} to px-av-content-length({i})",
                          f"move {step.get('inputTokens', 0)} to px-av-input-tokens({i})",
                          f"move {step.get('outputTokens', 0)} to px-av-output-tokens({i})"]
                calls = step.get("toolCalls", [])
                lines.append(f"move {len(calls)} to px-av-call-count({i})")
                for j, call in enumerate(calls, 1):
                    arguments = dump(call.get("arguments"))
                    lines += [f"move {literal(call['name'])} to px-av-call-name({i}, {j})",
                              f"move {len(call['name'].encode())} to px-av-call-name-length({i}, {j})",
                              f"move {literal(arguments)} to px-av-call-args({i}, {j})",
                              f"move {len(arguments.encode())} to px-av-call-args-length({i}, {j})"]
            tools = inp.get("tools", [])
            lines.append(f"move {len(tools)} to px-av-tool-count")
            for i, tool in enumerate(tools, 1):
                lines.append(f"move {literal(tool['name'])} to px-av-tools({i})")
            lines += [f"move {inp.get('maxSteps', 8)} to px-av-max-steps",
                      f"move {inp.get('maxTokens', 0)} to px-av-max-tokens",
                      'call "praxo-agent-vector" using px-agent-vector-request px-agent-vector-result']
            conditions = []
            if expect.get("error"):
                code = expect["errorCode"]
                conditions.append(f"px-av-error(1:{len(code.encode())}) = {literal(code)}")
            else:
                conditions += ["px-av-error = spaces",
                               f"px-av-result-output-length = {len(expect['output'].encode())}",
                               f"px-av-result-output(1:px-av-result-output-length) = {literal(expect['output'])}"]
            conditions += [f"px-av-invocations = {expect['toolInvocations']}",
                           f"px-av-event-count = {len(expect['events'])}"]
            if not expect.get("error"):
                conditions.append(f"px-av-steps = {expect['steps']}")
            for i, kind in enumerate(expect["events"], 1):
                conditions.append(f"px-av-events({i}) = {literal(kind)}")
            emit_checks(lines, label, conditions)
        elif group == "memory":
            lines += ["initialize px-memory-request px-memory-result",
                      "move \"clear\" to px-mem-op",
                      'call "praxo-memory" using px-memory-request px-memory-result']
            for put in inp["puts"]:
                record = put["record"]
                session = put["session"]
                lines += ["move \"put\" to px-mem-op",
                          f"move {literal(session)} to px-mem-session",
                          f"move {len(session.encode())} to px-mem-session-length",
                          f"move {literal(record.get('id', ''))} to px-mem-id",
                          f"move {len(record.get('id', '').encode())} to px-mem-id-length",
                          f"move {literal(record.get('frame', ''))} to px-mem-frame",
                          f"move {literal(record.get('content', ''))} to px-mem-content",
                          f"move {len(record.get('content', '').encode())} to px-mem-content-length",
                          f"move {literal(record.get('createdAt', ''))} to px-mem-created",
                          'call "praxo-memory" using px-memory-request px-memory-result']
                emit_checks(lines, label + " put", ["px-mem-error = spaces"])
            lines += ["move \"search\" to px-mem-op",
                      f"move {literal(inp['session'])} to px-mem-session",
                      f"move {len(inp['session'].encode())} to px-mem-session-length",
                      f"move {literal(inp['query'])} to px-mem-query",
                      f"move {len(inp['query'].encode())} to px-mem-query-length",
                      f"move {inp['limit']} to px-mem-limit",
                      'call "praxo-memory" using px-memory-request px-memory-result']
            expected_ids = expect["ids"] or []
            emit_checks(lines, label, ["px-mem-error = spaces",
                                       f"px-mem-count = {len(expected_ids)}"])
            for i, (identity, content) in enumerate(zip(expected_ids, expect["contents"] or [], strict=True), 1):
                emit_checks(lines, label, [
                    f"px-mem-res-id-length({i}) = {len(identity.encode())}",
                    f"px-mem-res-id({i})(1:px-mem-res-id-length({i})) = {literal(identity)}",
                    f"px-mem-res-content({i})(1:px-mem-res-content-length({i})) = {literal(content)}",
                ])
        elif group == "context":
            lines.append("initialize px-context-request px-context-result")
            lines += [f"move {literal(inp['operation'])} to px-ctx-op",
                      f"move {len(inp['messages'])} to px-ctx-count"]
            for i, message in enumerate(inp["messages"], 1):
                role, content = message["role"], message["content"]
                lines += [f"move {literal(role)} to px-ctx-role({i})",
                          f"move {literal(content)} to px-ctx-content({i})",
                          f"move {len(content.encode())} to px-ctx-content-length({i})"]
            if inp["operation"] == "compact":
                lines += [f"move {inp['budget']['maxTokens']} to px-ctx-max-tokens",
                          f"move {inp['budget']['keepRecent']} to px-ctx-keep-recent"]
            lines.append('call "praxo-context" using px-context-request px-context-result')
            conditions = ["px-ctx-error = spaces"]
            if inp["operation"] == "estimate":
                conditions.append(f"px-ctx-tokens = {expect['tokens']}")
            else:
                conditions.append("px-ctx-ok = 1" if expect["ok"] else "px-ctx-ok = 0")
                if expect["ok"]:
                    conditions += [f"px-ctx-tokens = {expect['tokens']}",
                                   f"px-ctx-out-count = {len(expect['messages'])}"]
                    for i, message in enumerate(expect["messages"], 1):
                        content = message["content"]
                        conditions += [
                            f"px-ctx-out-content-length({i}) = {len(content.encode())}",
                            f"px-ctx-out-content({i})(1:px-ctx-out-content-length({i})) = {literal(content)}",
                            f"px-ctx-out-role({i}) = {literal(message['role'])}",
                        ]
            emit_checks(lines, label, conditions)
        elif group == "event":
            lines.append("initialize px-event-request px-event-result")
            lines += [f"move {literal(inp['sink'])} to px-evt-op",
                      f"move {len(inp['events'])} to px-evt-count"]
            for i, kind in enumerate(inp["events"], 1):
                lines.append(f"move {literal(kind)} to px-evt-events({i})")
            predicates = inp.get("predicateTypes", [])
            lines.append(f"move {len(predicates)} to px-evt-predicate-count")
            for i, kind in enumerate(predicates, 1):
                lines.append(f"move {literal(kind)} to px-evt-predicates({i})")
            lines.append(f"move {inp.get('sinkCount', 0)} to px-evt-sink-count")
            lines.append('call "praxo-event" using px-event-request px-event-result')
            conditions = ["px-evt-error = spaces"]
            if inp["sink"] == "multi":
                conditions.append(f"px-evt-sink-total = {inp['sinkCount']}")
                for i, kinds in enumerate(expect["perSink"], 1):
                    conditions.append(f"px-evt-sink-type-count({i}) = {len(kinds)}")
                    for j, kind in enumerate(kinds, 1):
                        conditions.append(f"px-evt-sink-types({i}, {j}) = {literal(kind)}")
            else:
                delivered = expect["delivered"] or []
                conditions.append(f"px-evt-delivered-count = {len(delivered)}")
                for i, kind in enumerate(delivered, 1):
                    conditions.append(f"px-evt-delivered({i}) = {literal(kind)}")
            emit_checks(lines, label, conditions)
        elif group == "checkpoint":
            lines.append("initialize px-checkpoint-request px-checkpoint-result")
            for name in inp.get("registered", []):
                lines += ["move \"register\" to px-ck-op",
                          f"move {literal(name)} to px-ck-type",
                          f"move {len(name.encode())} to px-ck-type-length",
                          'call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result']
                emit_checks(lines, label + " register", ["px-ck-error = spaces"])
            value = dump(inp["value"])
            if inp["operation"] == "unmarshal":
                envelope = dump({"type": inp["type"], "data": inp["value"]})
                lines += ["move \"unmarshal\" to px-ck-op",
                          f"move {literal(envelope)} to px-ck-value",
                          f"move {len(envelope.encode())} to px-ck-value-length",
                          'call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result']
                conditions = [f"px-ck-error(1:{len(expect['errorCode'])}) = {literal(expect['errorCode'])}"]
                emit_checks(lines, label, conditions)
            else:
                lines += ["move \"marshal\" to px-ck-op",
                          f"move {literal(inp['type'])} to px-ck-type",
                          f"move {len(inp['type'].encode())} to px-ck-type-length",
                          f"move {literal(value)} to px-ck-value",
                          f"move {len(value.encode())} to px-ck-value-length",
                          'call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result']
                if "errorCode" in expect:
                    emit_checks(lines, label, [
                        f"px-ck-error(1:{len(expect['errorCode'])}) = {literal(expect['errorCode'])}"])
                else:
                    emit_checks(lines, label + " marshal", ["px-ck-error = spaces"])
                    lines += ["move px-ck-output(1:px-ck-output-length) to px-ck-value",
                              "move px-ck-output-length to px-ck-value-length",
                              "move \"unmarshal\" to px-ck-op",
                              'call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result']
                    expected = dump(expect["value"])
                    emit_checks(lines, label, [
                        "px-ck-error = spaces",
                        f"px-ck-output-length = {len(expected.encode())}",
                        f"px-ck-output(1:px-ck-output-length) = {literal(expected)}",
                    ])
        elif group == "toolcall":
            lines.append("initialize px-toolcall-request px-toolcall-result")
            lines += [f"move {literal(inp['operation'])} to px-tc-op",
                      f"move {literal(inp['content'])} to px-tc-content",
                      f"move {len(inp['content'].encode())} to px-tc-length",
                      'call "praxo-toolcall" using px-toolcall-request px-toolcall-result']
            if inp["operation"] == "strip":
                emit_checks(lines, label, ["px-tc-error = spaces",
                                           f"px-tc-text-length = {len(expect['text'].encode())}",
                                           f"px-tc-text(1:{len(expect['text'].encode())}) = {literal(expect['text'])}"])
            else:
                conditions = ["px-tc-error = spaces"]
                if expect.get("nil"):
                    conditions.append("px-tc-found = 0")
                else:
                    conditions += ["px-tc-found = 1",
                                   f"px-tc-name-length = {len(expect['name'].encode())}",
                                   f"px-tc-name(1:{len(expect['name'].encode())}) = {literal(expect['name'])}"]
                    expected = dump(expect["input"])
                    conditions += [f"px-tc-input-length = {len(expected.encode())}",
                                   f"px-tc-input(1:{len(expected.encode())}) = {literal(expected)}"]
                emit_checks(lines, label, conditions)
        elif group == "jsonschema":
            lines.append("initialize px-schema-request px-schema-result")
            schema, value = dump(inp["schema"]), dump(inp["data"])
            lines += [f"move {literal(schema)} to px-sch-schema",
                      f"move {len(schema.encode())} to px-sch-schema-length",
                      f"move {literal(value)} to px-sch-data",
                      f"move {len(value.encode())} to px-sch-data-length",
                      'call "praxo-jsonschema" using px-schema-request px-schema-result']
            conditions = ["px-sch-error = spaces",
                          f"px-sch-error-count = {len(expect.get('errorPaths', []))}"]
            emit_checks(lines, label, conditions)
            for path in expect.get("errorPaths", []):
                lines += ["move 0 to assertion-ok",
                          "perform varying i from 1 by 1 until i > px-sch-error-count",
                          f"    if px-sch-path(i)(1:{len(path.encode())}) = {literal(path)}",
                          "        move 1 to assertion-ok",
                          "    end-if",
                          "end-perform",
                          f"move {literal(label + ' ' + path)} to assertion-label",
                          "perform assert-ok"]
        elif group == "plugin":
            raw = inp.get("raw") or dump(inp["manifest"])
            lines += ["initialize px-plugin-request px-plugin-result",
                      f"move {literal(raw)} to px-plug-raw",
                      f"move {len(raw.encode())} to px-plug-length",
                      'call "praxo-plugin" using px-plugin-request px-plugin-result']
            conditions = ["px-plug-valid = 1" if expect["valid"] else "px-plug-valid = 0"]
            if expect["valid"]:
                if "id" in expect:
                    conditions += [f"px-plug-id-length = {len(expect['id'].encode())}",
                                   f"px-plug-id(1:px-plug-id-length) = {literal(expect['id'])}"]
                if "kind" in expect:
                    conditions += [f"px-plug-kind-length = {len(expect['kind'].encode())}",
                                   f"px-plug-kind(1:px-plug-kind-length) = {literal(expect['kind'])}"]
            emit_checks(lines, label, conditions)
        elif group == "middleware":
            op = inp["operation"]
            lines.append("initialize px-middleware-request px-middleware-result")
            if op == "pii":
                lines += ["move \"pii\" to px-mw-op",
                          f"move {literal(inp['text'])} to px-mw-text",
                          f"move {len(inp['text'].encode())} to px-mw-text-length",
                          'call "praxo-middleware" using px-middleware-request px-middleware-result']
                expected = expect["text"]
                emit_checks(lines, label, ["px-mw-ok = 1",
                                           f"px-mw-result-length = {len(expected.encode())}",
                                           f"px-mw-result(1:px-mw-result-length) = {literal(expected)}"])
            elif op == "pii-value":
                value = dump(inp["value"])
                lines += ["move \"pii-json\" to px-mw-op",
                          f"move {literal(value)} to px-mw-text",
                          f"move {len(value.encode())} to px-mw-text-length",
                          'call "praxo-middleware" using px-middleware-request px-middleware-result']
                expected = dump(expect["value"])
                emit_checks(lines, label, ["px-mw-ok = 1",
                                           f"px-mw-result-length = {len(expected.encode())}",
                                           f"px-mw-result(1:px-mw-result-length) = {literal(expected)}"])
            elif op == "structured":
                schema, output = dump(inp["schema"]), inp["output"]
                lines += ["move \"structured\" to px-mw-op",
                          f"move {literal(schema)} to px-mw-schema",
                          f"move {len(schema.encode())} to px-mw-schema-length",
                          f"move {literal(output)} to px-mw-output",
                          f"move {len(output.encode())} to px-mw-output-length",
                          f"move {inp['maxRepairs']} to px-mw-max-repairs"]
                if "repairOutput" in inp:
                    repair = inp["repairOutput"]
                    lines += [f"move {literal(repair)} to px-mw-repair",
                              f"move {len(repair.encode())} to px-mw-repair-length"]
                lines.append('call "praxo-middleware" using px-middleware-request px-middleware-result')
                if expect["ok"]:
                    expected = expect["output"]
                    conditions = ["px-mw-ok = 1",
                                  f"px-mw-result-length = {len(expected.encode())}",
                                  f"px-mw-result(1:px-mw-result-length) = {literal(expected)}"]
                else:
                    conditions = [f"px-mw-error(1:{len(expect['errorCode'])}) = {literal(expect['errorCode'])}"]
                emit_checks(lines, label, conditions)
            elif op == "call-limit":
                lines += ["move \"call-limit\" to px-mw-op",
                          f"move {literal('r1')} to px-mw-run",
                          f"move {inp['modelLimit']} to px-mw-model-limit",
                          f"move {inp['toolLimit']} to px-mw-tool-limit"]
                for kind, outcome in zip(inp["calls"], expect["outcomes"], strict=True):
                    lines += [f"move {literal(kind)} to px-mw-kind",
                              'call "praxo-middleware" using px-middleware-request px-middleware-result']
                    if outcome == "ok":
                        conditions = ["px-mw-ok = 1", "px-mw-error = spaces"]
                    else:
                        conditions = [f"px-mw-error(1:{len(outcome)}) = {literal(outcome)}"]
                    emit_checks(lines, label + " " + kind, conditions)
            elif op == "tool-selection":
                lines += ["move \"tool-selection\" to px-mw-op",
                          f"move {len(inp['selected'])} to px-mw-selected-count"]
                for i, name in enumerate(inp["selected"], 1):
                    lines.append(f"move {literal(name)} to px-mw-selected({i})")
                lines.append(f"move {len(inp['tools'])} to px-mw-tool-count")
                for i, name in enumerate(inp["tools"], 1):
                    lines.append(f"move {literal(name)} to px-mw-tools({i})")
                lines += [f"move {literal(inp['requested'])} to px-mw-requested",
                          f"move {len(inp['requested'].encode())} to px-mw-requested-length",
                          'call "praxo-middleware" using px-middleware-request px-middleware-result']
                conditions = [f"px-mw-advertised-count = {len(expect['advertised'])}"]
                for i, name in enumerate(expect["advertised"], 1):
                    conditions.append(f"px-mw-advertised({i}) = {literal(name)}")
                conditions.append(
                    f"px-mw-error(1:{len(expect['reject'])}) = {literal(expect['reject'])}")
                emit_checks(lines, label, conditions)
            elif op == "fallback":
                lines += ["move \"fallback\" to px-mw-op",
                          f"move {literal(inp['fallbackContent'])} to px-mw-fallback",
                          f"move {len(inp['fallbackContent'].encode())} to px-mw-fallback-length",
                          'call "praxo-middleware" using px-middleware-request px-middleware-result']
                expected = expect["output"]
                emit_checks(lines, label, ["px-mw-ok = 1",
                                           f"px-mw-result(1:px-mw-result-length) = {literal(expected)}"])
            else:
                raise ValueError(f"unknown middleware operation: {op}")
        elif group == "policy":
            lines.append("initialize px-policy-request px-policy-result")
            lines.append(f"move {len(inp['grants'])} to px-pol-grant-count")
            for i, grant in enumerate(inp["grants"], 1):
                root, access = grant["root"], grant["access"]
                lines += [f"move {literal(root)} to px-pol-root({i})",
                          f"move {len(root.encode())} to px-pol-root-length({i})",
                          f"move {literal(access)} to px-pol-access({i})",
                          f"move {len(access.encode())} to px-pol-access-length({i})"]
            target, need = inp["target"], inp["need"]
            lines += [f"move {literal(target)} to px-pol-target",
                      f"move {len(target.encode())} to px-pol-target-length",
                      f"move {literal(need)} to px-pol-need",
                      f"move {len(need.encode())} to px-pol-need-length",
                      'call "praxo-policy" using px-policy-request px-policy-result']
            if expect.get("error"):
                conditions = ["px-pol-error not = spaces"]
            else:
                conditions = ["px-pol-error = spaces",
                              "px-pol-allowed = 1" if expect["allowed"] else "px-pol-allowed = 0"]
            emit_checks(lines, label, conditions)
        elif group == "stream":
            lines += ["initialize px-stream-result",
                      'call "praxo-stream" using px-stream-result']
            conditions = [f"px-stream-count = {len(expect['kinds'])}"]
            for i, kind in enumerate(expect["kinds"], 1):
                conditions.append(f"px-stream-kind({i}) = {literal(kind)}")
            emit_checks(lines, label, conditions)
        else:
            raise ValueError(group)
    lines += [
        "if failures = 0",
        f"    display \"PASS: {len(data['vectors'])} vectors in {group}\"",
        "else",
        f"    display \"FAIL: {group} assertions=\" failures",
        "    move 1 to return-code",
        "end-if",
        "goback.",
        "assert-ok.",
        "    add 1 to checks",
        "    if assertion-ok = 0",
        "        add 1 to failures",
        '        display "FAIL: " assertion-label',
        "    end-if.",
        f"end program fixture-{group}.",
    ]
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate_all(root, build):
    available = {path.stem for path in (root.parent / "spec" / "vectors").glob("*.json")}
    if set(GROUPS) != available:
        raise ValueError(f"vector group inventory changed: {sorted(available ^ set(GROUPS))}")
    outputs = []
    for group in GROUPS:
        data = json.loads((root.parent / "spec" / "vectors" / f"{group}.json").read_text(encoding="utf-8"))
        if data["specVersion"] != "0.2.0" or data["group"] != group:
            raise ValueError(f"unsupported contract: {group}")
        destination = build / f"fixture_{group.replace('-', '_')}.cob"
        generate_group(root, destination, group, data)
        outputs.append((group, destination, len(data["vectors"])))
    return outputs

