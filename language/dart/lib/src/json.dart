import 'dart:convert';

/// The Json API.
class Json {
  /// Handles parse().
  static dynamic parse(String text) => jsonDecode(text);

  /// Handles stringify().
  static String stringify(dynamic value) => jsonEncode(value);

  /// Handles get().
  static dynamic get(dynamic node, String key) {
    if (node is Map) return node[key];
    return null;
  }

  /// Handles has().
  static bool has(dynamic node, String key) => node is Map && node.containsKey(key);

  /// Handles string().
  static String? string(dynamic node, String key) {
    final value = get(node, key);
    return value is String ? value : null;
  }

  /// Handles boolean().
  static bool boolean(dynamic node, String key, [bool fallback = false]) {
    final value = get(node, key);
    return value is bool ? value : fallback;
  }

  /// Handles integer().
  static int integer(dynamic node, String key, [int fallback = 0]) {
    final value = get(node, key);
    return value is num ? value.toInt() : fallback;
  }

  /// Handles array().
  static List<dynamic> array(dynamic node, String key) {
    final value = get(node, key);
    return value is List ? value : const [];
  }

  /// Handles equals().
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
