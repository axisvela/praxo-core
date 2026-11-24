import unittest
from collections import Counter

import tutorial_catalog as catalog


class TutorialCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.entries = catalog.records()

    def test_ids_and_source_paths(self):
        self.assertEqual(len({entry['id'] for entry in self.entries}), len(self.entries))
        source_keys = []
        for entry in self.entries:
            with self.subTest(entry=entry['id']):
                self.assertIn(entry['industry'], catalog.INDUSTRIES)
                path = catalog.ROOT / entry['path']
                self.assertTrue(path.exists())
                if entry['kind'] not in {'candidate', 'legacy-theme', 'guide'}:
                    self.assertTrue((path / 'README.md').is_file())
                    self.assertTrue(catalog.coverage.implementation_files(path))
                    source_keys.append((entry['languages'], entry['path']))
        self.assertEqual(len(set(source_keys)), len(source_keys))

    def test_every_application_directory_is_indexed(self):
        readmes = list((catalog.ROOT / 'language').glob('*/Tutorial/*/README.md'))
        actual = {entry['path'] for entry in self.entries if entry['kind'] == 'application'}
        expected = {path.parent.relative_to(catalog.ROOT).as_posix() for path in readmes}
        self.assertEqual(actual, expected)

    def test_candidates_legacy_themes_and_relations(self):
        ids = {entry['id'] for entry in self.entries if entry['kind'] == 'candidate'}
        self.assertEqual(len(ids), 100)
        text = (catalog.ROOT / 'docs/getting-started/tutorial-plan.md').read_text(encoding='utf-8')
        section = text.split('## Extended Scenario Catalog', 1)[1].split('### Scenario Selection Rules', 1)[0]
        themes = {line.split('|')[1].strip() for line in section.splitlines()
                  if line.startswith('| ') and not line.startswith(('| Scenario ', '| ---'))}
        self.assertEqual(themes, set(catalog.LEGACY_NAMES))
        for entry in self.entries:
            if entry['kind'] == 'application':
                related = set(filter(None, entry['related'].split(',')))
                self.assertTrue(related <= ids)
                self.assertTrue(entry['capabilities'])

    def test_partial_slices_do_not_imply_full_completion(self):
        goals = {entry['id']: entry for entry in self.entries if entry['kind'] == 'candidate'}
        for entry in goals.values():
            self.assertEqual(entry['status'], 'candidate')
            self.assertEqual(entry['full_implementation'], 'not-implemented')
            for path in entry['related_slices']:
                self.assertTrue((catalog.ROOT / path / 'README.md').is_file())
        for key in ('CY-02', 'CY-03', 'CY-06', 'CT-02', 'TL-04', 'TL-05', 'TL-07',
                    'MD-02', 'MD-03', 'LJ-01', 'LJ-04', 'AE-03', 'OG-06', 'OG-07'):
            self.assertTrue(goals[key]['related_slices'], key)
        self.assertFalse(goals['TL-02']['related_slices'])
        self.assertFalse(goals['TL-03']['related_slices'])

    def test_mechanism_matrix_matches_existing_inventory(self):
        mechanisms = [entry for entry in self.entries if entry['kind'] == 'mechanism']
        self.assertEqual({entry['languages'] for entry in mechanisms}, set(catalog.coverage.languages()))
        self.assertEqual(len(mechanisms), len(catalog.coverage.languages()) * len(catalog.coverage.ALIGNED_THEMES))

    def test_bilingual_generated_pages_are_current(self):
        counts = Counter(entry['kind'] for entry in self.entries)
        for zh, prefix in ((False, ''), (True, 'zh-CN/')):
            path = catalog.ROOT / f'docs/{prefix}getting-started/tutorial-catalog.md'
            text = path.read_text(encoding='utf-8')
            self.assertEqual(text, catalog.render(self.entries, zh))
            self.assertLess(len(text.splitlines()), 700)
            self.assertIn(str(sum(counts.values())), text)
            self.assertIn('tutorial-plan.md', text)
            self.assertIn('agent-scenarios.md', text)

    def test_navigation_and_existing_entry_points(self):
        nav = (catalog.ROOT / 'mkdocs.yml').read_text(encoding='utf-8')
        self.assertIn('Tutorial Catalog: getting-started/tutorial-catalog.md', nav)
        for prefix in ('', 'zh-CN/'):
            for page in ('tutorial-plan', 'agent-scenarios', 'examples'):
                text = (catalog.ROOT / f'docs/{prefix}getting-started/{page}.md').read_text(encoding='utf-8')
                self.assertIn('(tutorial-catalog.md)', text)


if __name__ == '__main__':
    unittest.main()
