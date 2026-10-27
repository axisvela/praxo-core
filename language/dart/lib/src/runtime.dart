import 'dart:io';

import 'errors.dart';
import 'json.dart';
import 'models.dart';

abstract class EventSink {
  void emit(Event event);
}

class MultiSink implements EventSink {
  final List<EventSink> sinks;

  MultiSink(this.sinks);

  @override
  void emit(Event event) {
    for (final sink in sinks) {
      sink.emit(event);
    }
  }
}

class FilterSink implements EventSink {
  final EventSink sink;
  final bool Function(Event) predicate;

  FilterSink(this.sink, this.predicate);

  @override
  void emit(Event event) {
    if (predicate(event)) sink.emit(event);
  }
}

class MemoryStore {
  final Map<String, List<MemoryRecord>> _records = {};
  int _sequence = 0;

  MemoryRecord put(String sessionId, MemoryRecord record) {
    if (record.id.isEmpty) {
      record.id = 'mem-${DateTime.now().millisecondsSinceEpoch}-${_sequence++}';
    }
    record.createdAt ??= DateTime.now().toUtc().toIso8601String();
    _records.putIfAbsent(sessionId, () => []).add(record);
    return record;
  }

  List<MemoryRecord> search(String sessionId, String query, int limit) {
    final needle = query.trim().toLowerCase();
    final matches = (_records[sessionId] ?? [])
        .where((record) => needle.isEmpty || record.content.toLowerCase().contains(needle))
        .toList();
    matches.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    if (limit > 0 && matches.length > limit) return matches.take(limit).toList();
    return matches;
  }
}

class CheckpointAllowlist {
  final Set<String> _registered = {};

  void register(String type) {
    if (type.isEmpty) {
      throw const PraxoError('CHECKPOINT_ERROR', 'checkpoint: type is required');
    }
    _registered.add(type);
  }

  String marshal(String type, dynamic value) {
    if (!_registered.contains(type)) {
      throw PraxoError('CHECKPOINT_TYPE_NOT_ALLOWED',
          'checkpoint: payload type not allowed: $type');
    }
    return Json.stringify({'type': type, 'data': value});
  }

  dynamic unmarshal(String data) {
    final envelope = Json.parse(data);
    if (envelope is! Map) {
      throw const PraxoError('CHECKPOINT_ERROR',
          'checkpoint: envelope must be an object');
    }
    final type = envelope['type'] is String ? envelope['type'] as String : '';
    if (!_registered.contains(type)) {
      throw PraxoError('CHECKPOINT_TYPE_NOT_ALLOWED',
          'checkpoint: payload type not allowed: $type');
    }
    return envelope['data'];
  }
}

class PathChecker {
  final List<PathGrant> grants;

  PathChecker(this.grants);

  Decision check(String target, String need) {
    if (!const {'read', 'write', 'readwrite'}.contains(need)) {
      throw const PraxoError('POLICY_ERROR', 'policy: invalid access');
    }
    if (grants.isEmpty) {
      return const Decision(allowed: false, reason: 'no allowed roots');
    }
    final resolved = _normalize(target);
    String? matched;
    for (final grant in grants) {
      final root = _normalize(grant.root);
      if (!_within(root, resolved)) continue;
      matched = root;
      if (_allows(grant.access, need)) {
        return Decision(allowed: true, reason: 'path within $root');
      }
    }
    return Decision(
      allowed: false,
      reason: matched == null ? 'outside roots' : 'insufficient grant',
    );
  }

  bool allowed(String target, String need) {
    try {
      return check(target, need).allowed;
    } on PraxoError {
      return false;
    }
  }
}

String _normalize(String value) {
  var path = value.replaceAll('\\', '/');
  var prefix = '';
  final drive = RegExp(r'^[a-zA-Z]:/');
  if (drive.hasMatch(path)) {
    prefix = path.substring(0, 2);
    path = path.substring(2);
  } else if (path.startsWith('/')) {
    prefix = '/';
  }
  final parts = <String>[];
  for (final part in path.split('/')) {
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (part.isNotEmpty && part != '.') {
      parts.add(part);
    }
  }
  var result = '$prefix${parts.join('/')}';
  if (Platform.isWindows) result = result.toLowerCase();
  return result;
}

bool _within(String root, String target) {
  if (target == root) return true;
  return target.startsWith('$root/');
}

bool _allows(String grant, String need) {
  if (need == 'read') return grant == 'read' || grant == 'readwrite';
  if (need == 'write') return grant == 'write' || grant == 'readwrite';
  return grant == 'readwrite';
}

class ContextBudget {
  final int maxTokens;
  final int keepRecent;

  const ContextBudget({this.maxTokens = 0, this.keepRecent = 0});

  (List<Message>, bool) compact(List<Message> messages) {
    if (maxTokens <= 0 || estimateTokens(messages) <= maxTokens) {
      return (messages, true);
    }
    final system = <Message>[];
    final rest = <Message>[];
    for (final message in messages) {
      if (message.role == roleSystem) {
        if ((message.content ?? '').startsWith('[context compacted:')) continue;
        system.add(message);
      } else {
        rest.add(message);
      }
    }
    if (estimateTokens(system) > maxTokens) {
      if (system.isEmpty) return (<Message>[], false);
      final first = Message(
        role: system.first.role,
        content: truncateToTokens(system.first.content ?? '', maxTokens - 4),
        contentBlocks: system.first.contentBlocks,
        toolCalls: system.first.toolCalls,
        toolId: system.first.toolId,
      );
      system
        ..clear()
        ..add(first);
      if (estimateTokens(system) > maxTokens) return (<Message>[], false);
    }
    final keep = keepRecent > 0 ? keepRecent : 4;
    var start = rest.length - keep;
    if (start < 0) start = 0;
    while (start > 0 && rest[start].role == roleTool) {
      start--;
    }
    final marker = Message.text(roleSystem,
        '[context compacted: $start older messages omitted]');
    final kept = rest.sublist(start);
    List<Message> build() => [
          ...system,
          if (start > 0) marker,
          ...kept,
        ];
    var output = build();
    while (estimateTokens(output) > maxTokens && kept.length > 1) {
      if (kept[1].role == roleTool) break;
      kept.removeAt(0);
      output = build();
    }
    return (output, estimateTokens(output) <= maxTokens);
  }
}

int estimateTokens(List<Message> messages) {
  var total = 0;
  for (final message in messages) {
    total += 4 + (message.content ?? '').length ~/ 4;
    total += (message.toolId ?? '').length ~/ 4;
    for (final block in message.contentBlocks) {
      total += 4 + (block.text ?? '').length ~/ 4;
      total += (block.imageUrl ?? '').length ~/ 4;
      total += (block.data ?? '').length ~/ 4;
    }
    for (final call in message.toolCalls) {
      total += 4 + call.name.length ~/ 4;
      total += Json.stringify(call.arguments).length ~/ 4;
    }
  }
  return total;
}

String truncateToTokens(String value, int tokens) {
  if (tokens <= 0) return '';
  final limit = tokens * 4;
  if (value.length <= limit) return value;
  if (limit <= 16) return value.substring(0, limit);
  return '${value.substring(0, limit - 16)}\n[truncated]';
}
