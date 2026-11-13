from dataclasses import dataclass

from praxo.checkpoint import Allowlist


@dataclass
class CheckpointRecord:
    id: str
    session_id: str
    version: int
    payload: bytes


class MemoryStore:
    def __init__(self) -> None:
        self._records: dict[str, CheckpointRecord] = {}

    def save(self, record: CheckpointRecord) -> None:
        self._records[record.session_id] = record

    def load(self, session_id: str) -> CheckpointRecord | None:
        return self._records.get(session_id)


def default_allowlist() -> Allowlist:
    allowlist = Allowlist()
    allowlist.register("order", lambda: {"session_id": "", "items": []})
    return allowlist


def save_checkpoint(
    store: MemoryStore,
    allowlist: Allowlist,
    session_id: str,
    version: int,
    items: list[str],
) -> CheckpointRecord:
    payload = allowlist.marshal(
        "order",
        {"session_id": session_id, "items": items},
    )
    record = CheckpointRecord(
        id=f"cp-{version}",
        session_id=session_id,
        version=version,
        payload=payload,
    )
    store.save(record)
    return record


if __name__ == "__main__":
    raise SystemExit(
        "This example is runnable through its test; wire a durable store in checkpoint_store.py."
    )
