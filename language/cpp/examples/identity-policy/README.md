# Identity and Policy

This example binds a trusted principal to C++ Core policy decisions and rejects
missing, inactive, role-mismatched, and tenant-mismatched actions.

```bash
g++ -std=c++20 -I language/cpp/include language/cpp/examples/identity-policy/main.cpp \
  language/cpp/build/libpraxo_cpp.a -o build/cpp-identity-policy
./build/cpp-identity-policy
```

Expected output:

```text
C++ identity policy example passed
```
