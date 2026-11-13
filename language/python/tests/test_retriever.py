from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.retriever import Document, FuncRetriever


class RetrieverTest(unittest.IsolatedAsyncioTestCase):
    async def test_func_retriever(self) -> None:
        async def retrieve(query: str, limit: int) -> list[Document]:
            return [
                Document(
                    id="doc-1",
                    content=f"{query}:{limit}",
                    metadata={"source": "test"},
                    score=0.5,
                )
            ]

        retriever = FuncRetriever(retrieve)
        documents = await retriever.retrieve("hello", 3)
        self.assertEqual(len(documents), 1)
        self.assertEqual(documents[0].id, "doc-1")
        self.assertEqual(documents[0].content, "hello:3")
        self.assertEqual(documents[0].metadata["source"], "test")
        self.assertEqual(
            documents[0].to_wire(),
            {
                "id": "doc-1",
                "content": "hello:3",
                "metadata": {"source": "test"},
                "score": 0.5,
            },
        )
