from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol, runtime_checkable

from .errors import PolicyError

PathAccess = str

ACCESS_READ = "read"
ACCESS_WRITE = "write"
ACCESS_READWRITE = "readwrite"

_ACCESS = {ACCESS_READ, ACCESS_WRITE, ACCESS_READWRITE}


@dataclass
class Action:
    kind: str
    session_id: str
    tool_name: str | None = None
    arguments: dict[str, Any] = field(default_factory=dict)


@dataclass
class Decision:
    allowed: bool
    reason: str = ""


@runtime_checkable
class Hook(Protocol):
    async def authorize(self, action: Action) -> Decision: ...


class FuncHook:
    def __init__(self, fn: Any) -> None:
        self.fn = fn

    async def authorize(self, action: Action) -> Decision:
        result = self.fn(action)
        if hasattr(result, "__await__"):
            return await result
        return result


@dataclass
class PathGrant:
    root: str
    access: str


@dataclass
class PathChecker:
    grants: list[PathGrant]

    def __post_init__(self) -> None:
        resolved: list[PathGrant] = []
        for grant in self.grants:
            if not grant.root:
                raise PolicyError("policy: path grant root is required")
            if grant.access not in _ACCESS:
                raise PolicyError(f"policy: invalid grant access {grant.access!r}")
            resolved.append(PathGrant(root=_resolve(grant.root), access=grant.access))
        self.grants = resolved

    def check(self, target: str, need: str = ACCESS_READ) -> Decision:
        if need not in _ACCESS:
            raise PolicyError(f"policy: invalid requested access {need!r}")
        if not self.grants:
            return Decision(False, "no allowed roots")
        resolved = _resolve(target)
        matched = ""
        for grant in self.grants:
            if not _within(grant.root, resolved):
                continue
            matched = grant.root
            if _allows(grant.access, need):
                return Decision(True, f"path within {grant.root}")
        if matched:
            return Decision(
                False,
                f"path within {matched} but the grant is insufficient",
            )
        return Decision(False, "path outside allowed roots")

    def allowed(self, target: str, need: str = ACCESS_READ) -> bool:
        try:
            return self.check(target, need).allowed
        except PolicyError:
            return False


def _resolve(value: str) -> str:
    try:
        return str(Path(value).resolve(strict=False))
    except OSError as exc:
        raise PolicyError(f"policy: resolve {value}: {exc}") from exc


def _within(root: str, target: str) -> bool:
    root_value = os.path.normcase(os.path.normpath(root))
    target_value = os.path.normcase(os.path.normpath(target))
    if root_value == target_value:
        return True
    return target_value.startswith(root_value + os.sep)


def _allows(grant: str, need: str) -> bool:
    if need == ACCESS_READ:
        return grant in (ACCESS_READ, ACCESS_READWRITE)
    if need == ACCESS_WRITE:
        return grant in (ACCESS_WRITE, ACCESS_READWRITE)
    if need == ACCESS_READWRITE:
        return grant == ACCESS_READWRITE
    return False
