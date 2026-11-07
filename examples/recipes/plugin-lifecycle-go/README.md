# Plugin Lifecycle Recipe (Go)

This recipe exercises the guarded per-instance plugin lifecycle: only ACTIVE
accepts calls, transitions are explicit, Drain waits for in-flight calls with a
bounded context, and UNLOADED/QUARANTINED are terminal.

**Evidence level: L1 contract recipe.** It demonstrates the lifecycle state
machine. It does not prove process/WASM isolation, manifest trust, signature
verification, or production plugin hosting. See
[plugin trust](../../../docs/security/plugin-trust.md) and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -v ./...
```

The tests show:

- Acquire is rejected before ACTIVE;
- a skipped transition is rejected and leaves the state unchanged;
- Release without Acquire is an underflow;
- Drain waits for the last in-flight call, then moves to STOPPED;
- deadline expiry and parent cancellation are distinct and stay DRAINING;
- Revoke moves ACTIVE all the way to UNLOADED and is a no-op when already
  UNLOADED;
- Quarantine is terminal and rejects further transitions and revoke.

From the repository root, `python scripts/test_go_plugin_lifecycle_recipe.py -v`
repeats the checks in a fresh temporary module using the published package.
