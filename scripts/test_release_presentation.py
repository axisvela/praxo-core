from pathlib import Path
import re
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]


class ReleasePresentationTests(unittest.TestCase):
    def test_github_release_publishers_set_latest_explicitly(self):
        publishers = []
        for path in (ROOT / '.github/workflows').glob('*.yml'):
            text = path.read_text(encoding='utf-8')
            for line in text.splitlines():
                if 'gh release create ' not in line:
                    continue
                publishers.append(path.name)
                if path.name == 'release.yml':
                    self.assertIn('--latest', line)
                    self.assertNotIn('--latest=false', line)
                else:
                    self.assertIn('--latest=false', line, path.name)
        self.assertIn('release.yml', publishers)
        self.assertIn('language-source-release.yml', publishers)

    def test_language_source_release_requires_existing_scoped_tag(self):
        path = ROOT / '.github/workflows/language-source-release.yml'
        config = yaml.safe_load(path.read_text(encoding='utf-8'))
        job = config['jobs']['publish']
        self.assertEqual(job['if'], "github.ref == 'refs/heads/main'")
        validation, publication = job['steps']
        script = validation['run']
        pattern = re.search(r'\[\[ "\$SOURCE_TAG" =~ (.*?) \]\]', script).group(1)
        for tag in ('octave/v0.2.1', 'python/v0.3.0', 'csharp/v1.2.3'):
            self.assertIsNotNone(re.fullmatch(pattern, tag))
        for tag in ('v2.5.2', 'adapters/mcp/v0.1.0', 'python/v0.3.0-rc.1',
                    '--latest', 'python/v1.2.3;echo bad'):
            self.assertIsNone(re.fullmatch(pattern, tag))
        self.assertIn('"$SOURCE_TAG" != spec/*', script)
        self.assertIn('git/ref/tags/$SOURCE_TAG', script)
        self.assertIn('--verify-tag', publication['run'])
        self.assertIn('--latest=false', publication['run'])

    def test_matlab_packaging_does_not_claim_untested_release_range(self):
        source = (ROOT / 'language/matlab/package_toolbox.m').read_text(encoding='utf-8')
        self.assertLess(source.index('run_tests();'), source.index('ToolboxOptions('))
        self.assertIn("testedRelease = ['R' version('-release')];", source)
        self.assertIn('opts.MinimumMatlabRelease = testedRelease;', source)
        self.assertIn('opts.MaximumMatlabRelease = testedRelease;', source)
        self.assertIn('opts.SupportedPlatforms.(platforms{i}) = false;', source)
        self.assertNotIn("'R2020a'", source)
        self.assertNotIn('MatlabOnline = true', source)
        readme = (ROOT / 'language/matlab/README.md').read_text(encoding='utf-8')
        self.assertIn('MATLAB runtime compatibility is unverified', readme[:600])

    def test_public_guidance_separates_claims_and_evidence(self):
        readme = (ROOT / 'README.md').read_text(encoding='utf-8')
        for phrase in ('What Core Implements', 'What Tests Verify',
                       'What the Consumer Must Supply', 'without Policy',
                       'not OS isolation', 'exactly-once', 'Language Release Index'):
            self.assertIn(phrase, readme)
        for prefix in ('', 'zh-CN/'):
            page = (ROOT / 'docs' / prefix / 'languages/registry-pages.md').read_text(encoding='utf-8')
            self.assertIn('2026-11-06', page)
            self.assertIn('Maven', page)
            self.assertIn('MATLAB', page)
            release = (ROOT / 'docs' / prefix / 'project/releasing.md').read_text(encoding='utf-8')
            self.assertIn('--latest=false', release)


if __name__ == '__main__':
    unittest.main()
