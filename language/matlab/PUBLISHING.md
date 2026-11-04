# Publishing the MATLAB/Octave Core

Source tag `matlab/v0.2.1`. The package is not published to Octave Packages or
the MATLAB File Exchange.

For **Octave Packages**, add package metadata and package the `+praxo`
directory, then open a pull request to
<https://github.com/gnu-octave/packages>. No separate account is required.

For **MATLAB File Exchange**, use a MathWorks account and submit the packaged
toolbox manually. Octave verification is not MATLAB verification.

Run `python language/matlab/run-tests.py --octave octave-cli`, the API snapshot,
and install the archive in a clean Octave environment before publishing.
