fn run_fallback(primary_fails bool, fallback_fails bool) string {
	if !primary_fails {
		return 'primary'
	}
	if !fallback_fails {
		return 'fallback'
	}
	return 'MODEL_UNAVAILABLE'
}

fn main() {
	assert run_fallback(false, false) == 'primary'
	assert run_fallback(true, false) == 'fallback'
	assert run_fallback(true, true) == 'MODEL_UNAVAILABLE'
	println('V provider fallback example passed')
}
