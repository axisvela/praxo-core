import importlib.util
from pathlib import Path
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location("api_snapshot", Path(__file__).resolve().parents[1] / "api-snapshot.py")
API = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(API)


class RustApiTests(unittest.TestCase):
    def parse(self, body):
        parser = API.Rustdoc()
        parser.feed('<section id="main-content">' + body + '</section>')
        return parser

    def test_public_fields_and_methods(self):
        parser = self.parse('<pre class="rust item-decl">pub struct Item { pub value: String }</pre>'
                            '<h2 id="implementations"></h2><section id="method.new">'
                            '<h4 class="code-header">pub fn new() -&gt; Self</h4></section>')
        self.assertIn("pub value: String", parser.declaration[0])
        self.assertIn("new", parser.symbols)
        self.assertIn("method pub fn new() -> Self", parser.implementations)

    def test_alias_expansion_is_not_a_second_declaration(self):
        parser = self.parse('<pre class="item-decl">pub type Alias = String;</pre>'
                            '<h2 id="aliased-type"></h2><pre class="item-decl">pub struct Alias;</pre>')
        self.assertEqual(parser.declaration, ["pub type Alias = String;"])

    def test_auto_and_blanket_traits_are_excluded(self):
        parser = self.parse('<pre class="item-decl">pub struct Item;</pre>'
                            '<h2 id="trait-implementations"></h2><h3 class="code-header">impl Clone for Item</h3>'
                            '<h2 id="synthetic-implementations"></h2><h3 class="code-header">impl Send for Item</h3>'
                            '<h2 id="blanket-implementations"></h2><h3 class="code-header">impl Into&lt;Item&gt; for Item</h3>')
        self.assertEqual(parser.implementations, ["impl Clone for Item"])

    def test_ui_summaries_do_not_change_signatures(self):
        parser = self.parse('<pre class="item-decl">pub struct Item {<details><summary>Show 20 fields</summary>'
                            'pub name: String,</details>}</pre>')
        self.assertNotIn("Show", parser.declaration[0])
        self.assertIn("pub name", parser.declaration[0])

    def test_stale_unlinked_pages_are_not_public_api(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "index.html").write_text('<section id="main-content"><a href="struct.Live.html">Live</a></section>')
            (root / "struct.Live.html").write_text('<section id="main-content"><pre class="item-decl">pub struct Live;</pre></section>')
            (root / "struct.Removed.html").write_text('<section id="main-content"><pre class="item-decl">pub struct Removed;</pre></section>')
            declarations, symbols = API.collect_api(root, "praxo_core")
            self.assertIn("struct praxo_core::Live", declarations)
            self.assertNotIn("praxo_core::Removed", symbols)

    def test_missing_published_page_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "index.html").write_text('<section id="main-content"><a href="struct.Missing.html">Missing</a></section>')
            with self.assertRaises(ValueError):
                API.collect_api(root, "praxo_core")

    def test_incompatible_signature_changes_snapshot(self):
        old = API.snapshot({"struct praxo_core::Item": ["pub struct Item { pub value: u32 }"]}, "0.1.0", "0.2.0")
        new = API.snapshot({"struct praxo_core::Item": ["pub struct Item { pub value: String }"]}, "0.1.0", "0.2.0")
        self.assertNotEqual(old, new)

    def test_parity_checks_symbols_but_not_planned_entries(self):
        text = '- SPEC_VERSION: 0.2.0\n| `model.Model` | `model::Model` | parity | P1 |\n| `tool.Gateway` | `tool::Gateway` | planned | P2 |'
        self.assertEqual(API.parity_errors({"praxo_core::model::Model"}, text, "0.2.0"), [])
        self.assertTrue(API.parity_errors(set(), text, "0.2.0"))


if __name__ == "__main__":
    unittest.main()
