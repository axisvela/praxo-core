import 'json.dart';

class ValidationError {
  final String path;
  final String message;

  const ValidationError(this.path, this.message);
}

List<ValidationError> validate(dynamic schema, dynamic data) {
  final errors = <ValidationError>[];
  _visit(schema, data, r'$', errors);
  return errors;
}

void _visit(dynamic schema, dynamic data, String path, List<ValidationError> errors) {
  if (schema is! Map) return;
  final type = schema['type'] is String ? schema['type'] as String : '';
  if (data == null) {
    if (type.isNotEmpty) errors.add(ValidationError(path, 'expected $type, got null'));
    return;
  }
  switch (type) {
    case 'object':
      _visitObject(schema, data, path, errors);
      break;
    case 'array':
      _visitArray(schema, data, path, errors);
      break;
    case 'string':
      _visitString(schema, data, path, errors);
      break;
    case 'number':
    case 'integer':
      _visitNumber(schema, type, data, path, errors);
      break;
    case 'boolean':
      _visitBoolean(schema, data, path, errors);
      break;
  }
}

void _visitObject(Map schema, dynamic data, String path, List<ValidationError> errors) {
  if (data is! Map) {
    errors.add(ValidationError(path, 'expected object'));
    return;
  }
  final required = schema['required'];
  if (required is List) {
    for (final name in required) {
      if (name is String && !data.containsKey(name)) {
        errors.add(ValidationError('$path.$name', 'required field missing'));
      }
    }
  }
  final properties = schema['properties'];
  if (properties is Map) {
    for (final entry in properties.entries) {
      if (data.containsKey(entry.key)) {
        _visit(entry.value, data[entry.key], '$path.${entry.key}', errors);
      }
    }
  }
}

void _visitArray(Map schema, dynamic data, String path, List<ValidationError> errors) {
  if (data is! List) {
    errors.add(ValidationError(path, 'expected array'));
    return;
  }
  final items = schema['items'];
  if (items is Map) {
    for (var index = 0; index < data.length; index++) {
      _visit(items, data[index], '$path[$index]', errors);
    }
  }
}

void _visitString(Map schema, dynamic data, String path, List<ValidationError> errors) {
  if (data is! String) {
    errors.add(ValidationError(path, 'expected string'));
    return;
  }
  final length = data.runes.length;
  final min = schema['minLength'] is num ? (schema['minLength'] as num).toInt() : 0;
  final max = schema['maxLength'] is num ? (schema['maxLength'] as num).toInt() : 0;
  if (min > 0 && length < min) {
    errors.add(ValidationError(path, 'min length $min, got $length'));
  }
  if (max > 0 && length > max) {
    errors.add(ValidationError(path, 'max length $max, got $length'));
  }
  final pattern = schema['pattern'];
  if (pattern is String) {
    try {
      if (!RegExp(pattern).hasMatch(data)) {
        errors.add(ValidationError(path, "pattern '$pattern' not matched"));
      }
    } on FormatException {
      errors.add(ValidationError(path, "invalid pattern '$pattern'"));
    }
  }
  _checkEnum(schema, data, path, errors);
}

void _visitNumber(Map schema, String type, dynamic data, String path,
    List<ValidationError> errors) {
  if (data is! num) {
    errors.add(ValidationError(path, 'expected number'));
    return;
  }
  if (type == 'integer' && data != data.truncate()) {
    errors.add(ValidationError(path, 'expected integer, got $data'));
    return;
  }
  _checkEnum(schema, data, path, errors);
  final minimum = schema['minimum'];
  if (minimum is num && minimum != 0 && data < minimum) {
    errors.add(ValidationError(path, 'value below minimum'));
  }
  final maximum = schema['maximum'];
  if (maximum is num && maximum != 0 && data > maximum) {
    errors.add(ValidationError(path, 'value above maximum'));
  }
}

void _visitBoolean(Map schema, dynamic data, String path, List<ValidationError> errors) {
  if (data is! bool) {
    errors.add(ValidationError(path, 'expected boolean'));
    return;
  }
  _checkEnum(schema, data, path, errors);
}

void _checkEnum(Map schema, dynamic data, String path, List<ValidationError> errors) {
  final values = schema['enum'];
  if (values is! List || values.isEmpty) return;
  for (final value in values) {
    if (Json.equals(value, data)) return;
  }
  errors.add(ValidationError(path, 'value not in enum'));
}
