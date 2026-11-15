# Java HITL

This example uses published Maven Central `com.axisvela:praxo-core:0.9.0` to
approve one write, then edit it to a target that the policy rejects.

## Run

```bash
cd language/java/examples/hitl
mvn -q compile exec:java
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```

The first decision approves the original `public` note. The second edits the
arguments to `private`; the policy runs again on the edited arguments and denies
the effect. This is an integration starting point, not a production approval
service or durable approval store.
