module praxo

import time
import x.json2

pub fn praxo_error(code string, message string) IError {
	return error('${code}|${message}')
}

pub fn error_code(value IError) string {
	parts := value.msg().split('|')
	if parts.len > 0 {
		return parts[0]
	}
	return ''
}

@[heap]
pub struct Sink {
pub mut:
	kinds     []string
	mode      string
	predicate []string
	target    &Sink = unsafe { nil }
	sinks     []&Sink
}

pub fn (mut s Sink) emit(event Event) {
	if s.mode == 'filter' {
		if s.predicate.len == 0 || event.kind in s.predicate {
			if s.target != unsafe { nil } {
				s.target.emit(event)
			}
		}
		return
	}
	if s.mode == 'multi' {
		for mut child in s.sinks {
			child.emit(event)
		}
		return
	}
	s.kinds << event.kind
}

pub fn multi_sink(sinks []&Sink) &Sink {
	return &Sink{mode: 'multi', sinks: sinks}
}

pub fn filter_sink(target &Sink, predicate []string) &Sink {
	return &Sink{mode: 'filter', target: target, predicate: predicate}
}

pub struct MemoryStore {
pub mut:
	records  map[string][]MemoryRecord
	sequence int
}

pub fn memory_store() &MemoryStore {
	return &MemoryStore{}
}

pub fn (mut store MemoryStore) put(session_id string, record MemoryRecord) MemoryRecord {
	mut value := record
	if value.id == '' {
		value.id = 'mem-${time.now().unix()}-${store.sequence}'
		store.sequence++
	}
	if value.created_at == '' {
		value.created_at = '${time.now().unix()}'
	}
	store.records[session_id] << value
	return value
}

pub fn (mut store MemoryStore) search(session_id string, query string, limit int) []MemoryRecord {
	records := store.records[session_id] or { return []MemoryRecord{} }
	needle := query.trim_space().to_lower()
	mut matches := []MemoryRecord{}
	for record in records {
		if needle == '' || record.content.to_lower().contains(needle) {
			matches << record
		}
	}
	mut index := 1
	for index < matches.len {
		current := matches[index]
		mut position := index
		for position > 0 && matches[position - 1].created_at < current.created_at {
			matches[position] = matches[position - 1]
			position--
		}
		matches[position] = current
		index++
	}
	if limit > 0 && matches.len > limit {
		return matches[0..limit]
	}
	return matches
}

pub struct CheckpointAllowlist {
pub mut:
	registered map[string]bool
}

pub fn checkpoint_allowlist() &CheckpointAllowlist {
	return &CheckpointAllowlist{}
}

pub fn (mut allow CheckpointAllowlist) register(kind string) !void {
	if kind == '' {
		return praxo_error('CHECKPOINT_ERROR', 'checkpoint: type is required')
	}
	allow.registered[kind] = true
}

pub fn (mut allow CheckpointAllowlist) marshal(kind string, value json2.Any) !string {
	if kind !in allow.registered {
		return praxo_error('CHECKPOINT_TYPE_NOT_ALLOWED', 'checkpoint: payload type not allowed')
	}
	mut envelope := map[string]json2.Any{}
	envelope['type'] = json2.Any(kind)
	envelope['data'] = value
	return encode_json(json2.Any(envelope))
}

pub fn (mut allow CheckpointAllowlist) unmarshal(data string) !json2.Any {
	envelope := parse_json(data) or {
		return praxo_error('CHECKPOINT_ERROR', 'checkpoint: invalid envelope')
	}
	if !is_object(envelope) {
		return praxo_error('CHECKPOINT_ERROR', 'checkpoint: envelope must be an object')
	}
	kind := get_string(envelope, 'type') or { '' }
	if kind !in allow.registered {
		return praxo_error('CHECKPOINT_TYPE_NOT_ALLOWED', 'checkpoint: payload type not allowed')
	}
	return get(envelope, 'data') or { json2.null }
}

pub fn normalize_path(value string) string {
	path := value.replace('\\', '/')
	mut prefix := ''
	mut body := path
	if body.len >= 2 && body[1] == `:` {
		prefix = body.substr(0, 2)
		body = body.substr(2, body.len)
	} else if body.starts_with('/') {
		prefix = '/'
	}
	mut parts := []string{}
	for part in body.split('/') {
		if part == '' || part == '.' {
			continue
		}
		if part == '..' {
			if parts.len > 0 && parts[parts.len - 1] != '..' {
				parts.delete_last()
			} else if !body.starts_with('/') {
				parts << part
			}
			continue
		}
		parts << part
	}
	mut result := prefix + parts.join('/')
	$if windows {
		result = result.to_lower()
	}
	return result
}

fn path_within(root string, target string) bool {
	if root == target {
		return true
	}
	return target.starts_with(root + '/')
}

fn access_allows(grant string, need string) bool {
	if need == 'read' {
		return grant == 'read' || grant == 'readwrite'
	}
	if need == 'write' {
		return grant == 'write' || grant == 'readwrite'
	}
	return grant == 'readwrite'
}

pub struct PathChecker {
pub:
	grants []PathGrant
}

pub fn path_checker(grants []PathGrant) !PathChecker {
	mut normalized := []PathGrant{cap: grants.len}
	for grant in grants {
		if grant.root == '' {
			return praxo_error('POLICY_ERROR', 'policy: path grant root is required')
		}
		if grant.access !in ['read', 'write', 'readwrite'] {
			return praxo_error('POLICY_ERROR', 'policy: invalid grant access')
		}
		normalized << PathGrant{root: normalize_path(grant.root), access: grant.access}
	}
	return PathChecker{grants: normalized}
}

pub fn (checker PathChecker) check(target string, need string) !Decision {
	if need !in ['read', 'write', 'readwrite'] {
		return praxo_error('POLICY_ERROR', 'policy: invalid requested access')
	}
	if checker.grants.len == 0 {
		return Decision{allowed: false, reason: 'no allowed roots'}
	}
	resolved := normalize_path(target)
	mut matched := false
	for grant in checker.grants {
		if path_within(grant.root, resolved) {
			matched = true
			if access_allows(grant.access, need) {
				return Decision{allowed: true, reason: 'allowed'}
			}
		}
	}
	return Decision{
		allowed: false
		reason: if matched { 'insufficient grant' } else { 'outside roots' }
	}
}

pub fn path_allowed(checker PathChecker, target string, need string) bool {
	result := checker.check(target, need) or { return false }
	return result.allowed
}

pub fn estimate_tokens(messages []Message) int {
	mut total := 0
	for item in messages {
		total += 4 + item.content.len / 4 + item.tool_id.len / 4
		for block in item.content_blocks {
			total += 4 + block.text.len / 4
		}
		for call in item.tool_calls {
			total += 4 + call.name.len / 4 + encode_json(json2.Any(call.arguments)).len / 4
		}
	}
	return total
}

pub fn truncate_to_tokens(value string, tokens int) string {
	if tokens <= 0 {
		return ''
	}
	limit := tokens * 4
	if value.len <= limit {
		return value
	}
	if limit <= 16 {
		return value.substr(0, limit)
	}
	return value.substr(0, limit - 16) + '\n[truncated]'
}

pub fn compact_context(budget ContextBudget, messages []Message) ([]Message, bool) {
	if budget.max_tokens <= 0 || estimate_tokens(messages) <= budget.max_tokens {
		return messages, true
	}
	mut system := []Message{}
	mut rest := []Message{}
	for item in messages {
		if item.role == role_system {
			if !item.content.starts_with('[context compacted:') {
				system << item
			}
		} else {
			rest << item
		}
	}
	if estimate_tokens(system) > budget.max_tokens {
		if system.len == 0 {
			return []Message{}, false
		}
		first := system[0]
		system = [Message{
			role: first.role
			content: truncate_to_tokens(first.content, budget.max_tokens - 4)
			content_blocks: first.content_blocks
			tool_calls: first.tool_calls
			tool_id: first.tool_id
		}]
		if estimate_tokens(system) > budget.max_tokens {
			return []Message{}, false
		}
	}
	keep := if budget.keep_recent > 0 { budget.keep_recent } else { 4 }
	mut start := if rest.len > keep { rest.len - keep } else { 0 }
	for start > 0 && rest[start].role == role_tool {
		start--
	}
	marker := message(role_system, '[context compacted: ${start} older messages omitted]')
	mut kept := if start >= rest.len { []Message{} } else { rest[start..rest.len] }
	mut output := []Message{}
	output << system
	if start > 0 {
		output << marker
	}
	output << kept
	for estimate_tokens(output) > budget.max_tokens && kept.len > 1 {
		if kept[1].role == role_tool {
			break
		}
		kept = kept[1..kept.len].clone()
		output = []Message{}
		output << system
		if start > 0 {
			output << marker
		}
		output << kept
	}
	return output, estimate_tokens(output) <= budget.max_tokens
}
