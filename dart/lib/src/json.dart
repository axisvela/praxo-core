import 'dart:convert';

class Json {
  static dynamic parse(String text) => jsonDecode(text);

  static String stringify(dynamic value) => jsonEncode(value);

  static dynamic get(dynamic node, String key) {
    if (node is Map) return node[key];
    return null;
  }

  static bool has(dynamic node, String key) => node is Map && node.containsKey(key);

  static String? string(dynamic node, String key) {
    final value = get(node, key);
    return value is String ? value : null;
  }

  static bool boolean(dynamic node, String key, [bool fallback = false]) {
    final value = get(node, key);
    return value is bool ? value : fallback;
  }

  static int integer(dynamic node, String key, [int fallback = 0]) {
    final value = get(node, key);
    return value is num ? value.toInt() : fallback;
  }

  static List<dynamic> array(dynamic node, String key) {
    final value = get(node, key);
    return value is List ? value : const [];
  }

  static bool equals(dynamic left, dynamic right) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return left == right;
    if (left is num && right is num) return left == right;
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!equals(left[index], right[index])) return false;
      }
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key)) return false;
        if (!equals(left[key], right[key])) return false;
      }
      return true;
    }
    return left == right;
  }
}
