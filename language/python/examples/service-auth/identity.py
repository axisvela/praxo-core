from dataclasses import dataclass


class AuthError(Exception):
    pass


@dataclass(frozen=True)
class Principal:
    subject: str
    tenant: str
    expires: int

    @property
    def session_id(self) -> str:
        return f"{self.tenant}/{self.subject}"


class PrincipalStore:
    def __init__(self) -> None:
        self._principals: dict[str, Principal] = {}

    def bind(self, principal: Principal) -> None:
        self._principals[principal.session_id] = principal

    def lookup(self, session_id: str) -> Principal | None:
        return self._principals.get(session_id)
