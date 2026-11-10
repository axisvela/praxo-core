# Publishing the Lua Core

## Status

Source tag `lua/v0.4.1` maps to rock revision `0.4.1-1`. The release workflow is
`.github/workflows/lua-release.yml`. LuaRocks publishes `0.4.1-1`; the earlier
`0.4.0-1`, `0.3.0-1`, and `0.2.0-1` revisions remain available.

<https://luarocks.org/modules/hanhhuiwen/praxo-core>

## Rockspec

The rockspec is `language/lua/praxo-core-0.4.1-1.rockspec`. Its `source.url`
points at the main repository tag and its `build.modules` paths start with
`language/lua/`. The source rock is built from that tag, so the source and
rockspec versions stay aligned.

## Local gates

```bash
lua language/lua/conformance/run.lua
python language/lua/api-snapshot.py --check
lua language/lua/tests/run.lua
luarocks --lua-version 5.4 --tree build/lua-tree make --deps-mode=none language/lua/praxo-core-0.4.1-1.rockspec
LUA_PATH="build/lua-tree/share/lua/5.4/?.lua;build/lua-tree/share/lua/5.4/?/init.lua;;" lua language/lua/tests/installed_smoke.lua
```

The workflow uses the same sequence on Linux. Windows LuaRocks can hang while
setting executable permissions on the install tree; use the Linux workflow or a
Linux environment for final rock verification.

## Workflow

The `build` job:

1. Verifies `language/lua/VERSION`, the rockspec version/tag, and the push tag.
2. Runs conformance, the API snapshot, and native tests.
3. Packs the source rock, installs it into a clean tree, and runs
   `tests/installed_smoke.lua`.
4. Uploads the `.src.rock` artifact.

The `publish` job runs on a `lua/v*` tag push or an explicit manual `publish`
target. It skips an already published revision, otherwise uploads with
`--skip-pack` using a temporary LuaRocks API key. Manual dispatch defaults to
`build-only`.

## Credentials

- Configure the GitHub environment `luarocks` and the repository secret
  `LUAROCKS_API_KEY`.
- Do not print, commit, or store the key in a rockspec or documentation file.
- Keep local LuaRocks configuration and TLS interception certificates outside
  the repository.

## Verify

```bash
luarocks search praxo-core
luarocks install praxo-core
```

The published module page and a clean-tree install are the release evidence.
