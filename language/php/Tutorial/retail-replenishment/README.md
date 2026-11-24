# PHP Retail Replenishment (CS-05)

Computes a reorder quantity from fixed stock and drafts a review-only order. No
purchase order or supplier call.

## Why this language and runtime?

- **Selection basis:** PHP often serves store operations dashboards; the review
  step can stay next to existing inventory views.
- **Demonstrated fit:** A deterministic threshold computes a quantity of 40 and
  drafts one replenishment request.
- **Choose when:** Adding a review-only replenishment draft to a PHP store tool.
- **Do not choose when:** Seeking automated purchasing or supplier commitments.
  Compare the current replenishment rules first.
- **Evidence limit:** One fixed SKU and store only; no live inventory, supplier,
  purchase order or forecast claim.

## Run

```bash
php language/php/Tutorial/retail-replenishment/app.php --test
```

Expected output:

```text
PHP CS-05 retail-replenishment tutorial: success, denial and dependency failure passed
```

No purchase order, supplier call or inventory write is implemented. Store
identity, approval and purchasing belong to the consumer.
