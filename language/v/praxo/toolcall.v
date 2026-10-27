module praxo

import x.json2

pub fn parse_input_json(raw string) ?map[string]json2.Any {
	value := parse_json(raw.trim_space()) or { return none }
	if value is map[string]json2.Any {
		return value
	}
	return none
}

fn parse_json_call(content string) ?ToolCall {
	value := parse_json(content) or { return none }
	object := as_object(value)
	name := as_string(object['name'] or { json2.null }) or { return none }
	if name == '' {
		return none
	}
	input := as_object(object['input'] or { json2.null })
	return ToolCall{
		name: name
		arguments: input
	}
}

fn find_matching_brace(text string, start int) ?int {
	mut depth := 0
	mut in_string := false
	mut escaped := false
	mut index := start
	for index < text.len {
		character := text[index]
		if in_string {
			if escaped {
				escaped = false
			} else if character == `\\` {
				escaped = true
			} else if character == `"` {
				in_string = false
			}
		} else if character == `"` {
			in_string = true
		} else if character == `{` {
			depth++
		} else if character == `}` {
			depth--
			if depth == 0 {
				return index
			}
		}
		index++
	}
	return none
}

fn parse_xml(content string) ?ToolCall {
	start := content.last_index('<tool_call') or { return none }
	rest := content.substr(start, content.len)
	name_open := rest.index('name="') or { return none }
	name_start := name_open + 6
	name_end := rest.index_after('"', name_start) or { return none }
	name := rest.substr(name_start, name_end)
	if name == '' {
		return none
	}
	open_end := rest.index_after('>', name_end) or { return none }
	close := rest.last_index('</tool_call>') or { rest.len }
	if close <= open_end {
		return none
	}
	input := parse_input_json(rest.substr(open_end + 1, close)) or { return none }
	return ToolCall{name: name, arguments: input}
}

fn parse_tag(content string) ?ToolCall {
	mut search := 0
	mut name := ''
	mut body := ''
	for {
		start := content.index_after('<', search) or { break }
		end := content.index_after('>', start + 1) or { break }
		candidate := content.substr(start + 1, end).trim_space()
		search = end + 1
		if candidate == '' || candidate.starts_with('/') || candidate.contains(' ')
			|| candidate.contains('\t') || candidate.contains('\n') {
			continue
		}
		if !candidate.contains('.') {
			continue
		}
		after := if end + 1 < content.len { content.substr(end + 1, content.len).trim_space() } else { '' }
		if !after.starts_with('{') {
			name = candidate
			body = after
			continue
		}
		brace_end := find_matching_brace(after, 0) or { continue }
		name = candidate
		body = after.substr(0, brace_end + 1)
	}
	if name == '' {
		return none
	}
	input := parse_input_json(body) or { return none }
	return ToolCall{name: name, arguments: input}
}

fn parse_plain(content string) ?ToolCall {
	for line in content.split_into_lines() {
		line_trimmed := line.trim_space()
		if line_trimmed == '' || line_trimmed.starts_with('{') {
			continue
		}
		space := line_trimmed.index(' ') or { continue }
		name := line_trimmed.substr(0, space)
		if !name.contains('.') || name.starts_with('<') {
			continue
		}
		raw := line_trimmed.substr(space + 1, line_trimmed.len).trim_space()
		if !raw.starts_with('{') {
			continue
		}
		input := parse_input_json(raw) or { continue }
		return ToolCall{name: name, arguments: input}
	}
	return none
}

pub fn parse_tool_call(content string) ?ToolCall {
	if call := parse_json_call(content) {
		return call
	}
	if call := parse_xml(content) {
		return call
	}
	if call := parse_tag(content) {
		return call
	}
	return parse_plain(content)
}

fn remove_between(text string, open_prefix string, close_tag string) string {
	mut output := text
	for {
		start := output.index(open_prefix) or { break }
		close := output.index_after(close_tag, start) or { break }
		end := close + close_tag.len
		output = output.substr(0, start) + output.substr(end, output.len)
	}
	return output
}

fn remove_dotted_tags(text string) string {
	mut output := text
	mut search := 0
	for {
		start := output.index_after('<', search) or { break }
		end := output.index_after('>', start + 1) or { break }
		name := output.substr(start + 1, end).trim_space()
		if name == '' || name.starts_with('/') || !name.contains('.') {
			search = end + 1
			continue
		}
		close_tag := '</${name}>'
		close := output.index_after(close_tag, end + 1) or {
			output = output.substr(0, start)
			break
		}
		finish := close + close_tag.len
		output = output.substr(0, start) + output.substr(finish, output.len)
		search = start
	}
	return output
}

pub fn strip_tool_call_markup(content string) string {
	mut output := remove_between(content, '<tool_call name="', '</tool_call>')
	output = remove_between(output, '<tool_call_invoke>', '</tool_call_invoke>')
	output = remove_dotted_tags(output)
	for output.contains('\n\n\n') {
		output = output.replace('\n\n\n', '\n\n')
	}
	return output.trim_space()
}
