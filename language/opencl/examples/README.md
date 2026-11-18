# PRAXO-CORE OpenCL Sample

OpenCL is a compute API, not an independent contract implementation. This sample
reuses the C Core's JSON parser and runs a trivial OpenCL kernel, showing one way
to host GPU/compute work alongside a PRAXO-CORE tool implementation. It does not
implement an agent loop, wire codec, or provider adapter.

## Build and run

Install OpenCL headers, an ICD loader, and a device. On Debian/Ubuntu:

```bash
sudo apt-get install -y ocl-icd-opencl-dev pocl-opencl-icd
cc -std=c11 -DCL_TARGET_OPENCL_VERSION=300 \
  -I language/c/include -I language/c/src \
  language/opencl/examples/sample.c language/c/src/json.c \
  -lOpenCL -lm -o build/opencl-sample
./build/opencl-sample
```

POCL provides a CPU device when no GPU ICD is installed. CI uses the same
packages and command.

## Usage

The sample parses a PRAXO tool-call JSON value with `px_parse` and runs an
OpenCL kernel that adds one to each element. A real integration would dispatch
compute work from a tool callback and return the result as JSON; OpenCL itself
does not implement the PRAXO-CORE contract.

## Representative Chain and Governance

OpenCL uses the C Core and has no separate agent loop. Run the host language
chain and delegation tests instead of creating a separate OpenCL chain:

- [`test_representative_chain.c`](../../c/tests/test_representative_chain.c)
- [`test_delegation_governance.c`](../../c/tests/test_delegation_governance.c)

## Release

No separate tag. The sample reuses the C package `c/v0.2.0`.
