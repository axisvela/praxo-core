module main

import os
import time
import praxo
import x.json2

struct Config {
    name string
    version string
    entry string
}

struct State {
mut:
    reads int
    drafts int
}

fn version_valid(version string) bool {
    parts := version.split('.')
    if parts.len != 3 { return false }
    for part in parts {
        if part.len == 0 { return false }
        if part.len > 1 && part[0] == `0` { return false }
        for ch in part.bytes() {
            if ch < `0` || ch > `9` { return false }
        }
    }
    return true
}

fn check_config(root string) !json2.Any {
    text := os.read_file(os.join_path(root, 'app.json'))!
    config := json2.decode[Config](text)!
    mut issues := []json2.Any{}
    if config.name.trim_space() == '' { issues << json2.Any('missing_name') }
    if !version_valid(config.version) { issues << json2.Any('invalid_version') }
    if config.entry != 'main.v' {
        issues << json2.Any('entry_outside_allowlist')
    } else if !os.is_file(os.join_path(root, config.entry)) {
        issues << json2.Any('entry_missing')
    }
    return json2.Any({
        'issues': json2.Any(issues)
        'valid': json2.Any(issues.len == 0)
        'checked_file': json2.Any('app.json')
    })
}

fn fixture_model(workspace string) &praxo.Model {
    return praxo.callback_model(fn [workspace] (request praxo.Request) !praxo.Response {
        mut results := []json2.Any{}
        for message in request.messages {
            if message.role == praxo.role_tool {
                results << praxo.parse_json(message.content)!
            }
        }
        if results.len == 0 {
            return praxo.response(praxo.message_assistant('', [
                praxo.tool_call('check-1', 'check_config', {'workspace': json2.Any(workspace)}),
            ]), praxo.usage(0, 0))
        }
        failure := praxo.get_string(results[0], 'error') or { '' }
        if failure != '' {
            return praxo.response(praxo.message_assistant(failure, []praxo.ToolCall{}), praxo.usage(0, 0))
        }
        if results.len == 1 {
            action := if praxo.get_bool(results[0], 'valid', false) { 'review_release' } else { 'review_corrections' }
            return praxo.response(praxo.message_assistant('', [
                praxo.tool_call('draft-1', 'draft_review', {
                    'workspace': json2.Any(workspace)
                    'action': json2.Any(action)
                }),
            ]), praxo.usage(0, 0))
        }
        report := json2.Any({'checks': results[0], 'review': results[1], 'deployments': json2.Any(0)})
        return praxo.response(praxo.message_assistant(praxo.encode_json(report), []praxo.ToolCall{}), praxo.usage(0, 0))
    })
}

fn run_case(workspace string, root string) (string, int, int, string) {
    mut state := &State{}
    mut reader := praxo.func_tool('check_config', 'Read fixed app.json and check local release prerequisites.')
    reader.invoke = fn [mut state, root] (_ map[string]json2.Any) json2.Any {
        state.reads++
        return check_config(root) or { json2.Any({'error': json2.Any('CONFIG_UNAVAILABLE_OR_INVALID')}) }
    }
    mut draft := praxo.func_tool('draft_review', 'Draft review only; never deploys or executes commands.')
    draft.invoke = fn [mut state] (args map[string]json2.Any) json2.Any {
        state.drafts++
        return json2.Any({
            'action': args['action'] or { json2.Any('') }
            'status': json2.Any('draft_only')
            'review_required': json2.Any(true)
            'deployments': json2.Any(0)
        })
    }
    mut options := praxo.agent_options(fixture_model(workspace))
    options.tools = [reader, draft]
    options.allowed_tools = ['check_config', 'draft_review']
    options.require_policy = true
    options.require_tool_scope = true
    options.max_steps = 4
    options.policy_action = fn (action praxo.Action) praxo.Decision {
        if action.kind == 'model.generate' { return praxo.Decision{allowed: true} }
        if action.kind != 'tool.invoke' { return praxo.Decision{allowed: false} }
        scope := praxo.get_string(json2.Any(action.arguments), 'workspace') or { '' }
        if scope != 'workspace-100' {
            return praxo.Decision{allowed: false, reason: 'workspace outside scope'}
        }
        if action.tool_name == 'check_config' { return praxo.Decision{allowed: true} }
        choice := praxo.get_string(json2.Any(action.arguments), 'action') or { '' }
        return praxo.Decision{allowed: action.tool_name == 'draft_review' && choice in ['review_release', 'review_corrections']}
    }
    result := praxo.run_agent(options, praxo.session('preflight', []praxo.Message{}),
        'Check configuration and draft the appropriate review without deploying.') or {
        return '', state.reads, state.drafts, err.msg()
    }
    return result.output, state.reads, state.drafts, ''
}

fn run_tests(root string) ! {
    good := '{"name":"demo","version":"1.2.3","entry":"main.v"}'
    os.write_file(os.join_path(root, 'app.json'), good)!
    output, reads, drafts, failure := run_case('workspace-100', root)
    assert failure == '' && reads == 1 && drafts == 1
    report := praxo.parse_json(output)!
    review := praxo.get_object(report, 'review')
    assert (praxo.get_string(json2.Any(review), 'action') or { '' }) == 'review_release'
    _, denied_reads, denied_drafts, denied := run_case('workspace-200', root)
    assert denied.contains('AGENT_POLICY_DENIED') && denied_reads == 0 && denied_drafts == 0
    os.write_file(os.join_path(root, 'app.json'), '{"version":"v1","entry":"../outside.v"}')!
    bad_output, _, bad_drafts, bad_failure := run_case('workspace-100', root)
    assert bad_failure == '' && bad_drafts == 1
    bad := praxo.parse_json(bad_output)!
    checks := praxo.get_object(bad, 'checks')
    assert praxo.get_array(json2.Any(checks), 'issues').len == 3
    bad_review := praxo.get_object(bad, 'review')
    assert (praxo.get_string(json2.Any(bad_review), 'action') or { '' }) == 'review_corrections'
    os.write_file(os.join_path(root, 'app.json'), good)!
    os.rm(os.join_path(root, 'main.v'))!
    missing := check_config(root)!
    assert praxo.get_array(missing, 'issues').len == 1
    os.write_file(os.join_path(root, 'app.json'), '{')!
    malformed, _, malformed_drafts, _ := run_case('workspace-100', root)
    assert malformed == 'CONFIG_UNAVAILABLE_OR_INVALID' && malformed_drafts == 0
    os.rm(os.join_path(root, 'app.json'))!
    unavailable, failed_reads, failed_drafts, _ := run_case('workspace-100', root)
    assert unavailable == 'CONFIG_UNAVAILABLE_OR_INVALID' && failed_reads == 1 && failed_drafts == 0
    assert !version_valid('01.2.3') && !version_valid('1.2') && version_valid('0.2.10')
    println('V release-preflight tutorial: configuration, branches, denial and failure passed')
}

fn main() {
    root := os.join_path(os.temp_dir(), 'praxo-preflight-${os.getpid()}-${time.now().unix_nano()}')
    os.mkdir(root) or { panic(err) }
    defer { os.rmdir_all(root) or {} }
    os.write_file(os.join_path(root, 'main.v'), 'module main\nfn main() {}\n') or { panic(err) }
    if '--test' in os.args {
        run_tests(root) or { panic(err) }
        return
    }
    config := if '--invalid' in os.args { '{"version":"bad","entry":"../outside.v"}' } else {
        '{"name":"demo","version":"1.2.3","entry":"main.v"}'
    }
    if '--simulate-failure' !in os.args {
        os.write_file(os.join_path(root, 'app.json'), config) or { panic(err) }
    }
    workspace := if '--deny' in os.args { 'workspace-200' } else { 'workspace-100' }
    output, reads, drafts, failure := run_case(workspace, root)
    if failure != '' || output == 'CONFIG_UNAVAILABLE_OR_INVALID' {
        eprintln('${failure}${output} reads=${reads} drafts=${drafts}')
        exit(1)
    }
    println(output)
}
