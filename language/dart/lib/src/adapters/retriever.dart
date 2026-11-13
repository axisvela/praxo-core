import '../errors.dart';

class Document {
  final String id;
  final String content;
  final Map<String, String>? metadata;
  final double? score;

  const Document({
    required this.id,
    required this.content,
    this.metadata,
    this.score,
  });
}

typedef Retriever = Future<List<Document>> Function(String query, int limit);

class FuncRetriever {
  final Retriever retrieve;

  const FuncRetriever(this.retrieve);
}

Future<List<Document>> retrieveDocuments(Retriever retriever, String query, int limit) async {
  if (limit < 0) {
    throw const PraxoError('RETRIEVER_INVALID', 'retriever: invalid limit');
  }
  return retriever(query, limit);
}
