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
                self.assertIn('2026-11-08', overview)
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

    def test_embodied_pilot_plan_is_planned_and_bilingual(self):
        with self.subTest(language=""):
            text = (DOCS / 'project/embodied-pilot.md').read_text(encoding='utf-8')
            self.assertEqual(re.findall(r'^\| (E[1-8]) \|', text, re.MULTILINE),
                             [f'E{i}' for i in range(1, 9)])
            self.assertIn('proposed pilot plan', text)
            self.assertIn('embodied-integration.md', text)
            self.assertIn('governed-execution.md', text)
            self.assertIn('not a schedule', text)
            self.assertIn('Simulation is not hardware evidence', text)
        with self.subTest(language='zh-CN/'):
            text = (DOCS / 'zh-CN/project/embodied-pilot.md').read_text(encoding='utf-8')
            self.assertEqual(re.findall(r'^\| (E[1-8]) \|', text, re.MULTILINE),
                             [f'E{i}' for i in range(1, 9)])
            self.assertIn('试点计划提案', text)
            self.assertIn('embodied-integration.md', text)
            self.assertIn('governed-execution.md', text)
        roadmap = (DOCS / 'project/roadmap.md').read_text(encoding='utf-8')
        self.assertIn('embodied-pilot.md', roadmap)
        self.assertIn('embodied-pilot.md', (DOCS / 'zh-CN/project/roadmap.md').read_text(encoding='utf-8'))
        status = (DOCS / 'project/contract-status.md').read_text(encoding='utf-8')
        self.assertIn('Embodied pilot plan', status)
        config = yaml.safe_load((ROOT / 'mkdocs.yml').read_text(encoding='utf-8'))
        self.assertIn('project/embodied-pilot.md', str(config['nav']))

    def test_design_pages_are_navigable_with_translations(self):
        config = yaml.safe_load((ROOT / 'mkdocs.yml').read_text(encoding='utf-8'))
        navigation = str(config['nav'])
        for page in ('reference/execution-profiles.md', 'reference/governed-execution.md',
                     'reference/embodied-integration.md', 'project/execution-correctness.md'):
            self.assertIn(page, navigation)
            self.assertTrue((DOCS / 'zh-CN' / page).is_file())

    def test_governed_assembly_and_requirement_inventory(self):
        configurations = []
        for prefix in ('', 'zh-CN/'):
            with self.subTest(language=prefix):
                text = (DOCS / prefix / 'reference/governed-execution.md').read_text(encoding='utf-8')
                self.assertEqual(re.findall(r'^\| (G[1-8]) \|', text, re.MULTILINE),
                                 [f'G{i}' for i in range(1, 9)])
                sample, = re.findall(r'```yaml\n(.*?)\n```', text, re.DOTALL)
                config = yaml.safe_load(sample)
                self.assertEqual(config['execution']['level'], 'governed')
                self.assertEqual(config['scope']['mode'], 'allowlist')
                self.assertEqual(config['effects']['retry'], 'guarded')
                configurations.append(config)
                self.assertIn('2026-11-08', text)
                for path in ('reference/execution-profiles.md', 'project/roadmap.md',
                             'project/contract-status.md', 'project/embodied-pilot.md'):
                    page = (DOCS / prefix / path).read_text(encoding='utf-8')
                    self.assertIn('G1-G8', page, path)
        self.assertEqual(*configurations)

    def test_pilot_review_requirements_are_documented(self):
        expectations = {
            '': ('consumer-local', 'G1-G8 checklist', 'deny-all implementation cannot pass',
                 'stop confirmed', 'authoritative no-effect', 'append-only',
                 'wrong-robot', 'single-use approval', 'bounded wait',
                 'documentation structure tests are not behavioral evidence'),
            'zh-CN/': ('消费者局部', 'G1-G8 清单', '拒绝所有动作的实现不能通过',
                       '停止已确认', '权威无效果', '只追加', '错误机器人',
                       '单次审批', '有界等待', '文档结构测试不是行为证据'),
        }
        for prefix, terms in expectations.items():
            with self.subTest(language=prefix):
                text = (DOCS / prefix / 'project/embodied-pilot.md').read_text(encoding='utf-8')
                for term in terms:
                    self.assertIn(term, text)
                headings = re.findall(r'^## .+', text, re.MULTILINE)
                self.assertEqual(len(headings), len(set(headings)))
        english = (DOCS / 'project/embodied-pilot.md').read_text(encoding='utf-8')
        self.assertNotIn('confirmation, rejection, or timeout is recorded as unknown/pending', english)

    def test_embodied_product_roles_and_public_contract_boundaries(self):
        for prefix in ('', 'zh-CN/'):
            with self.subTest(language=prefix):
                ecosystem = (DOCS / prefix / 'integrations/ecosystem.md').read_text(encoding='utf-8')
                for term in ('PEIRAVELA', 'KINETOVELA', 'ONTOVELA', 'TEKMOVELA',
                             'SimulationEvidence', 'peiravela-open/sdk/go', 'Apache-2.0'):
                    self.assertIn(term, ecosystem)
                profile = (DOCS / prefix / 'reference/embodied-integration.md').read_text(encoding='utf-8')
                for term in ('integrations/ecosystem.md', 'SafetyEnvelope', 'AGPL', 'epoch'):
                    self.assertIn(term, profile)
        english = (DOCS / 'project/embodied-pilot.md').read_text(encoding='utf-8')
        for term in ('experiment-attempt/Run/Mission', 'observer health',
                     'cleanup evidence', 'independent', 'published and reviewed',
                     'cross-attempt/tenant/epoch', 'declared absence'):
            self.assertIn(term, english)
        chinese = (DOCS / 'zh-CN/project/embodied-pilot.md').read_text(encoding='utf-8')
        for term in ('experiment-attempt/Run/Mission', '观测者健康', '清理证据',
                     '独立保障', '发布并审查', '跨 attempt/租户/epoch', '显式缺失'):
            self.assertIn(term, chinese)

    def test_edge_learning_targets_remain_optional_and_unimplemented(self):
        for prefix in ('', 'zh-CN/'):
            for relative in ('integrations/ecosystem.md', 'project/roadmap.md',
                             'project/contract-status.md', 'reference/embodied-integration.md',
                             'project/embodied-pilot.md'):
                with self.subTest(language=prefix, page=relative):
                    text = (DOCS / prefix / relative).read_text(encoding='utf-8')
                    self.assertIn('AKROVELA', text)
                    self.assertIn('DIDACTOVELA', text)
                    self.assertIn('0.1.0', text)
        english = (DOCS / 'reference/embodied-integration.md').read_text(encoding='utf-8')
        self.assertIn('not usable embodied integrations', english)
        pilot = (DOCS / 'project/embodied-pilot.md').read_text(encoding='utf-8')
        self.assertIn('not prerequisites for every pilot', pilot)


if __name__ == '__main__':
    unittest.main()
