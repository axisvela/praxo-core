import 'package:praxo_core/praxo_core.dart';

void main() {
  final agent = Agent(AgentOptions(StaticModel('hello from praxo_core')));
  final result = agent.run(
    const Session(id: 'example'),
    'Say hello.',
  );
  print(result.output);
}
