# Durable Checkpoint Store Recipe (Go)

This recipe implements the `checkpoint.Store` contract with an application-owned
JSON file store. Writes use a temporary file, `Sync`, and `Rename`; a reopen
loads the persisted checkpoint, and a leftover temporary file is ignored.

**Evidence level: L4 application recipe.** It demonstrates one durable-store
pattern. It is not a concurrent database, a power-loss proof, a tenant authority,
or an exactly-once guarantee. See the
[checkpoint example](../../checkpoint/) and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -v ./...
```

The tests show:

- save, load-latest, load-by-run, and list ordering;
- replacement of an earlier checkpoint for the same session and run;
- recovery after closing and reopening the store;
- a partially written `.tmp` file does not corrupt the load;
- tenant-scoped and unscoped loads;
- deletion by checkpoint id.

The store is teaching code. Production checkpoints need concurrent-write
control, retention, encryption, tenant enforcement, and deployment-level
recovery policy. A checkpoint is a recovery hint, not a transaction or proof
that an external effect committed.

From the repository root, `python scripts/test_go_checkpoint_store_recipe.py -v`
repeats the checks in a fresh temporary module using the published package.
