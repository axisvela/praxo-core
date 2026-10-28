import contextlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
MODULE = importlib.util.spec_from_file_location("c_api_snapshot", ROOT / "api-snapshot.py")
API = importlib.util.module_from_spec(MODULE)
MODULE.loader.exec_module(API)
COMPILER = API.compiler_path(os.environ.get("PRAXO_API_TEST_COMPILER"))


class ApiSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        shutil.copytree(ROOT / "include", self.root / "include")
        self.spec = self.root / "SPEC_VERSION"
        self.spec.write_text("0.2.0\n", encoding="utf-8")

    def snapshot(self):
        return API.snapshot(self.root, self.spec, COMPILER)

    def change(self, header, before, after):
        path = self.root / "include" / header
        source = path.read_text(encoding="utf-8")
        self.assertIn(before, source)
        path.write_text(source.replace(before, after, 1), encoding="utf-8")

    def run_main(self, *args):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return API.main(["--compiler", COMPILER, *args], self.root, self.spec)

    def test_current_baseline_matches_headers(self):
        version, content = self.snapshot()
        self.assertEqual(version, "0.2.0")
        self.assertEqual(content, (ROOT / "api" / f"{version}.txt").read_text(encoding="utf-8"))
        self.assertIn("## include/praxo.h", content)
        self.assertIn("## include/praxo_core.h", content)
        self.assertNotIn("typedef long long", content)

    def test_same_name_api_mutations_change_snapshot(self):
        original = self.snapshot()
        mutations = [
            ("praxo.h", "size_t size", "unsigned int size"),
            ("praxo.h", "void *px_arena_alloc", "const void *px_arena_alloc"),
            ("praxo.h", "const PxValue *left", "PxValue *left"),
            ("praxo.h", "const PxValue *left, const PxValue *right", "const PxValue *left, const PxValue **right"),
            ("praxo.h", "typedef struct PxArenaBlock PxArenaBlock;", "typedef struct OtherBlock PxArenaBlock;"),
            ("praxo.h", "PX_BOOL,", "PX_BOOL = 8,"),
            ("praxo.h", "PX_BOOL,\n    PX_NUM,", "PX_NUM,\n    PX_BOOL,"),
            ("praxo.h", "double number;", "float number;"),
            ("praxo.h", "char *key;", "char *renamed_key;"),
            ("praxo.h", "PxValue **items;", "PxValue *items[2];"),
            ("praxo_core.h", "int max_tokens;\n    int keep_recent;", "int keep_recent;\n    int max_tokens;"),
            ("praxo_core.h", "typedef char *(*PxRepairer)", "typedef const char *(*PxRepairer)"),
            ("praxo_core.h", "void (*emit)(const char *kind, void *ctx);", "int (*emit)(const char *kind, void *ctx);"),
            ("praxo.h", "void px_arena_free(PxArena *arena);", ""),
        ]
        for header, before, after in mutations:
            with self.subTest(before=before):
                self.change(header, before, after)
                self.assertNotEqual(original, self.snapshot())
                shutil.copyfile(ROOT / "include" / header, self.root / "include" / header)

    def test_macro_values_and_function_macros_are_captured(self):
        self.change("praxo.h", "#endif", "#define PX_LIMIT 7\n#define PX_SCALE(x) ((x) * 2)\n#endif")
        first = self.snapshot()
        self.assertIn("define PX_LIMIT 7", first[1])
        self.assertIn("define function PX_SCALE ( x ) ( ( x ) * 2 )", first[1])
        self.change("praxo.h", "PX_LIMIT 7", "PX_LIMIT 8")
        self.assertNotEqual(first, self.snapshot())
        first = self.snapshot()
        self.change("praxo.h", "((x) * 2)", "((x) * 3)")
        self.assertNotEqual(first, self.snapshot())
        first = self.snapshot()
        self.change("praxo.h", "PX_SCALE(x)", "PX_SCALE (x)")
        self.assertNotEqual(first, self.snapshot())

    def test_conditional_default_before_header_guard_is_captured(self):
        header = self.root / "include" / "praxo.h"
        source = header.read_text(encoding="utf-8")
        header.write_text("#ifndef PX_LIMIT\n#define PX_LIMIT 7\n#endif\n" + source, encoding="utf-8")
        first = self.snapshot()
        self.assertIn("define PX_LIMIT 7", first[1])
        self.change("praxo.h", "PX_LIMIT 7", "PX_LIMIT 8")
        self.assertNotEqual(first, self.snapshot())

    def test_new_header_and_includes_are_captured(self):
        original = self.snapshot()
        extra = self.root / "include" / "extra.h"
        extra.write_text("#define PX_EXTRA 1\n", encoding="utf-8")
        self.assertNotEqual(original, self.snapshot())
        self.assertIn("## include/extra.h", self.snapshot()[1])
        extra.unlink()
        self.change("praxo.h", "#include <stddef.h>", "#include <stddef.h>\n#include <stdint.h>")
        self.assertNotEqual(original, self.snapshot())

    def test_comments_and_whitespace_are_ignored(self):
        original = self.snapshot()
        self.change("praxo.h", "void px_arena_free(PxArena *arena);",
                    "/* formatting only */ void\npx_arena_free ( PxArena* arena );")
        self.assertEqual(original, self.snapshot())

    def test_version_mismatches_fail(self):
        self.spec.write_text("0.3.0\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "SPEC_VERSION"):
            self.snapshot()
        self.spec.write_text("0.2.0\n", encoding="utf-8")
        self.change("praxo_core.h", 'PRAXO_CORE_VERSION "0.2.0"', 'PRAXO_CORE_VERSION "0.3.0"')
        with self.assertRaisesRegex(ValueError, "CORE_VERSION"):
            self.snapshot()

    def test_check_is_nonwriting_and_baselines_cannot_be_overwritten(self):
        self.assertEqual(self.run_main("--check"), 1)
        self.assertFalse((self.root / "api").exists())
        self.assertEqual(self.run_main(), 0)
        target = self.root / "api" / "0.2.0.txt"
        original = target.read_bytes()
        stat = target.stat()
        self.assertEqual(self.run_main("--check"), 0)
        self.assertEqual(target.stat().st_mtime_ns, stat.st_mtime_ns)
        self.change("praxo.h", "double number;", "float number;")
        self.assertEqual(self.run_main("--check"), 1)
        self.assertEqual(self.run_main(), 1)
        self.assertEqual(target.read_bytes(), original)
        self.assertEqual(target.stat().st_mtime_ns, stat.st_mtime_ns)

    def test_new_version_preserves_historical_baseline(self):
        self.assertEqual(self.run_main(), 0)
        target = self.root / "api" / "0.2.0.txt"
        original = target.read_bytes()
        for header in ("praxo.h", "praxo_core.h"):
            self.change(header, '"0.2.0"', '"0.3.0"')
        self.assertEqual(self.run_main(), 0)
        self.assertTrue((self.root / "api" / "0.3.0.txt").exists())
        self.assertEqual(target.read_bytes(), original)

    def test_invalid_headers_fail_without_writing(self):
        self.change("praxo.h", "double number;", "NotAType number;")
        self.assertEqual(self.run_main(), 1)
        self.assertFalse((self.root / "api").exists())

    def test_cli_propagates_compiler_failure(self):
        result = subprocess.run([sys.executable, str(ROOT / "api-snapshot.py"), "--check",
                                 "--compiler", str(self.root / "missing-compiler")],
                                cwd=self.root, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("C API snapshot failed", result.stderr)

    def test_compiler_timeout_fails_without_writing(self):
        with patch.object(API.subprocess, "run", side_effect=subprocess.TimeoutExpired([COMPILER], 30)):
            self.assertEqual(self.run_main(), 1)
        self.assertFalse((self.root / "api").exists())

    def test_cmake_compiler_frontend_selection(self):
        cmake = shutil.which("cmake")
        if not cmake:
            self.skipTest("CMake is required for compiler frontend selection")
        helper = (ROOT / "cmake" / "ApiCompiler.cmake").as_posix()
        cases = (("GNU", "GNU", "--compiler;compiler"),
                 ("Clang", "GNU", "--compiler;compiler"),
                 ("AppleClang", "GNU", "--compiler;compiler"),
                 ("Clang", "MSVC", ""), ("MSVC", "MSVC", ""))
        for compiler_id, frontend, wanted in cases:
            with self.subTest(compiler=compiler_id, frontend=frontend):
                script = self.root / "selection.cmake"
                script.write_text(
                    f'include("{helper}")\n'
                    f'praxo_api_compiler_args(args "{compiler_id}" "{frontend}" "compiler")\n'
                    f'if(NOT "${{args}}" STREQUAL "{wanted}")\n'
                    'message(FATAL_ERROR "wrong compiler selection: ${args}")\nendif()\n',
                    encoding="utf-8")
                subprocess.run([cmake, "-P", str(script)], check=True, capture_output=True, timeout=30)

    def test_gcc_and_clang_produce_identical_snapshots(self):
        compilers = [shutil.which(name) for name in ("gcc", "clang")]
        selected = Path(COMPILER).name.lower()
        if selected.startswith("gcc"):
            compilers[0] = COMPILER
        elif selected.startswith("clang"):
            compilers[1] = COMPILER
        if not all(compilers):
            self.skipTest("both GCC and Clang are needed for cross-compiler comparison")
        snapshots = []
        for compiler in compilers:
            try:
                snapshots.append(API.snapshot(self.root, self.spec, compiler))
            except subprocess.CalledProcessError as error:
                if compiler == COMPILER:
                    raise
                self.skipTest(f"additional compiler unavailable: {compiler}: {error.stderr}")
        self.assertEqual(*snapshots)


if __name__ == "__main__":
    unittest.main()
