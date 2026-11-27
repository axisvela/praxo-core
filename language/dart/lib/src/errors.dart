/// An error raised by the Core.
class PraxoError implements Exception {
  /// The code value.
  final String code;
  /// The message value.
  final String message;

  /// Creates a PraxoError instance.
  const PraxoError(this.code, this.message);

  @override
  String toString() => message;
}
