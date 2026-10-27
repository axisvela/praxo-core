class PraxoError implements Exception {
  final String code;
  final String message;

  const PraxoError(this.code, this.message);

  @override
  String toString() => message;
}
