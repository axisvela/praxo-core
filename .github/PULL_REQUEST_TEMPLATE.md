## Summary

Explain the change and why it is needed.

## Testing

- [ ] `GOWORK=off go test ./...`
- [ ] `GOWORK=off go vet ./...`
- [ ] `GOWORK=off go build ./...`
- [ ] `GOWORK=off go test -race ./...`
- [ ] `examples/ecosystem-sdk` tests pass, if affected

## Compatibility

- [ ] No exported API change
- [ ] Exported API change documented in `CHANGELOG.md` and `docs/05-compatibility.md`

## Checklist

- [ ] Tests added or updated
- [ ] Documentation updated
- [ ] No credentials, tenant data, secrets, or AGPL-only imports
