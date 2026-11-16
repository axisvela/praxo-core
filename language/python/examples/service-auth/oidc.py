import base64
import hashlib
import hmac
import json
import time
import urllib.request
from threading import Lock

from identity import AuthError, Principal


HASH_ALGORITHMS = {
    "RS256": "sha256",
    "RS384": "sha384",
    "RS512": "sha512",
}

DER_PREFIXES = {
    "RS256": bytes.fromhex("3031300d060960864801650304020105000420"),
    "RS384": bytes.fromhex("3041300d060960864801650304020205000430"),
    "RS512": bytes.fromhex("3051300d060960864801650304020305000440"),
}


def decode_base64url(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    try:
        return base64.urlsafe_b64decode(value + padding)
    except (ValueError, TypeError) as error:
        raise AuthError("invalid token") from error


def decode_segment(value: str) -> dict:
    try:
        decoded = json.loads(decode_base64url(value).decode("utf-8"))
    except (ValueError, UnicodeDecodeError) as error:
        raise AuthError("invalid token") from error
    if not isinstance(decoded, dict):
        raise AuthError("invalid token")
    return decoded


def audience_matches(value, expected: str) -> bool:
    if isinstance(value, str):
        return value == expected
    if isinstance(value, list):
        return expected in value
    return False


def verify_rsa_signature(key: dict, algorithm: str, signing_input: bytes, signature: bytes) -> bool:
    try:
        modulus = int.from_bytes(decode_base64url(key["n"]), "big")
        exponent = int.from_bytes(decode_base64url(key["e"]), "big")
    except (KeyError, AuthError):
        return False
    size = (modulus.bit_length() + 7) // 8
    if len(signature) != size or exponent < 3:
        return False
    value = int.from_bytes(signature, "big")
    if value >= modulus:
        return False
    encoded = pow(value, exponent, modulus).to_bytes(size, "big")
    digest = hashlib.new(HASH_ALGORITHMS[algorithm], signing_input).digest()
    expected = DER_PREFIXES[algorithm] + digest
    padding = size - len(expected) - 3
    if padding < 8:
        return False
    encoded_message = b"\x00\x01" + b"\xff" * padding + b"\x00" + expected
    return hmac.compare_digest(encoded, encoded_message)


class ProviderDiscovery:
    def __init__(
        self,
        issuer: str = "",
        discovery_url: str = "",
        timeout: float = 2.0,
        cache_seconds: float = 300.0,
    ) -> None:
        self.issuer = issuer.rstrip("/")
        self.discovery_url = discovery_url
        self.timeout = timeout
        self.cache_seconds = cache_seconds
        self._metadata: dict | None = None
        self._fetched = 0.0
        self._lock = Lock()

    def metadata(self) -> dict:
        with self._lock:
            if (
                self._metadata is not None
                and time.time() - self._fetched <= self.cache_seconds
            ):
                return self._metadata
            url = self.discovery_url or (
                f"{self.issuer}/.well-known/openid-configuration"
            )
            if not self.discovery_url and not self.issuer:
                raise AuthError("provider discovery is not configured")
            try:
                with urllib.request.urlopen(url, timeout=self.timeout) as response:
                    if response.status != 200:
                        raise ValueError("metadata status")
                    body = json.loads(response.read())
            except Exception as error:
                raise AuthError("identity provider unavailable") from error
            if not isinstance(body, dict):
                raise AuthError("invalid provider metadata")
            issuer = body.get("issuer")
            if self.issuer and (
                not isinstance(issuer, str)
                or issuer.rstrip("/") != self.issuer
            ):
                raise AuthError("invalid provider issuer")
            self._metadata = body
            self._fetched = time.time()
            return body

    def jwks_uri(self) -> str:
        uri = self.metadata().get("jwks_uri")
        if not isinstance(uri, str) or not uri:
            raise AuthError("provider metadata is missing jwks_uri")
        return uri


class OidcVerifier:
    def __init__(
        self,
        issuer: str,
        audience: str,
        jwks_url: str = "",
        discovery_url: str = "",
        tenant_claim: str = "tenant",
        timeout: float = 2.0,
        cache_seconds: float = 300.0,
    ) -> None:
        self.issuer = issuer.rstrip("/")
        self.audience = audience
        self.jwks_url = jwks_url
        self.tenant_claim = tenant_claim
        self.timeout = timeout
        self.cache_seconds = cache_seconds
        self.discovery = (
            ProviderDiscovery(
                issuer=issuer,
                discovery_url=discovery_url,
                timeout=timeout,
                cache_seconds=cache_seconds,
            )
            if not jwks_url
            else None
        )
        self._keys: dict[str, dict] = {}
        self._fetched = 0.0
        self._lock = Lock()

    def verify(self, header: str, now: int | None = None) -> Principal:
        if not header.startswith("Bearer "):
            raise AuthError("missing bearer token")
        token = header.removeprefix("Bearer ")
        parts = token.split(".")
        if len(parts) != 3:
            raise AuthError("invalid token")
        token_header = decode_segment(parts[0])
        algorithm = token_header.get("alg")
        key_id = token_header.get("kid")
        if not isinstance(algorithm, str) or algorithm not in HASH_ALGORITHMS:
            raise AuthError("unsupported token algorithm")
        if not isinstance(key_id, str) or not key_id:
            raise AuthError("token is missing key id")
        claims = decode_segment(parts[1])
        if claims.get("iss") != self.issuer:
            raise AuthError("invalid token issuer")
        if not audience_matches(claims.get("aud"), self.audience):
            raise AuthError("invalid token audience")
        current = int(time.time()) if now is None else now
        expires = claims.get("exp")
        if (
            not isinstance(expires, int)
            or isinstance(expires, bool)
            or expires <= current
        ):
            raise AuthError("token is expired")
        not_before = claims.get("nbf")
        if not_before is not None and (
            not isinstance(not_before, int)
            or isinstance(not_before, bool)
            or not_before > current
        ):
            raise AuthError("token is not active")
        subject = claims.get("sub")
        tenant = claims.get(self.tenant_claim)
        if not isinstance(subject, str) or not subject:
            raise AuthError("token is missing subject")
        if not isinstance(tenant, str) or not tenant:
            raise AuthError("token is missing tenant")
        signature = decode_base64url(parts[2])
        key = self._key(key_id, algorithm, refresh=False)
        if key is None:
            key = self._key(key_id, algorithm, refresh=True)
        if key is None:
            raise AuthError("unknown token key")
        signing_input = f"{parts[0]}.{parts[1]}".encode("ascii")
        if not verify_rsa_signature(key, algorithm, signing_input, signature):
            raise AuthError("invalid token signature")
        return Principal(subject, tenant, expires)

    def _key(self, key_id: str, algorithm: str, refresh: bool) -> dict | None:
        with self._lock:
            if (
                refresh
                or not self._keys
                or time.time() - self._fetched > self.cache_seconds
            ):
                self._keys = self._fetch_keys()
                self._fetched = time.time()
            key = self._keys.get(key_id)
            if not isinstance(key, dict):
                return None
            if key.get("kty") != "RSA":
                return None
            use = key.get("use")
            if use not in (None, "", "sig"):
                return None
            algorithm_value = key.get("alg")
            if algorithm_value not in (None, "", algorithm):
                return None
            return key

    def _fetch_keys(self) -> dict[str, dict]:
        url = self.jwks_url
        if not url:
            if self.discovery is None:
                raise AuthError("identity provider JWKS is not configured")
            url = self.discovery.jwks_uri()
        try:
            with urllib.request.urlopen(url, timeout=self.timeout) as response:
                if response.status != 200:
                    raise ValueError("jwks status")
                body = json.loads(response.read())
        except Exception as error:
            if isinstance(error, AuthError):
                raise
            raise AuthError("identity provider unavailable") from error
        if not isinstance(body, dict) or not isinstance(body.get("keys"), list):
            raise AuthError("invalid JWKS")
        keys = {}
        for key in body["keys"]:
            if isinstance(key, dict) and isinstance(key.get("kid"), str):
                keys[key["kid"]] = key
        return keys
