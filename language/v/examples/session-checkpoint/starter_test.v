module main

fn test_session_checkpoint_restores_four_messages() {
	outcome := run() or { panic(err) }
	assert outcome.restored_messages == 4
	assert outcome.output == 'turn 5'
}
