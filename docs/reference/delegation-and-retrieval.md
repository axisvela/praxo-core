# Delegation and Retrieval Seams

These are optional adapter seams. They do not add a durable worker service, a
vector database, or new Core wire contracts.

## Delegation

A subagent manager owns local child runs:

- Modes: `isolated` starts with only the request; `fork` carries the parent
  message history.
- States: `queued`, `running`, `completed`, `failed`, `canceled`.
- Operations: launch, check, wait, optional mid-flight update, and cancel.
- Cancellation is local. It is not proof that remote work stopped.
- A terminal state is final for the local task; it is not an exactly-once or
  durable execution guarantee.

The Go reference is `pkg/agent/delegation`. Python provides
`praxo.delegation.SubagentManager` with an async runner seam; TypeScript
provides `src/delegation.ts` `SubagentManager`; Java provides
`agent.delegation.SubagentManager`; Rust provides
`delegation::SubagentManager`; C# provides
`Praxo.Core.Delegation.SubagentManager`; R provides a synchronous
`subagent_run` seam without an asynchronous manager; Ruby provides
`Delegation::SubagentManager`; PHP provides a synchronous
`SubagentManager::run` seam; Elixir provides `Praxo.SubagentManager`; Lua, C,
C++, Fortran, Haskell, OCaml, Swift, Dart, and Perl provide synchronous seams. Other
implementations do not have an in-tree delegation manager yet.

## Retrieval

A retriever seam maps a query and limit to documents:

- `Document`: id, content, optional metadata, optional score.
- `Retriever`: retrieve query/limit and return documents.
- A function adapter is sufficient for local or caller-owned retrieval.

The Go reference is `pkg/retriever`. Python provides `praxo.retriever` with
`Document`, `Retriever`, and `FuncRetriever`; TypeScript provides
`src/retriever.ts` with the same shapes; Java provides `retriever.Document` and
`retriever.Retriever`; Rust provides `retriever::Document` and `Retriever`; C#
provides `Praxo.Core.Retriever.Document` and `Retriever`; R provides
`document` and `retriever_retrieve`; Ruby provides `Document` and
`FuncRetriever`; PHP provides `Document`, `Retriever`, and `FuncRetriever`;
Elixir provides `Praxo.Document` and `Praxo.FuncRetriever`; Lua provides
`document` and `retriever_retrieve`; C provides `PxDocument` and `PxRetriever`;
C++ provides `Document` and `Retriever`; Fortran provides `document` and
`retriever`; Haskell provides `Praxo.Retriever.Document` and `Retriever`; OCaml
provides `document` and `retrieve_documents`; Swift provides `Document`, `FuncRetriever`, and `retrieveDocuments`; Dart provides `Document`, `FuncRetriever`, and `retrieveDocuments`; Perl provides `document`, `func_retriever`, and `retrieve_documents`. Other implementations do not have
an in-tree retriever yet.

Retrieval does not define an embedding model, vector store, ranking service, or
search-quality claim. Memory stores and context compaction remain separate Core
surfaces.

## Baseline Status

The canonical per-language list is the
[adapter status](../languages/adapter-status.md#delegation) and
[retriever](../languages/adapter-status.md#retriever) tables. Current evidence
is deterministic fixture or fake-runner coverage, not live worker or search
systems.

## Testing

Delegation tests cover launch, completion, failure, cancel, optional update,
unknown tasks, and validation. Retrieval tests cover the document shape,
query/limit forwarding, and the function seam.
