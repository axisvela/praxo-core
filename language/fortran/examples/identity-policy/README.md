# Identity and Policy

This example binds a trusted principal to policy decisions and rejects missing,
inactive, role-mismatched, and tenant-mismatched actions.

```bash
gfortran language/fortran/examples/identity-policy/identity_policy_example.f90 \
  -o build/fortran-identity-policy
./build/fortran-identity-policy
```

Expected output:

```text
Fortran identity policy example passed
```
