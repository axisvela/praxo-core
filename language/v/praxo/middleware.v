module praxo

import x.json2

fn is_email_local(character u8) bool {
	return (character >= `a` && character <= `z`) || (character >= `A` && character <= `Z`)
		|| (character >= `0` && character <= `9`) || character == `.` || character == `_`
		|| character == `%` || character == `+` || character == `-`
}

fn is_domain_character(character u8) bool {
	return (character >= `a` && character <= `z`) || (character >= `A` && character <= `Z`)
		|| (character >= `0` && character <= `9`) || character == `.` || character == `-`
}

fn is_alpha(character u8) bool {
	return (character >= `a` && character <= `z`) || (character >= `A` && character <= `Z`)
}

fn is_digit(character u8) bool {
	return character >= `0` && character <= `9`
}

fn redact_email(text string) string {
	mut output := ''
	mut index := 0
	for index < text.len {
		if text[index] == `@` {
			mut start := index
			for start > 0 && is_email_local(text[start - 1]) {
				start--
			}
			mut end := index + 1
			for end < text.len && is_domain_character(text[end]) {
				end++
			}
			for end > index + 1 && text[end - 1] == `.` {
				end--
			}
			if end > index + 1 {
				domain := text.substr(index + 1, end)
				dot := domain.last_index('.') or { -1 }
				if dot > 0 && domain.len - dot - 1 >= 2 {
					mut valid_tld := true
					for position := dot + 1; position < domain.len; position++ {
						if !is_alpha(domain[position]) {
							valid_tld = false
						}
					}
					if valid_tld {
						output = output.substr(0, output.len - (index - start))
						output += '[REDACTED:email]'
						index = end
						continue
					}
				}
			}
		}
		output += text.substr(index, index + 1)
		index++
	}
	return output
}

fn redact_ssn(text string) string {
	mut output := ''
	mut index := 0
	for index < text.len {
		if index + 11 <= text.len && is_digit(text[index]) && is_digit(text[index + 1])
			&& is_digit(text[index + 2]) && text[index + 3] == `-` && is_digit(text[index + 4])
			&& is_digit(text[index + 5]) && text[index + 6] == `-` && is_digit(text[index + 7])
			&& is_digit(text[index + 8]) && is_digit(text[index + 9]) && is_digit(text[index + 10]) {
			output += '[REDACTED:ssn]'
			index += 11
			continue
		}
		output += text.substr(index, index + 1)
		index++
	}
	return output
}

fn credit_card_at(text string, start int) int {
	mut index := start
	for group := 0; group < 4; group++ {
		if group > 0 && index < text.len && (text[index] == ` ` || text[index] == `-`) {
			index++
		}
		for digit := 0; digit < 4; digit++ {
			if index >= text.len || !is_digit(text[index]) {
				return start
			}
			index++
		}
	}
	return index
}

fn redact_credit_card(text string) string {
	mut output := ''
	mut index := 0
	for index < text.len {
		end := credit_card_at(text, index)
		if end > index {
			output += '[REDACTED:credit_card]'
			index = end
			continue
		}
		output += text.substr(index, index + 1)
		index++
	}
	return output
}

fn is_word_char(character u8) bool {
	return is_alpha(character) || is_digit(character) || character == `_`
}

fn take_digits(text string, start int, count int) int {
	mut index := start
	mut digit := 0
	for digit < count {
		if index >= text.len || !is_digit(text[index]) {
			return -1
		}
		index++
		digit++
	}
	return index
}

fn skip_separator(text string, index int) int {
	if index < text.len && (text[index] == `-` || text[index] == `.` || text[index] == ` `) {
		return index + 1
	}
	return index
}

fn phone_end_without_prefix(text string, start int) int {
	mut index := start
	if index < text.len && text[index] == `(` {
		index++
	}
	index = take_digits(text, index, 3)
	if index < 0 {
		return start
	}
	if index < text.len && text[index] == `)` {
		index++
	}
	index = skip_separator(text, index)
	index = take_digits(text, index, 3)
	if index < 0 {
		return start
	}
	index = skip_separator(text, index)
	index = take_digits(text, index, 4)
	if index < 0 {
		return start
	}
	return index
}

fn phone_at(text string, start int) int {
	if start > 0 && is_word_char(text[start - 1]) {
		return start
	}
	mut best := start
	direct := phone_end_without_prefix(text, start)
	if direct > start && (direct >= text.len || !is_word_char(text[direct])) {
		best = direct
	}
	mut index := start
	if index < text.len && text[index] == `+` {
		if index + 1 < text.len && text[index + 1] == `1` {
			index += 2
		} else {
			return best
		}
	} else if index < text.len && text[index] == `1` {
		index++
	} else {
		return best
	}
	index = skip_separator(text, index)
	prefixed := phone_end_without_prefix(text, index)
	if prefixed > index && (prefixed >= text.len || !is_word_char(text[prefixed])) && prefixed > best {
		best = prefixed
	}
	return best
}

fn redact_phone(text string) string {
	mut output := ''
	mut index := 0
	for index < text.len {
		ending := phone_at(text, index)
		if ending > index {
			output += '[REDACTED:phone]'
			index = ending
			continue
		}
		output += text.substr(index, index + 1)
		index++
	}
	return output
}

pub fn pii_redact(text string) string {
	mut output := redact_email(text)
	output = redact_ssn(output)
	output = redact_credit_card(output)
	return redact_phone(output)
}

pub fn redact_value(value json2.Any) json2.Any {
	if value is string {
		return json2.Any(pii_redact(value as string))
	}
	if value is []json2.Any {
		mut items := []json2.Any{cap: (value as []json2.Any).len}
		for item in (value as []json2.Any) {
			items << redact_value(item)
		}
		return json2.Any(items)
	}
	if value is map[string]json2.Any {
		mut output := map[string]json2.Any{}
		for key, item in (value as map[string]json2.Any) {
			output[key] = redact_value(item)
		}
		return json2.Any(output)
	}
	return value
}

pub fn extract_json(text string) ?json2.Any {
	mut value := text.trim_space()
	if value == '' {
		return none
	}
	if value.starts_with('```') {
		mut body := value.substr(3, value.len)
		if newline := body.index('\n') {
			body = body.substr(newline + 1, body.len)
		}
		if close := body.last_index('```') {
			body = body.substr(0, close)
		}
		value = body.trim_space()
	}
	mut start := value.len
	object := value.index('{') or { value.len }
	array := value.index('[') or { value.len }
	if object < start {
		start = object
	}
	if array < start {
		start = array
	}
	if start >= value.len {
		return none
	}
	return parse_json(value.substr(start, value.len)) or { return none }
}

pub struct StructuredOutput {
pub mut:
	schema      json2.Any
	max_repairs int
	repairer    ?fn (text string) string
}

pub fn structured_output(schema json2.Any, max_repairs int, repairer ?fn (text string) string) StructuredOutput {
	return StructuredOutput{schema: schema, max_repairs: max_repairs, repairer: repairer}
}

pub fn (config StructuredOutput) apply(text string) (string, string) {
	mut output := text
	for attempt := 0; attempt <= config.max_repairs; attempt++ {
		value := extract_json(output) or { json2.null }
		if !is_null(value) && validate_schema(config.schema, value).len == 0 {
			return output, ''
		}
		if attempt == config.max_repairs {
			break
		}
		if repairer := config.repairer {
			repaired := repairer(output)
			if repaired.trim_space() == '' {
				break
			}
			output = repaired
		} else {
			break
		}
	}
	return '', 'AGENT_STRUCTURED_OUTPUT'
}

pub struct CallLimit {
pub mut:
	model_limit int
	tool_limit  int
	models      int
	tools       int
}

pub fn call_limit(model_limit int, tool_limit int) &CallLimit {
	return &CallLimit{model_limit: model_limit, tool_limit: tool_limit}
}

pub fn (mut limit CallLimit) model_call() !void {
	limit.models++
	if limit.model_limit > 0 && limit.models > limit.model_limit {
		return praxo_error('AGENT_MODEL_CALL_LIMIT', 'model call limit')
	}
}

pub fn (mut limit CallLimit) tool_call() !void {
	limit.tools++
	if limit.tool_limit > 0 && limit.tools > limit.tool_limit {
		return praxo_error('AGENT_TOOL_CALL_LIMIT', 'tool call limit')
	}
}

pub struct ToolSelection {
pub:
	selected map[string]bool
}

pub fn tool_selection(selected []string) ToolSelection {
	mut lookup := map[string]bool{}
	for name in selected {
		lookup[name] = true
	}
	return ToolSelection{selected: lookup}
}

pub fn select_tools(selection ToolSelection, tools []ToolSpec) []ToolSpec {
	mut output := []ToolSpec{}
	for tool in tools {
		if tool.name in selection.selected {
			output << tool
		}
	}
	return output
}

pub fn check_tool_selected(selection ToolSelection, name string) !void {
	if name !in selection.selected {
		return praxo_error('AGENT_TOOL_NOT_SELECTED', 'tool not selected')
	}
}
