# Publishing the Delphi/Free Pascal Core

Source tag `delphi/v0.2.1` maps to OPM package `PRAXO-CORE` version `0.2.1.0`.
The package descriptor is `praxo_core.lpk`.

Build the submission files:

```bash
python language/delphi/build_opm.py
```

This creates `language/delphi/build/opm/PRAXO-CORE.zip` and
`language/delphi/build/opm/PRAXO-CORE.json`.

The OPM Submit endpoint (`lazarusopm.org`) no longer resolves; OPM now uses the
manual path. Publish the zip and JSON at stable links and contact the OPM
maintainer through the OPM forum thread:
<https://forum.lazarus.freepascal.org/index.php/topic,34297.0.html>. The 0.2.1
assets are on the GitHub release:

- <https://github.com/axisvela/praxo-core/releases/download/delphi/v0.2.1/PRAXO-CORE.zip>
- <https://github.com/axisvela/praxo-core/releases/download/delphi/v0.2.1/PRAXO-CORE.json>

Run the Free Pascal tests and API snapshot before submitting. Verify
installation from OPM in a clean Lazarus/Free Pascal environment. Commercial
Delphi and other targets remain unverified. The OPM maintainer reviews the
package before adding it to `packagelist.json`.
