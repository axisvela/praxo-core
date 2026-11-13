export interface Document {
  id: string;
  content: string;
  metadata?: Record<string, string>;
  score?: number;
}

export interface Retriever {
  retrieve(query: string, limit: number): Promise<Document[]>;
}

export class FuncRetriever implements Retriever {
  constructor(
    private readonly retrieveFn: (
      query: string,
      limit: number
    ) => Promise<Document[]>
  ) {}

  retrieve(query: string, limit: number): Promise<Document[]> {
    return this.retrieveFn(query, limit);
  }
}
