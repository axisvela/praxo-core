import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE = 'github.com/axisvela/praxo-core/v2'


class GoUpgradeTests(unittest.TestCase):
    def test_same_consumer_upgrades_without_source_changes(self):
        go = shutil.which('go')
        self.assertIsNotNone(go, 'Go is required for upgrade acceptance')
        historical = (ROOT / 'tests/consumer/go.mod').read_text(encoding='utf-8')
        baseline = re.search(r'^\s*' + re.escape(MODULE) + r' (v\d+\.\d+\.\d+)\s*$',
                             historical, re.MULTILINE).group(1)
        packages = json.loads((ROOT / 'docs/getting-started/agent-integration.json').read_text(encoding='utf-8'))
        current = 'v' + next(item['version'] for item in packages['languages'] if item['language'] == 'Go')
        self.assertNotEqual(baseline, current, 'Upgrade evidence needs two distinct published versions')
        env = dict(os.environ, GOWORK='off')
        with tempfile.TemporaryDirectory(prefix='praxo-upgrade-') as directory:
            application = Path(directory)
            files = ('main.go', 'main_test.go', 'governed_test.go')
            source = {name: (ROOT / 'language/go/examples/consumer-go' / name).read_bytes() for name in files}
            for name in files:
                shutil.copy2(ROOT / 'language/go/examples/consumer-go' / name, application / name)

            def run(*args):
                result = subprocess.run([go, *args], cwd=application, env=env,
                                        capture_output=True, text=True, timeout=180)
                self.assertEqual(result.returncode, 0,
                                 f'go {" ".join(args)}\n{result.stdout}{result.stderr}')
                return result.stdout

            def check_dependency(expected):
                manifest = json.loads(run('mod', 'edit', '-json'))
                self.assertFalse(manifest.get('Replace'), 'Consumer must not replace modules')
                dependency = json.loads(run('list', '-mod=readonly', '-m', '-json', MODULE))
                self.assertEqual(dependency['Version'], expected)
                self.assertNotIn('Replace', dependency)
                graph = run('list', '-mod=readonly', '-m', '-json', 'all')
                decoder = json.JSONDecoder()
                while graph.strip():
                    item, end = decoder.raw_decode(graph.lstrip())
                    self.assertNotIn('Replace', item, item['Path'])
                    graph = graph.lstrip()[end:]

            run('mod', 'init', 'example.com/praxo-upgrade')
            run('get', MODULE + '@' + baseline)
            run('mod', 'tidy')
            check_dependency(baseline)
            baseline_tests = run('test', '-mod=readonly', '-count=1', '-v', '-run',
                                 '^Test(AllowedTool|DeniedToolHasNoEffect|StarterOutput)$', './...')
            for name in ('TestAllowedTool', 'TestDeniedToolHasNoEffect', 'TestStarterOutput'):
                self.assertIn('--- PASS: ' + name, baseline_tests)

            run('get', MODULE + '@' + current)
            run('mod', 'tidy')
            check_dependency(current)
            upgraded_tests = run('test', '-mod=readonly', '-count=1', '-v', './...')
            for name in ('TestPublishedDependency', 'TestGovernedRejectsMissingPolicy',
                         'TestGovernedRejectsEmptyToolScope', 'TestGovernedReauthorizesFinalArguments',
                         'TestGovernedReauthorizesApprovalEdit', 'TestGovernedFailsClosedOnPolicyError'):
                self.assertIn('--- PASS: ' + name, upgraded_tests)
            run('vet', '-mod=readonly', './...')
            run('build', '-mod=readonly', './...')
            self.assertEqual(run('run', '-mod=readonly', '.'),
                             'allow: recorded; effects=1\ndeny: policy rejected; effects=0\n')
            for name, original in source.items():
                self.assertEqual((application / name).read_bytes(), original, name)
            print(f'Published upgrade {baseline} -> {current}: unchanged consumer, '
                  'no replacements, governed negative checks passed')


if __name__ == '__main__':
    unittest.main()
