import Foundation

public struct Document {
    public var id: String
    public var content: String
    public var metadata: [String: String]?
    public var score: Double?

    public init(id: String,
                content: String,
                metadata: [String: String]? = nil,
                score: Double? = nil) {
        self.id = id
        self.content = content
        self.metadata = metadata
        self.score = score
    }
}

public typealias Retriever = (_ query: String, _ limit: Int) throws -> [Document]

public struct FuncRetriever {
    public var retrieve: Retriever

    public init(_ retrieve: @escaping Retriever) {
        self.retrieve = retrieve
    }
}

public func retrieveDocuments(_ retriever: Retriever,
                              query: String,
                              limit: Int) throws -> [Document] {
    if limit < 0 {
        throw PraxoError("RETRIEVER_INVALID", "retriever: invalid limit")
    }
    return try retriever(query, limit)
}
