# Publishing the Lua Core

## Status

`praxo-core` `0.3.0-1` was published to LuaRocks from source tag
`lua/v0.3.0`:

<https://luarocks.org/modules/hanhhuiwen/praxo-core>

## Build

The rockspec is `language/lua/praxo-core-0.3.0-1.rockspec`. Its `source.url`
points at the main repository tag and its `build.modules` paths start with
`language/lua/`.

Local gates:

```bash
luarocks make language/lua/praxo-core-0.3.0-1.rockspec
lua language/lua/tests/run.lua
lua language/lua/conformance/run.lua
python language/lua/api-snapshot.py --check
```

## Publish

Normal command:

```bash
cd language/lua
luarocks upload praxo-core-0.3.0-1.rockspec
```

Windows workaround used for `0.3.0-1`: `luarocks upload` failed while packing
with `Failed creating temporary directory: Failed setting permission exec for
all`. Build the source rock locally and upload it with `--skip-pack`:

```python
import zipfile
from pathlib import Path
root = Path(".")
out = root / "build" / "praxo-core-0.3.0-1.src.rock"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(root / "language/lua/praxo-core-0.3.0-1.rockspec",
            "praxo-core-0.3.0-1.rockspec")
    for path in sorted((root / "language/lua").rglob("*")):
        if path.is_file():
            z.write(path, "praxo-core-0.3.0/" + path.as_posix())
    z.write(root / "LICENSE", "praxo-core-0.3.0/LICENSE")
```

```powershell
cd language/lua
luarocks upload --skip-pack praxo-core-0.3.0-1.rockspec `
  ..\..\build\praxo-core-0.3.0-1.src.rock
```

## Credentials and configuration

- LuaRocks API key: `upload.api_key` in
  `C:\Users\hanhw1\AppData\Roaming\luarocks\config-5.4.lua` and
  `C:\Users\hanhw1\.luarocks\config-5.4.lua`.
- Do not print or commit the key. `luarocks upload` reads it from config.
- Network: the environment uses an HTTPS proxy with TLS interception. Export
  the trusted `mitmproxy` root from the Windows certificate store and set
  `SSL_CERT_FILE` and `CURL_CA_BUNDLE` before uploading. The CA file is a local
  build artifact.

## Verify

```bash
luarocks search praxo-core
```

The published module page is the primary evidence.
