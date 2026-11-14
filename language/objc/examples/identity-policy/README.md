# Identity and Policy

This example binds a trusted principal to policy decisions and rejects missing,
role-mismatched, and tenant-mismatched actions.

```bash
clang -fobjc-arc language/objc/examples/identity-policy/identity_policy.m \
  -framework Foundation -o build/objc-identity-policy
./build/objc-identity-policy
```

Expected output:

```text
Objective-C identity policy example passed
```
