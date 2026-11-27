import '../errors.dart';

/// The Document API.
class Document {
  /// The id value.
  final String id;
  /// The content value.
  final String content;
  /// The String value.
  final Map<String, String>? metadata;
  /// The score value.
  final double? score;

  /// Creates a Document instance.
  const Document({
    required this.id,
    required this.content,
    this.metadata,
    this.score,
  });
}

/// Signature for Retriever.
typedef Retriever = Future<List<Document>> Function(String query, int limit);

/// The FuncRetriever API.
class FuncRetriever {
  /// The retrieve value.
  final Retriever retrieve;

  /// Creates a FuncRetriever instance.
  const FuncRetriever(this.retrieve);
}

/// Handles retrieveDocuments().
Future<List<Document>> retrieveDocuments(Retriever retriever, String query, int limit) async {
  if (limit < 0) {
    throw const PraxoError('RETRIEVER_INVALID', 'retriever: invalid limit');
  }
  return retriever(query, limit);
}
