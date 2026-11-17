# Publishing the Delphi/Free Pascal Core

Source tag `delphi/v0.7.0` maps to OPM package `PRAXO-CORE` version `0.7.0.0`.
The package descriptor is `praxo_core.lpk`; it lists all eleven Core units.

Build the submission files:

```bash
python language/delphi/build_opm.py
```

This creates `language/delphi/build/opm/PRAXO-CORE.zip` and
`language/delphi/build/opm/PRAXO-CORE.json`. The 0.7.0 assets are on the GitHub
release:

- <https://github.com/axisvela/praxo-core/releases/download/delphi/v0.7.0/PRAXO-CORE.zip>
- <https://github.com/axisvela/praxo-core/releases/download/delphi/v0.7.0/PRAXO-CORE.json>

The 0.7.0 zip is 44,098 bytes with MD5
`5ac7bb339992e3b072592cf19fd03640`. `run-tests.py` and the API snapshot pass
locally with Free Pascal 3.2.2.

The OPM Submit endpoint (`lazarusopm.org`) no longer resolves; OPM now uses the
manual path. The remaining step is to publish the two stable links and contact
the OPM maintainer through the OPM forum thread:
<https://forum.lazarus.freepascal.org/index.php/topic,34297.0.html>.

Suggested forum message:

```text
Package: PRAXO-CORE 0.7.0.0
Descriptor: praxo_core.lpk
Zip: https://github.com/axisvela/praxo-core/releases/download/delphi/v0.7.0/PRAXO-CORE.zip
JSON: https://github.com/axisvela/praxo-core/releases/download/delphi/v0.7.0/PRAXO-CORE.json
MD5: 5ac7bb339992e3b072592cf19fd03640
License: MIT
```

After the maintainer adds the package to `packagelist.json`, verify
installation from OPM in a clean Lazarus/Free Pascal environment. Commercial
Delphi and other targets remain unverified.
