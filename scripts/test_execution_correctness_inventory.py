import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ExecutionCorrectnessInventoryTests(unittest.TestCase):
    def setUp(self):
        self.inventory = json.loads(
            (ROOT / 'scripts/execution_correctness_inventory.json').read_text(encoding='utf-8'))

    def test_inventory_is_complete_but_not_a_pass_report(self):
        self.assertEqual(self.inventory['status'], 'audited inventory; not an execution report')
        self.assertRegex(self.inventory['designCommit'], r'^[0-9a-f]{40}$')
        self.assertEqual(self.inventory['tracks'], ['EC-D', 'EC-I', 'EC-O'])
        self.assertEqual([case['id'] for case in self.inventory['scenarios']],
                         [f'EC-{i:02d}' for i in range(1, 15)])
        for prefix in ('', 'zh-CN/'):
            page = (ROOT / 'docs' / prefix / 'project/execution-correctness.md').read_text(encoding='utf-8')
            self.assertEqual(re.findall(r'^\| (EC-\d{2}) \|', page, re.MULTILINE),
                             [case['id'] for case in self.inventory['scenarios']])
        allowed = {'partial-core-evidence', 'core-gap-and-external',
                   'external-authority', 'blocked-consumer'}
        for case in self.inventory['scenarios']:
            self.assertEqual(case['acceptance'], 'not-run', case['id'])
            self.assertIn(case['disposition'], allowed)
            self.assertTrue(case['gap'], case['id'])
            if case['disposition'] != 'partial-core-evidence':
                self.assertEqual(case['localTests'], [], case['id'])

    def test_local_mappings_resolve_to_existing_core_test_functions(self):
        seen = set()
        for case in self.inventory['scenarios']:
            for test in case['localTests']:
                with self.subTest(case=case['id'], test=test['test']):
                    file = Path(test['file'])
                    self.assertFalse(file.is_absolute())
                    self.assertNotIn('..', file.parts)
                    self.assertTrue(test['file'].startswith('pkg/'))
                    self.assertTrue(test['file'].endswith('_test.go'))
                    self.assertEqual(test['package'], './' + file.parent.as_posix())
                    source = (ROOT / file).read_text(encoding='utf-8')
                    self.assertRegex(source, r'(?m)^func ' + re.escape(test['test']) + r'\(t \*testing\.T\)')
                    self.assertTrue(test['assertion'])
                    subtests = test.get('requiredSubtests', [])
                    self.assertIsInstance(subtests, list)
                    for subtest in subtests:
                        self.assertIsInstance(subtest, str)
                        self.assertTrue(subtest)
                        self.assertFalse(subtest.startswith('/') or subtest.endswith('/'))
                    identity = (test['package'], test['test'])
                    self.assertNotIn(identity, seen)
                    seen.add(identity)

    def test_initial_scope_requires_only_named_partial_mechanics(self):
        scope = self.inventory['initialScope']
        self.assertEqual(scope['name'], 'core-mechanics-baseline')
        self.assertEqual(scope['track'], 'EC-D')
        self.assertEqual(scope['scenarioIds'],
                         ['EC-01', 'EC-03', 'EC-04', 'EC-06', 'EC-08', 'EC-10', 'EC-14'])
        self.assertIn('not full EC scenario or profile acceptance', scope['claim'])
        cases = {case['id']: case for case in self.inventory['scenarios']}
        for identifier in scope['scenarioIds']:
            self.assertTrue(cases[identifier]['localTests'])
            self.assertEqual(cases[identifier]['disposition'], 'partial-core-evidence')


if __name__ == '__main__':
    unittest.main()
