from pathlib import Path
import re
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs'


class ExecutionDesignDocumentationTests(unittest.TestCase):
    def test_profile_levels_are_bilingual_and_do_not_claim_implementation(self):
        for prefix in ('', 'zh-CN/'):
            with self.subTest(language=prefix):
                overview = (DOCS / prefix / 'reference/execution-profiles.md').read_text(encoding='utf-8')
                for name in ('Standard Embedding', 'Governed Execution Profile',
                             'Embodied Integration Profile', 'agent.Profile',
                             'model.ProviderProfile', 'AllowedTools'):
                    self.assertIn(name, overview)
                self.assertIn('governed-execution.md', overview)
                self.assertIn('embodied-integration.md', overview)
                self.assertIn('execution-correctness.md', overview)
                self.assertIn('2026-11-06', overview)
                status = (DOCS / prefix / 'project/contract-status.md').read_text(encoding='utf-8')
                for name in ('Standard Embedding', 'Governed Execution Profile',
                             'Embodied Integration Profile', 'Execution Correctness Suite'):
                    self.assertIn('| ' + name + ' |', status)

    def test_governed_boundary_covers_preconditions_and_all_effect_steps(self):
        expected = ['01 Intent', '02 Resolve Context', '03 Authorize', '04 Prepare',
                    '05 Invoke', '06 Confirm Effect', '07 Persist Evidence', '08 Reconcile']
        for prefix in ('', 'zh-CN/'):
            text = (DOCS / prefix / 'reference/governed-execution.md').read_text(encoding='utf-8')
            steps = re.findall(r'^\| (0[1-8] [^|]+?) \|', text, re.MULTILINE)
            self.assertEqual(steps, expected)
            for term in ('Policy == nil', 'AllowedTools', 'All', 'None',
                         'Middleware', 'Effect PEP', 'AEGIVELA'):
                self.assertIn(term, text)
        english = (DOCS / 'reference/governed-execution.md').read_text(encoding='utf-8')
        self.assertIn('not an implemented', english)
        self.assertIn('tool discovery/exposure', english)
        self.assertIn('not only', english)
        self.assertIn('post-commit evidence failure', english)

    def test_embodied_requirements_are_proposed_not_hardware_evidence(self):
        for prefix in ('', 'zh-CN/'):
            text = (DOCS / prefix / 'reference/embodied-integration.md').read_text(encoding='utf-8')
            self.assertEqual(re.findall(r'^\| (E[1-8]) \|', text, re.MULTILINE),
                             [f'E{i}' for i in range(1, 9)])
            for name in ('Core', 'Run', 'Task', 'Process', 'Mission', 'governed-execution.md'):
                self.assertIn(name, text)
        english = (DOCS / 'reference/embodied-integration.md').read_text(encoding='utf-8')
        self.assertIn('consumer pilot not started', english)
        self.assertIn('Simulation is not hardware or production evidence', english)

    def test_ec_inventory_preserves_taxonomy_and_planned_status(self):
        for prefix in ('', 'zh-CN/'):
            text = (DOCS / prefix / 'project/execution-correctness.md').read_text(encoding='utf-8')
            ids = re.findall(r'^\| (EC-\d{2}) \|', text, re.MULTILINE)
            self.assertEqual(ids, [f'EC-{i:02d}' for i in range(1, 15)])
            for term in ('EC-D', 'EC-I', 'EC-O', 'L1-L6', 'not-run',
                         'ShouldRetry', 'event.Sink.Emit', 'test-evidence.md'):
                self.assertIn(term, text)
            roadmap = (DOCS / prefix / 'project/roadmap.md').read_text(encoding='utf-8')
            self.assertIn('execution-correctness.md', roadmap)
            self.assertIn('execution-profiles.md', roadmap)
        english = (DOCS / 'project/execution-correctness.md').read_text(encoding='utf-8')
        self.assertIn('EC-D Scope Runner', english)
        self.assertIn('execution_correctness.py', english)
        self.assertIn('scope-passed', english)
        self.assertIn('full EC inventory', english)
        self.assertIn('not a claim that a non-idempotency guard has been implemented', english)

    def test_design_pages_are_navigable_with_translations(self):
        config = yaml.safe_load((ROOT / 'mkdocs.yml').read_text(encoding='utf-8'))
        navigation = str(config['nav'])
        for page in ('reference/execution-profiles.md', 'reference/governed-execution.md',
                     'reference/embodied-integration.md', 'project/execution-correctness.md'):
            self.assertIn(page, navigation)
            self.assertTrue((DOCS / 'zh-CN' / page).is_file())


if __name__ == '__main__':
    unittest.main()
