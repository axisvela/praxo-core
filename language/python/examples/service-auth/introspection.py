import base64
import json
import time
import urllib.error
import urllib.parse
import urllib.request

from identity import AuthError, Principal
from oidc import ProviderDiscovery


def bearer_token(header: str) -> str:
    if not header.startswith("Bearer "):
        raise AuthError("missing bearer token")
    token = header.removeprefix("Bearer ")
    if not token:
        raise AuthError("missing bearer token")
    return token


def auth_headers(client_id: str, client_secret: str) -> dict[str, str]:
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    if client_id:
        raw = f"{client_id}:{client_secret}".encode("utf-8")
        headers["Authorization"] = (
            "Basic " + base64.b64encode(raw).decode("ascii")
        )
    return headers


def post_form(
    url: str,
    form: dict[str, str],
    headers: dict[str, str],
    timeout: float,
) -> tuple[int, bytes]:
    request = urllib.request.Request(
        url,
        data=urllib.parse.urlencode(form).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        try:
            return error.code, error.read()
        finally:
            error.close()
    except Exception as error:
        raise AuthError("identity provider unavailable") from error


class IntrospectionVerifier:
    def __init__(
        self,
        url: str = "",
        issuer: str = "",
        discovery_url: str = "",
        client_id: str = "",
        client_secret: str = "",
        tenant_claim: str = "tenant",
        timeout: float = 2.0,
    ) -> None:
        self.url = url
        self.client_id = client_id
        self.client_secret = client_secret
        self.tenant_claim = tenant_claim
        self.timeout = timeout
        self.discovery = (
            ProviderDiscovery(
                issuer=issuer,
                discovery_url=discovery_url,
                timeout=timeout,
            )
            if issuer and not url
            else None
        )

    def endpoint(self) -> str:
        if self.url:
            return self.url
        if self.discovery is not None:
            return self.discovery.metadata().get("introspection_endpoint", "")
        raise AuthError("introspection endpoint is not configured")

    def verify(self, header: str, now: int | None = None) -> Principal:
        token = bearer_token(header)
        endpoint = self.endpoint()
        if not endpoint:
            raise AuthError(
                "provider metadata is missing introspection_endpoint"
            )
        form = {"token": token}
        if not self.client_id:
            form["client_id"] = self.client_id
            form["client_secret"] = self.client_secret
        status, raw = post_form(
            endpoint,
            form,
            auth_headers(self.client_id, self.client_secret),
            self.timeout,
        )
        if status != 200:
            raise AuthError("identity provider unavailable")
        try:
            body = json.loads(raw)
        except (ValueError, UnicodeDecodeError) as error:
            raise AuthError("invalid introspection response") from error
        if not isinstance(body, dict):
            raise AuthError("invalid introspection response")
        if body.get("active") is not True:
            raise AuthError("token is not active")
        subject = body.get("sub")
        tenant = body.get(self.tenant_claim)
        expires = body.get("exp")
        if not isinstance(subject, str) or not subject:
            raise AuthError("token is missing subject")
        if not isinstance(tenant, str) or not tenant:
            raise AuthError("token is missing tenant")
        if not isinstance(expires, int) or isinstance(expires, bool):
            raise AuthError("token is missing expiration")
        current = int(time.time()) if now is None else now
        if expires <= current:
            raise AuthError("token is expired")
        return Principal(subject, tenant, expires)


def revoke_token(
    token: str,
    url: str = "",
    issuer: str = "",
    discovery_url: str = "",
    client_id: str = "",
    client_secret: str = "",
    timeout: float = 2.0,
    token_type_hint: str = "access_token",
) -> bool:
    if not token:
        raise AuthError("revocation token is required")
    endpoint = url
    if not endpoint and issuer:
        endpoint = (
            ProviderDiscovery(
                issuer=issuer,
                discovery_url=discovery_url,
                timeout=timeout,
            )
            .metadata()
            .get("revocation_endpoint", "")
        )
    if not endpoint:
        raise AuthError("revocation endpoint is not configured")
    form = {"token": token, "token_type_hint": token_type_hint}
    if not client_id:
        form["client_id"] = client_id
        form["client_secret"] = client_secret
    status, _ = post_form(
        endpoint,
        form,
        auth_headers(client_id, client_secret),
        timeout,
    )
    if status != 200:
        raise AuthError("token revocation failed")
    return True
