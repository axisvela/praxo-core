struct Outcome {
mut:
	output string
	code   string
	calls  int
}

fn run_retry(failures int, max_attempts int) Outcome {
	for attempt in 1 .. max_attempts + 1 {
		if attempt > failures {
			return Outcome{
				output: 'status: green'
				calls: attempt
			}
		}
	}
	return Outcome{
		code: 'MODEL_UNAVAILABLE'
		calls: max_attempts
	}
}

fn main() {
	recovered := run_retry(2, 3)
	assert recovered.output == 'status: green' && recovered.calls == 3
	exhausted := run_retry(3, 3)
	assert exhausted.code == 'MODEL_UNAVAILABLE' && exhausted.calls == 3
	println('V retry example passed')
}
