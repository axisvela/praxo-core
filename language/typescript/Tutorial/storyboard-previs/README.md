# TypeScript Storyboard Previs (MD-01)

Turns a fixed script scene into a review-only shot plan. No rendering or
virtual-production engine.

## Why this language and runtime?

- **Selection basis:** TypeScript fits web-based previs and production tooling;
  the plan review can stay in the existing app.
- **Demonstrated fit:** Two fixed pages and three beats yield a draft-only plan
  with three shots.
- **Choose when:** Evaluating a bounded shot-plan seam before production.
- **Do not choose when:** Seeking rendering or verified Unreal integration.
  Compare the production pipeline first.
- **Evidence limit:** One fixed scene only; no renderer, engine, asset or
  production output.

## Run

```bash
npm ci
npm test
```

Expected output:

```text
TypeScript MD-01 storyboard-previs tutorial: all checks passed
```

No renderer, Unreal integration or asset pipeline is implemented. Rights and
production approval belong to the consumer.
