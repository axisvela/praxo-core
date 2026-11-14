import '../../lib/praxo_core.dart';

class FakeTransport implements McpTransport {
  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
    Duration timeout,
  ) async {
    switch (method) {
      case 'initialize':
        return {'protocolVersion': '2024-11-05', 'serverInfo': {'name': 'example-mcp'}};
      case 'tools/list':
        return {
          'tools': [
            {'name': 'echo'},
            {'name': 'add'},
          ],
        };
      case 'tools/call':
        return {
          'structuredContent': {'sum': 5},
        };
      default:
        throw StateError('unexpected method');
    }
  }

  @override
  void notify(String method, Map<String, dynamic> params) {}

  @override
  Future<void> close() async {}
}

Future<void> main() async {
  final client = McpClient(transport: FakeTransport());
  await client.start();
  final tools = await client.listTools();
  final result = await client.callTool('add', {});
  client.close();
  if (tools.map((tool) => tool['name']).join(',') != 'echo,add' ||
      result['sum'] != 5) {
    throw StateError('mcp example failed');
  }
  print('Dart MCP example passed');
}
