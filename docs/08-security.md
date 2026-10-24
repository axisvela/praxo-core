# Framework Threat Model

**Status:** working security baseline for the 2.3.x line. This is a threat model,
not independent security sign-off.

## Assets

- local files, processes, and shell execution
- provider and adapter credentials
- plugin payloads and manifests
- session, memory, and checkpoint data
- policy decisions and audit/event facts

## Trust Boundaries

1. **Application -> agent loop.** Model output, tool names, and tool arguments
   are untrusted input.
2. **Agent -> tool/policy.** The framework enforces the policy decision and the
   tool allowlist; it does not implement authorization policy.
3. **Framework -> plugin host.** Core hosts expect an already-verified payload.
   Signature, SBOM, and trust-store checks are product-owned.
4. **Plugin host -> OS.** Process and WASM hosts apply containment, timeouts,
   cancellation, and resource bounds.
5. **Framework -> HTTP adapters.** The shared client uses default TLS
   verification and sends caller-supplied credentials.
6. **Framework -> sandbox.** `pkg/sandbox` is an interface; the embedding
   product owns the concrete isolation.

## Security Invariants

- Policy denial fails closed; every model/tool action can be authorized.
- Allowed tools are both advertised and enforced.
- A plugin host admits calls only in `ACTIVE` state; every other state rejects.
- Process tokens are passed by environment, never argv. Child environments are
  not inherited unless the caller supplies them.
- Process hosts apply platform limits when required and fail to start when the
  platform cannot enforce them.
- WASM guests are bounded by linear-memory pages and context cancellation.
- `policy.PathChecker` resolves symlinks, rejects traversal and sibling-prefix
  escapes, and is deny-by-default.
- The HTTP client does not disable TLS verification. Callers choose the base
  URL and credentials.
- The framework stores no provider credentials, tenant policy, or trust roots.

## Known Limitations

- **Governance is opt-in.** A nil `Policy` permits actions, and an empty
  `AllowedTools` permits all registered tools. Configure both explicitly for a
  least-privilege application; the framework is not an authorization service.
- **Final tool-call checks since 2.3.3.** Original policy denials still stop
  preparation. Changes to a tool name or JSON arguments during preparation are
  rechecked before the batch executes; unchanged calls keep one policy request.
  This fix is not included in the older 2.3.2 tag.
  Hook arguments must remain JSON-serializable when policy is enabled. Callbacks
  must not mutate retained arguments asynchronously, and tools still own their
  internal side effects and resource-level checks.
- **No signature/SBOM verification in core.** A product must verify the
  descriptor, signature, and SBOM before starting a host. Unsigned local
  development is an explicit product trust-profile decision.
- **PathChecker is check-then-use.** A symlink can change between the check and
  the file operation. High-risk callers should combine it with OS-level
  confinement or open-by-handle APIs.
- **Linux process containment is weaker than Windows.** Per-process rlimits and
  a process group do not provide the same hard guarantee as a Windows Job
  Object; see `pkg/plugin/host/process/limits_linux.go`.
- **No WASM CPU fuel in v1.** A CPU-bound guest relies on context cancellation
  and forced termination, not deterministic fuel accounting.
- **HTTP redirects.** `pkg/httpclient` uses Go's default redirect policy.
  Response bodies are bounded by default (32 MiB) and can be overridden with
  `Config.MaxBodyBytes`; callers should still use trusted base URLs.
- **Virtual filesystem confinement.** `pkg/vfs/localfs` rejects absolute paths, traversal, sibling prefixes, and symlink escapes via `policy.PathChecker`. Like PathChecker itself, it is check-then-use; high-risk callers should add OS-level confinement.
- **Offloaded tool results.** The `Offloader` is caller-owned; stored bytes may
  contain sensitive data. The framework only replaces prompt content and does
  not choose storage, encryption, or retention.
- **Go standard-library fixes.** CI and release builds use Go `1.26.10` so the
  `net/http` fixes in Go 1.26.9+ and the `crypto/x509` fix for GO-2026-6809 are
  present. Consumers on older toolchains should upgrade before deploying the
  HTTP client.
- **Prompt injection is not a framework vulnerability by itself.** The
  enforcement boundary is policy plus tool allowlisting, not model text.
- **No plugin-to-plugin calls and no dynamic capability escalation** in v1.

## 1.0 Review Checklist

- [x] exported API doc-comment audit
- [x] fuzz tests added: manifest parser, tool-call parser, JSON Schema, path checker
- [x] race tests passing in CI
- [x] CI matrix configured: Linux, Windows, macOS
- [x] `go vet`, `staticcheck`, and `govulncheck` locally
- [x] SBOM/checksum tooling verified locally
- [x] release published with SBOM/checksums (annotated tag)
- [ ] independent review of host containment and path containment
- [x] external integrator example added; least-privilege policy profile remains

## Reporting

See [SECURITY.md](https://github.com/axisvela/praxo-core/blob/main/SECURITY.md).
