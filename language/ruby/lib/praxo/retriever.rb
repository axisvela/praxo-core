module Praxo
  Document = Struct.new(:id, :content, :metadata, :score, keyword_init: true) do
    def to_wire
      out = { 'id' => id, 'content' => content }
      out['metadata'] = metadata if metadata && !metadata.empty?
      out['score'] = score if score && score != 0
      out
    end
  end

  class FuncRetriever
    def initialize(&block)
      raise ArgumentError, 'retriever: block is required' unless block

      @block = block
    end

    def retrieve(query, limit)
      @block.call(query.to_s, limit.to_i)
    end
  end
end
