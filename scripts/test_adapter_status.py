import unittest

import check_adapter_status as check


class AdapterStatusTests(unittest.TestCase):
    def test_repository_adapter_status_is_current(self):
        self.assertEqual(check.validate(), [])

    def test_mcp_marker_ignores_memcpy(self):
        pattern = check.MARKERS["mcp"]
        self.assertIsNone(pattern.search("memcpy(destination, source, size);"))

    def test_mcp_marker_matches_identifiers(self):
        pattern = check.MARKERS["mcp"]
        for text in (
            "praxo.mcp",
            "mcp_client",
            "PraxoMcpServerOptions",
            "PXRMcpClient",
            "MCPClient",
        ):
            with self.subTest(text=text):
                self.assertIsNotNone(pattern.search(text))

    def test_reference_baselines_link_to_adapter_status(self):
        mcp = (check.ROOT / "docs/reference/mcp-client.md").read_text(encoding="utf-8")
        harmovela = (check.ROOT / "docs/reference/harmovela-sink.md").read_text(encoding="utf-8")
        self.assertIn("languages/adapter-status.md#mcp", mcp)
        self.assertIn("languages/adapter-status.md#harmovela", harmovela)


if __name__ == "__main__":
    unittest.main()
