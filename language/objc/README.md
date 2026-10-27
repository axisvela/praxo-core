# PRAXO-CORE for Objective-C

Objective-C is a native Core implementation targeting the PRAXO-CORE
contract. It passes all eleven shared vector groups and includes the native
agent loop, context compaction, memory store, path policy, checkpoint
allowlist, tool selection, and tool-call parsing. PII, structured output, and
call limit are standalone helpers, not integrated agent middleware. Vector
coverage does not establish full Core parity or production readiness.

The SDK does not call Go or another language runtime. It has no provider
adapter or plugin host; those remain outside the declared Core scope.

Local validation uses clang 21.1.8 with GNUstep Base 1.31.1 and lld on Windows.
A macOS CI job using Apple Foundation is configured. Local Apple Foundation,
macOS CI, release review, package publication, and a delivery date are not
claimed.

## Build And Test

From the repository root with Python 3.10 or newer:

```bash
python language/objc/api-snapshot.py --check
python language/objc/run-tests.py
```

`run-tests.py` also checks the API snapshot before compiling. Set `CLANG` or pass
`--compiler /path/to/clang`. On Windows, the GNUstep runtime directory must be on
`PATH` so the test executable can load `gnustep-base` and the Objective-C
runtime. The runner links GNUstep builds with lld because the GNU ld PE/COFF
path discards the GNUstep selector COMDAT sections.

To build manually on macOS from `language/objc/`:

```bash
clang -fobjc-arc -fblocks -I. -o build/praxo_tests \
  PraxoJSON.m PraxoJsonSchema.m PraxoPlugin.m PraxoWire.m \
  PraxoCore.m PraxoAgent.m tests/main.m tests/correlation.m \
  -framework Foundation
build/praxo_tests ../../spec
```

For a GNUstep build, use `-fobjc-runtime=gnustep-2.0 -fuse-ld=lld` and link
`-lgnustep-base -lobjc -lstdc++`.

The complete local environment procedure, including manual clang and GNUstep
installation, is in [SETUP.md](SETUP.md).

## API

```objc
#import "PraxoCore.h"

NSDictionary *call = PXRParseToolCall(
    @"<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>", nil);
NSString *text = PXRStripToolCallMarkup(content);
NSArray<NSString *> *paths = PXRValidateSchema(schema, data);
NSDictionary *manifest = PXRParseManifest(raw, &error);

NSMutableDictionary *options = PXRAgentOptionsCreate(PXRModelCreateStatic(@"hello"));
NSError *runError = nil;
NSDictionary *result = PXRAgentRun(options, PXRSessionCreate(@"s1", @[]), @"hello", &runError);
```

Public declarations are inventoried in [`api/unreleased.txt`](api/unreleased.txt).
Agent events use the supplied session's `id` and a UUID-based run ID; the
existing event sink callback is unchanged.
Set `options[@"toolSelection"]` to a set from `PXRToolSelectionCreate` to
advertise and permit only selected tool names. An empty set denies all tools;
omitting the option preserves unrestricted tool behavior. A call to an
unselected name fails with `AGENT_TOOL_NOT_SELECTED` before invocation.
The parser returns `nil` when the content is not a recognized call or the
manifest is invalid. Schema validation returns error paths. SDK-local
`PXRWireErrorDomain` and `PXRCoreErrorDomain` codes are not new shared wire
error codes.

## Current Limits

- The verified target is Windows clang + GNUstep. Apple Foundation and macOS CI
  are not yet verified. Windows support depends on the GNUstep package and lld.
- JSON is bounded to 1,048,576 characters and nesting to 64. Invalid UTF-8,
  malformed escapes, duplicate object keys, and trailing JSON are rejected.
  Numbers use Foundation JSON numbers, so large integers and exact decimal
  spellings may lose precision.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. DSML, invoke, todo, and skill-install formats are not implemented.
  Generated call IDs are not provided. Markup stripping is not an authorization
  control or security sanitizer.
- Schema patterns use a bounded ASCII `NSRegularExpression` subset, not full
  RE2. Zero bounds are treated as unset, additional properties are allowed, and
  unknown keywords are ignored.
- Path checks are lexical and confined by separator boundaries. Relative paths
  retain unmatched parent components and are compared as written, not resolved
  against a working directory. Checks do not resolve symlinks, filesystem
  aliases, or replace operating-system sandboxing.
- Manifest checks validate declarations only. They do not verify signatures,
  establish trust, execute plugins, or enforce OS sandboxing.
- Provider adapters, streaming wire encodings, and plugin hosts are not part of
  this SDK.

The source is MIT; see [LICENSE](LICENSE). Clang, GNUstep, and other toolchain
components are separate projects, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/objc.md), and
[implementation support](../../docs/languages/support.md).
