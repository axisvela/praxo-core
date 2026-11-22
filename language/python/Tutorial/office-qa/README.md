# Python Office Q&A

A native Python Core tutorial for office-policy Q&A with citations. The Agent has
one fixed tool, `search_documents`, which searches three synthetic policy
documents. The deterministic model packages the top search result and its document
ID into an answer. It does not read arbitrary files, call a connector, update the
documents or send email.

## Run

From this directory:

```bash
python -m pip install -r requirements.txt
python app.py
python app.py --query "travel approval"
```

Output:

```json
{"answer":"According to handbook: Expense reports are due on the fifth. Travel requires manager approval. Attach receipts to every expense report.","citations":["handbook"],"matches":[{"id":"handbook","score":2,"snippet":"Expense reports are due on the fifth. Travel requires manager approval. Attach receipts to every expense report."}],"mutating_actions":[]}
```

## Failure Checks

```bash
python app.py --scope private
python app.py --simulate-failure
python app.py --test
```

The first request is denied by Agent policy before the tool runs (`reads=0`). The
second simulates an unavailable document index after one read (`reads=1`) and
exits nonzero. The `--test` mode covers success, denial and dependency failure.

## Optional Live Model

```bash
export PRAXO_BASE_URL=http://127.0.0.1:11434/v1
export PRAXO_MODEL=qwen2.5:0.5b
python app.py --live
```

Live mode uses the same `search_documents` tool but has not been verified for this
example. The answer must still cite a returned document ID; do not let a model
invent a policy or a citation.

## Boundaries

- The search tool is fixed to synthetic in-process documents; no path, URL, SQL
  query or connector comes from the model.
- The answer is a teaching extraction, not a legal or HR decision, and the
  citations prove retrieval, not truth or policy currency.
- Application identity, access policy, document retention, connector isolation,
  approval and audit remain application-owned.
- There is no live provider verification, production document store, email/calendar
  action, public hosting or independent consumer evidence.
