# PRAXO-CORE for Objective-C

Unreleased native Wire-stage candidate targeting a Framework implementation.
The current code has no agent loop, model provider, process bridge, or plugin
host. It does not call Go or another language SDK.

Local validation uses clang 21.1.8 with GNUstep Base 1.31.1 and lld on Windows.
A macOS CI job using Apple Foundation is configured. Local Apple Foundation,
release review, package publication, commercial support, and a delivery date
are not claimed.

## Build and Test

From the repository root with Python 3.10 or newer:

```bash
python language/objc/run-tests.py
python language/objc/api-snapshot.py --check
```

Set `CLANG` or pass `--compiler /path/to/clang`. On Windows, the GNUstep runtime
directory must be on `PATH` so the test executable can load `gnustep-base` and
the Objective-C runtime. The runner links GNUstep builds with lld because the
GNU ld PE/COFF path discards the GNUstep selector COMDAT sections.

To build manually on macOS from `language/objc/`:

```bash
clang -fobjc-arc -I. -o build/praxo_tests \
  PraxoJSON.m PraxoJsonSchema.m PraxoPlugin.m PraxoWire.m tests/main.m \
  -framework Foundation
build/praxo_tests ../../spec
```

For a GNUstep build, use `-fobjc-runtime=gnustep-2.0 -fuse-ld=lld` and link
`-lgnustep-base -lobjc`.

## API

```objc
#import "PraxoWire.h"

NSError *error = nil;
NSDictionary *call = PXRParseToolCall(
    @"<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>", &error);
NSString *text = PXRStripToolCallMarkup(content);
NSArray<NSString *> *paths = PXRValidateSchema(schema, data);
NSDictionary *manifest = PXRParseManifest(raw, &error);
```

Public declarations are inventoried in [`api/unreleased.txt`](api/unreleased.txt).
The parser returns `nil` when the content is not a recognized call or the
manifest is invalid. Schema validation returns error paths. SDK-local
`PXRWireErrorDomain` codes are not new shared wire error codes.

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
- Manifest checks validate declarations only. They do not verify signatures,
  establish trust, execute plugins, or enforce OS sandboxing.
- Passing three vector groups does not imply full Framework or Go feature parity.

The source is MIT; see [LICENSE](LICENSE). Clang, GNUstep, and other toolchain
components are separate projects, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/objc.md), and
[implementation support](../../docs/languages/support.md).
