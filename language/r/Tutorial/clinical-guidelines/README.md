# R Clinical Guidelines (HC-01)

Retrieves fixed guideline citations and abstains when evidence is missing. No
diagnosis or treatment decision.

## Why this language and runtime?

- **Selection basis:** R is used in clinical analytics where cited evidence must
  remain separate from decisions.
- **Demonstrated fit:** Native R returns two citations for one topic and abstains
  on a topic with no evidence.
- **Choose when:** Evaluating a read-only evidence seam beside R analysis.
- **Do not choose when:** Seeking diagnosis, triage or treatment advice. Compare
  clinical governance and licensed sources first.
- **Evidence limit:** Two fixed topics only; no guideline corpus, patient data or
  clinical validation.

## Run

```bash
Rscript language/r/Tutorial/clinical-guidelines/clinical_guidelines.R --test
```

Expected output:

```text
R clinical-guidelines tutorial: all checks passed
```

No diagnosis, treatment or patient data access is implemented. Clinical review
and source licensing belong to the consumer.
