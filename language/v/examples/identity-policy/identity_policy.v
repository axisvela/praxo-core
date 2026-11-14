fn authorize(tenant string, role string, active bool, tool string, target string) bool {
	return active && role == 'operator' && tenant == target && tool == 'record'
}

fn main() {
	assert authorize('acme', 'operator', true, 'record', 'acme')
	assert !authorize('acme', 'viewer', true, 'record', 'acme')
	assert !authorize('acme', 'operator', true, 'record', 'other')
	println('V identity policy example passed')
}
