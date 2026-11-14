# Identity and Policy

This example binds a trusted principal to a C Core policy callback and rejects
missing, inactive, role-mismatched, and tenant-mismatched actions.

```bash
gcc -std=c11 -I language/c/include language/c/examples/identity-policy/main.c \
  language/c/build/libpraxo_core.a -o build/c-identity-policy
./build/c-identity-policy
```

Expected output:

```text
C identity policy example passed
```
