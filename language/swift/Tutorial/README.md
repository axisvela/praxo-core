# Swift Tutorials

Application-shaped Swift examples that keep the Agent inside an Apple-platform
runtime. Mechanism checks remain under `language/go/examples/`.

- [Chronic Care (HC-02)](chronic-care/README.md): fixed wearable trends, review-only
  care alert and no dosage/treatment change.

## Language and runtime fit

Swift is the default language for existing Apple-platform applications, UIKit/
SwiftUI clients and health-adjacent apps. The tutorial targets that host shape.

Language and ecosystem traits:

- First-class Apple platform frameworks and tooling.
- Strong static typing and value semantics.
- Native performance with a managed memory model.

Trade-offs:

- Non-Apple tooling is less mature; local Windows verification is currently blocked.
- Platform APIs and app lifecycle remain application-owned.

Praxo-specific fit: the tutorial demonstrates the Core tool/policy seam in Swift;
it does not claim HealthKit integration or clinical validity.
