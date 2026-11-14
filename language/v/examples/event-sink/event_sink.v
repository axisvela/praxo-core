module main

import praxo

fn main() {
	all := &praxo.Sink{}
	tool := &praxo.Sink{}
	filtered := praxo.filter_sink(tool, ['tool.call'])
	mut multi := praxo.multi_sink([all, filtered])
	for kind in ['run.started', 'tool.call', 'run.completed'] {
		multi.emit(praxo.Event{ kind: kind, session_id: 's1' })
	}
	assert all.kinds == ['run.started', 'tool.call', 'run.completed']
	assert tool.kinds == ['tool.call']
	println('V event sink example passed')
}
