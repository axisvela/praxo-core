import 'errors.dart';
import 'json.dart';

class PluginManifest {
  final int schemaVersion;
  final String id;
  final String version;
  final String kind;
  final Map<String, dynamic> entrypoint;
  final String protocol;
  final List<String> capabilities;
  final Map<String, dynamic> permissions;
  final Map<String, dynamic> limits;
  final String isolation;
  final Map<String, dynamic> health;

  const PluginManifest({
    required this.schemaVersion,
    required this.id,
    required this.version,
    required this.kind,
    required this.entrypoint,
    required this.protocol,
    required this.capabilities,
    required this.permissions,
    required this.limits,
    required this.isolation,
    required this.health,
  });
}

const _kinds = {
  'tool.provider.v1',
  'model.provider.v1',
  'policy.provider.v1',
  'memory.provider.v1',
  'sandbox.provider.v1',
};
const _topKeys = {
  'schemaVersion', 'id', 'version', 'kind', 'entrypoint', 'protocol',
  'capabilities', 'permissions', 'limits', 'isolation', 'health',
  'signature', 'sbom',
};
const _entrypointKeys = {'type', 'command', 'module', 'image', 'args', 'dir'};
const _permissionKeys = {'filesystem', 'network', 'env'};
const _limitKeys = {'memoryMB', 'cpuMillis', 'timeoutMs', 'maxInflight'};
const _healthKeys = {'method', 'intervalMs'};
const _signatureKeys = {'algorithm', 'keyId'};

PluginManifest parseManifest(String raw) {
  if (raw.trim().isEmpty) {
    throw const PraxoError('PLUGIN_INVALID', 'plugin: manifest is empty');
  }
  dynamic root;
  try {
    root = Json.parse(raw);
  } catch (error) {
    throw PraxoError('PLUGIN_INVALID', 'plugin: manifest: $error');
  }
  if (root is! Map<String, dynamic>) {
    throw const PraxoError('PLUGIN_INVALID', 'plugin: manifest must be an object');
  }
  _checkKeys(root, _topKeys, 'manifest');
  final schemaVersion = _asInt(root['schemaVersion'], 'schemaVersion');
  if (schemaVersion != 1) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: schemaVersion = $schemaVersion, want 1');
  }
  final id = _asString(root['id'], 'id');
  if (!RegExp(r'^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$')
      .hasMatch(id)) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: id $id is not reverse-DNS');
  }
  final version = _asString(root['version'], 'version');
  if (!RegExp(
          r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$')
      .hasMatch(version)) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: version $version is not semver');
  }
  final kind = _asString(root['kind'], 'kind');
  if (!_kinds.contains(kind)) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: kind $kind is not a known contract');
  }
  final protocol = _asString(root['protocol'], 'protocol');
  if (protocol != 'jsonrpc-2') {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: protocol = $protocol, want jsonrpc-2');
  }
  final entrypoint = _asObject(root['entrypoint'], 'entrypoint');
  _checkKeys(entrypoint, _entrypointKeys, 'entrypoint');
  final entryType = _asString(entrypoint['type'], 'entrypoint.type');
  final required = switch (entryType) {
    'process' => 'command',
    'wasm' => 'module',
    'container' => 'image',
    _ => throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: unknown entrypoint type $entryType'),
  };
  if (!_textPresent(entrypoint[required])) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: $entryType entrypoint requires $required');
  }
  final isolation = _asString(root['isolation'], 'isolation');
  if (isolation != entryType) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: isolation $isolation does not match entrypoint $entryType');
  }
  final permissions = _asObject(root['permissions'], 'permissions');
  _checkKeys(permissions, _permissionKeys, 'permissions');
  final limits = _asObject(root['limits'], 'limits');
  _checkKeys(limits, _limitKeys, 'limits');
  limits.forEach((key, value) {
    if (_asInt(value, 'limits.$key') < 0) {
      throw const PraxoError('PLUGIN_INVALID',
          'plugin: manifest: limits must not be negative');
    }
  });
  final health = _asObject(root['health'], 'health');
  _checkKeys(health, _healthKeys, 'health');
  if (root.containsKey('signature')) {
    final signature = _asObject(root['signature'], 'signature');
    _checkKeys(signature, _signatureKeys, 'signature');
    if (!_textPresent(signature['algorithm']) || !_textPresent(signature['keyId'])) {
      throw const PraxoError('PLUGIN_INVALID',
          'plugin: manifest: signature requires algorithm and keyId');
    }
  }
  final capabilities = <String>[];
  if (root.containsKey('capabilities')) {
    final rawCapabilities = root['capabilities'];
    if (rawCapabilities is! List) {
      throw const PraxoError('PLUGIN_INVALID',
          'plugin: manifest: capabilities must be an array');
    }
    for (final item in rawCapabilities) {
      final capability = _asString(item, 'capabilities');
      if (capability.isEmpty) {
        throw const PraxoError('PLUGIN_INVALID',
            'plugin: manifest: capability must not be empty');
      }
      if (capabilities.contains(capability)) {
        throw const PraxoError('PLUGIN_INVALID',
            'plugin: manifest: duplicate capability');
      }
      capabilities.add(capability);
    }
  }
  return PluginManifest(
    schemaVersion: schemaVersion,
    id: id,
    version: version,
    kind: kind,
    entrypoint: entrypoint,
    protocol: protocol,
    capabilities: capabilities,
    permissions: permissions,
    limits: limits,
    isolation: isolation,
    health: health,
  );
}

void _checkKeys(Map<String, dynamic> value, Set<String> allowed, String where) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw PraxoError('PLUGIN_INVALID',
          'plugin: manifest: unknown field $key in $where');
    }
  }
}

Map<String, dynamic> _asObject(dynamic value, String where) {
  if (value == null) return <String, dynamic>{};
  if (value is! Map<String, dynamic>) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: $where must be an object');
  }
  return value;
}

String _asString(dynamic value, String where) {
  if (value is! String) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: $where must be a string');
  }
  return value;
}

int _asInt(dynamic value, String where) {
  if (value is! num || value != value.truncate()) {
    throw PraxoError('PLUGIN_INVALID',
        'plugin: manifest: $where must be an integer');
  }
  return value.toInt();
}

bool _textPresent(dynamic value) => value is String && value.isNotEmpty;
