use std::cell::{Cell, RefCell};
use std::collections::HashMap;

use base64::Engine;
use ring::signature::{
    UnparsedPublicKey, VerificationAlgorithm, RSA_PKCS1_2048_8192_SHA256,
    RSA_PKCS1_2048_8192_SHA384, RSA_PKCS1_2048_8192_SHA512,
};
use serde_json::Value;

use crate::authentication::{AuthError, Principal, Transport};

#[derive(Debug, Clone)]
struct JwkKey {
    kind: String,
    use_: String,
    algorithm: String,
    modulus: String,
    exponent: String,
}

pub struct OidcAuthenticator<'a> {
    transport: &'a dyn Transport,
    issuer: String,
    audience: String,
    jwks_url: String,
    discovery_url: String,
    tenant_claim: String,
    keys: RefCell<Option<HashMap<String, JwkKey>>>,
    keys_at: Cell<i64>,
    metadata: RefCell<Option<Value>>,
    metadata_at: Cell<i64>,
}

impl<'a> OidcAuthenticator<'a> {
    pub fn new(
        transport: &'a dyn Transport,
        issuer: impl Into<String>,
        audience: impl Into<String>,
        jwks_url: impl Into<String>,
        discovery_url: impl Into<String>,
        tenant_claim: impl Into<String>,
    ) -> Result<Self, AuthError> {
        let issuer = issuer.into().trim_end_matches('/').to_string();
        let audience = audience.into();
        if issuer.is_empty() {
            return Err(AuthError::new("issuer is required"));
        }
        if audience.is_empty() {
            return Err(AuthError::new("audience is required"));
        }
        let tenant_claim = tenant_claim.into();
        Ok(Self {
            transport,
            issuer,
            audience,
            jwks_url: jwks_url.into(),
            discovery_url: discovery_url.into(),
            tenant_claim: if tenant_claim.is_empty() {
                "tenant".to_string()
            } else {
                tenant_claim
            },
            keys: RefCell::new(None),
            keys_at: Cell::new(0),
            metadata: RefCell::new(None),
            metadata_at: Cell::new(0),
        })
    }

    pub fn authenticate(&self, authorization: Option<&str>, now: i64) -> Option<Principal> {
        let authorization = authorization?;
        let token = authorization.strip_prefix("Bearer ")?.trim();
        let parts: Vec<&str> = token.split('.').collect();
        if parts.len() != 3 {
            return None;
        }
        let header: Value = serde_json::from_slice(&base64_decode(parts[0]).ok()?).ok()?;
        let claims: Value = serde_json::from_slice(&base64_decode(parts[1]).ok()?).ok()?;
        let algorithm = header.get("alg")?.as_str()?;
        let kid = header.get("kid")?.as_str()?;
        let signature_algorithm = algorithm_for(algorithm)?;
        let token_issuer = claims.get("iss")?.as_str()?;
        if token_issuer.trim_end_matches('/') != self.issuer {
            return None;
        }
        if !audience_matches(claims.get("aud"), &self.audience) {
            return None;
        }
        let expires = claims.get("exp")?.as_i64()?;
        if expires <= now {
            return None;
        }
        if claims
            .get("nbf")
            .and_then(Value::as_i64)
            .is_some_and(|not_before| not_before > now)
        {
            return None;
        }
        let subject = claims.get("sub")?.as_str()?;
        let tenant = claims.get(self.tenant_claim.as_str())?.as_str()?;
        if subject.is_empty() || tenant.is_empty() {
            return None;
        }
        let key = self
            .find_key(kid, algorithm, false)
            .or_else(|| self.find_key(kid, algorithm, true))?;
        let signature = base64_decode(parts[2]).ok()?;
        let der = rsa_der(&key).ok()?;
        UnparsedPublicKey::new(signature_algorithm, &der)
            .verify(format!("{}.{}", parts[0], parts[1]).as_bytes(), &signature)
            .ok()?;
        Some(Principal {
            subject: subject.to_string(),
            tenant: tenant.to_string(),
            expires: Some(expires),
        })
    }

    fn find_key(&self, kid: &str, algorithm: &str, refresh: bool) -> Option<JwkKey> {
        let now = current_seconds();
        if refresh || now - self.keys_at.get() > 300 || self.keys.borrow().is_none() {
            let mut url = self.jwks_url.clone();
            if url.is_empty() {
                url = self.metadata()?.get("jwks_uri")?.as_str()?.to_string();
            }
            let body = self.fetch_json(&url).ok()?;
            let items = body.get("keys")?.as_array()?;
            let mut keys = HashMap::new();
            for item in items {
                let Some(object) = item.as_object() else {
                    continue;
                };
                let Some(kid) = object.get("kid").and_then(Value::as_str) else {
                    continue;
                };
                let Some(kind) = object.get("kty").and_then(Value::as_str) else {
                    continue;
                };
                let Some(modulus) = object.get("n").and_then(Value::as_str) else {
                    continue;
                };
                let Some(exponent) = object.get("e").and_then(Value::as_str) else {
                    continue;
                };
                keys.insert(
                    kid.to_string(),
                    JwkKey {
                        kind: kind.to_string(),
                        use_: object
                            .get("use")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string(),
                        algorithm: object
                            .get("alg")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string(),
                        modulus: modulus.to_string(),
                        exponent: exponent.to_string(),
                    },
                );
            }
            *self.keys.borrow_mut() = Some(keys);
            self.keys_at.set(now);
        }
        let keys = self.keys.borrow();
        let key = keys.as_ref()?.get(kid)?;
        if key.kind != "RSA"
            || (!key.use_.is_empty() && key.use_ != "sig")
            || (!key.algorithm.is_empty() && key.algorithm != algorithm)
        {
            return None;
        }
        Some(key.clone())
    }

    fn metadata(&self) -> Option<Value> {
        let now = current_seconds();
        if let Some(value) = self.metadata.borrow().as_ref() {
            if now - self.metadata_at.get() <= 300 {
                return Some(value.clone());
            }
        }
        let url = if self.discovery_url.is_empty() {
            format!("{}/.well-known/openid-configuration", self.issuer)
        } else {
            self.discovery_url.clone()
        };
        let body = self.fetch_json(&url).ok()?;
        let issuer = body.get("issuer")?.as_str()?;
        if issuer.trim_end_matches('/') != self.issuer {
            return None;
        }
        *self.metadata.borrow_mut() = Some(body.clone());
        self.metadata_at.set(now);
        Some(body)
    }

    fn fetch_json(&self, url: &str) -> Result<Value, AuthError> {
        let (status, body) = self.transport.get_json(url)?;
        if status != 200 {
            return Err(AuthError::new("identity provider unavailable"));
        }
        serde_json::from_str(&body).map_err(|_| AuthError::new("invalid provider response"))
    }
}

fn algorithm_for(name: &str) -> Option<&'static dyn VerificationAlgorithm> {
    match name {
        "RS256" => Some(&RSA_PKCS1_2048_8192_SHA256),
        "RS384" => Some(&RSA_PKCS1_2048_8192_SHA384),
        "RS512" => Some(&RSA_PKCS1_2048_8192_SHA512),
        _ => None,
    }
}

fn audience_matches(value: Option<&Value>, expected: &str) -> bool {
    match value {
        Some(Value::String(audience)) => audience == expected,
        Some(Value::Array(audiences)) => {
            audiences.iter().any(|item| item.as_str() == Some(expected))
        }
        _ => false,
    }
}

fn current_seconds() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or(0)
}

fn base64_decode(value: &str) -> Result<Vec<u8>, AuthError> {
    base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(value)
        .map_err(|_| AuthError::new("invalid token encoding"))
}

fn rsa_der(key: &JwkKey) -> Result<Vec<u8>, AuthError> {
    let modulus = base64_decode(&key.modulus)?;
    let exponent = base64_decode(&key.exponent)?;
    let mut body = der_integer(&modulus);
    body.extend(der_integer(&exponent));
    Ok(der_sequence(&body))
}

fn der_integer(value: &[u8]) -> Vec<u8> {
    let mut bytes = value;
    while bytes.first() == Some(&0) && bytes.len() > 1 {
        bytes = &bytes[1..];
    }
    let mut body = Vec::new();
    if bytes.first().map(|byte| byte & 0x80 != 0).unwrap_or(true) {
        body.push(0);
    }
    body.extend_from_slice(bytes);
    let mut out = vec![0x02];
    out.extend(der_length(body.len()));
    out.extend(body);
    out
}

fn der_sequence(value: &[u8]) -> Vec<u8> {
    let mut out = vec![0x30];
    out.extend(der_length(value.len()));
    out.extend_from_slice(value);
    out
}

fn der_length(length: usize) -> Vec<u8> {
    if length < 128 {
        return vec![length as u8];
    }
    let mut value = length;
    let mut bytes = Vec::new();
    while value > 0 {
        bytes.insert(0, (value & 0xff) as u8);
        value >>= 8;
    }
    let mut out = vec![0x80 | bytes.len() as u8];
    out.extend(bytes);
    out
}

#[cfg(test)]
mod tests {
    use std::cell::RefCell;
    use std::collections::HashMap;

    use super::*;

    struct ScriptedTransport {
        routes: RefCell<HashMap<String, (u16, String)>>,
    }

    impl ScriptedTransport {
        fn new(routes: &[(&str, &str)]) -> Self {
            let mut values = HashMap::new();
            for (url, body) in routes {
                values.insert(url.to_string(), (200, (*body).to_string()));
            }
            Self {
                routes: RefCell::new(values),
            }
        }

        fn unavailable() -> Self {
            Self::new(&[])
        }
    }

    impl Transport for ScriptedTransport {
        fn get_json(&self, url: &str) -> Result<(u16, String), AuthError> {
            self.routes
                .borrow()
                .get(url)
                .cloned()
                .ok_or_else(|| AuthError::new("identity provider unavailable"))
        }

        fn post_form(
            &self,
            _url: &str,
            _form: &[(&str, &str)],
            _authorization: Option<&str>,
        ) -> Result<(u16, String), AuthError> {
            Err(AuthError::new("not used"))
        }
    }

    const ISSUER: &str = "https://issuer.example.com";
    const DISCOVERY: &str = "https://issuer.example.com/.well-known/openid-configuration";
    const JWKS: &str = "https://issuer.example.com/jwks";
    const MODULUS: &str = "qWFElz2hCqBme8dCaZWbNaozJ01XQBacFGb0TfRR_I0k5-l0G06HwUL0tdtb6embo6QPJoWL6itik4jxkYtnFv7NowJSUVd7a84xJG4pBRYT3dgBtuBJcCfUKawYYJ0LniiSyWUErhM-9Z5jTkTT3fQ3trB73eUSIJMK4M-3oWecJ99Tb8I4jMMHYCft4rcZ8RVmavBu_GkQjqUIqS_Qmbqdj1d2j_DScWf3AiH4I-A4FpyFzvwkrog2s9RzAiFarQ7PN59nFR8xkE63EsNM3bTsXbMSuRc22ZByASQVQr3cNXqf3DF0i9Ok1XNrXvbNwyECz1BXmV8OAnrhEsOquQ";
    const ALLOWED: &str = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5IiwidHlwIjoiSldUIn0.eyJhdWQiOiJwcmF4by1zZXJ2aWNlIiwiZXhwIjoxNzAwMDAwMDYwLCJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInN1YiI6InVzZXItMSIsInRlbmFudCI6ImxvY2FsIn0.oHGVuKZGT2E8LPfPkXBIEbHGJQw4kjJ76YfgJHRgrz7GCqVtGwhAPho5sZ5pjxlUdvePLNt50ZlgBZ0qXo3VxgepG-hukZhRCOcx-0UyFHh96fEWXD6g7M3H52WtXFB58V3C6pQAxrCha7KrvRlWC62b4G57cpOeelCbx8KnQ35BXmp5cFUHhE8Qwk7tgir2aX2nHD17e2z8dx7JA5FXyguzmQoYZjCYfZZKwc9hapNBpL7HsDUUnN9XQ5RaIj2G6i2gyw8H0NVGyTejzCO50axYUkyulOedLG2WszHDnJmeTqkzNm4gU5K55cvCwTfIGpeaZ8wdp6evp6a0Kxmupg";
    const WRONG_AUDIENCE: &str = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5IiwidHlwIjoiSldUIn0.eyJhdWQiOiJvdGhlci1zZXJ2aWNlIiwiZXhwIjoxNzAwMDAwMDYwLCJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInN1YiI6InVzZXItMSIsInRlbmFudCI6ImxvY2FsIn0.RjdHNC9xtx0LhwD_YOfsdmLgs0zFqAe27FEH2iNlAuZP814Ek-okFsNeyOeSzji5A2UbeEQs0HaSw70zL94YqRMQ3eDVMItVhytH2pPrVRTrWHgsQ7TWzqaLa_VYXXWCQXQasYIkTJJGEbJG_RTk6pRMNfFO-U1UwMiq5jJ6q4dTQeXORFY7lRDLx_J1D809f2MSsL_I3XUsxYwxFw-_k7sluyYhKQezz9lTbxEq0VyWQsI2GDSvlzngZDkIizMWgfNpwDF0-V-I4IFcCASAt9H6ZKRkkx2eLAkwRXcnam_0SfcfBIuiam6ksxBGg2DA7ZhM7jLrDIGo82hH1XX51Q";
    const EXPIRED: &str = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5IiwidHlwIjoiSldUIn0.eyJhdWQiOiJwcmF4by1zZXJ2aWNlIiwiZXhwIjoxNjk5OTk5OTQwLCJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInN1YiI6InVzZXItMSIsInRlbmFudCI6ImxvY2FsIn0.GLJfAOrSRbyYZthVZY66dNECjjTgmeUvjYfF2Zd-XLH0MNMWEIox8mNW9NVAVpTW9cGhbDVpaM0Q6Tt6luZh4qDTh5ybh6wDrMlVnR5P9M9VNshB2mFgzZKmhRaIFAY9diTwag76_0NmJUW-PnXhi6hZ4j3LKrWKkc4UwBFRb7P00GE7llOFLp5NTq4GZ4Im4vhe1vW__Q2e7TFbWlUiHlEmkFmji3gkEDAnkRs8JZ88fbDcPepgvywL1dz4yyHRM5HkjC3PoyeGbnRDjWvgQsMly9PdHZhlQdobjSnWCwyXZL8YCBCbnHAPny0CSc-PkFiT8nR4sLySwLGPFyVFew";
    const WRONG_ISSUER: &str = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5IiwidHlwIjoiSldUIn0.eyJhdWQiOiJwcmF4by1zZXJ2aWNlIiwiZXhwIjoxNzAwMDAwMDYwLCJpc3MiOiJodHRwczovL3dyb25nLmV4YW1wbGUuY29tIiwic3ViIjoidXNlci0xIiwidGVuYW50IjoibG9jYWwifQ.g-2fZg5x5bm3YTN1AF_URyzTacGwbeisCo2wiXUoCEi1xPLiwjzKPzOGXEkGGKd-YsLDJJsIkyjlP6bzNScK4T_qvhnhaC-wB4liOCAQdgH066a_3Sj9qyemZL7Fx8E7Uiifc-9aNWYD6ISRNSPQdQrdkFM0VMw7G-G7iaMb77ikfuwziCOB_HxiY-Ea1FAhlA46Nr19aMHPW7c_04-lfxuogZueO1PWBulbDiMKrvy_OplL7JfUv5J1HMU2cQDsTM2cNsIVowqC9IM-x6C4UuT__7OvQJQuoEmdwjw5L4h0Veq5XPtc43MJY42zqgLXHpnnGAuNXqYNw6ecGjguMw";
    const UNKNOWN_KEY: &str = "eyJhbGciOiJSUzI1NiIsImtpZCI6Im90aGVyLWtleSIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJwcmF4by1zZXJ2aWNlIiwiZXhwIjoxNzAwMDAwMDYwLCJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInN1YiI6InVzZXItMSIsInRlbmFudCI6ImxvY2FsIn0.hMhJFIlioC4nX0uOUYbXnns66gki5QbAzl9c2NJTVkogVxURrKC1DddTjwSuWzydqh1zwvJ6J48auqw4aKwvf6_eC2hSntbI9w68gTxcNlXS81AER7LhLl6r2JdnXru_kR2Qd-0TwhwlrIFWaKuYZEhfbLv6XIQcZ2-Xzd4vFXhbhC6iciXGSN6xw4l5oWh2fww0qF8qQZur6gJMkC5u3OxvZIoQlWjAMzib4P_EcjlJFGTX7iDhNdZsL2yJ6J6QKM8tFs7RniQK_kz1DJJwL__XboJ36KKTN7Jq5GUmS4oXzBd2qz4gU0NStNbPcsWH2BxG--8zc8U0noI7P8q69A";

    fn provider() -> ScriptedTransport {
        let metadata = format!(r#"{{"issuer":"{ISSUER}","jwks_uri":"{JWKS}"}}"#);
        let jwks = format!(
            r#"{{"keys":[{{"kid":"test-key","kty":"RSA","use":"sig","alg":"RS256","n":"{MODULUS}","e":"AQAB"}}]}}"#
        );
        ScriptedTransport::new(&[(DISCOVERY, &metadata), (JWKS, &jwks)])
    }

    #[test]
    fn oidc_discovery_and_jwks_reject_invalid_tokens() {
        let transport = provider();
        let auth = OidcAuthenticator::new(&transport, ISSUER, "praxo-service", "", "", "tenant")
            .expect("auth");
        let now = 1_700_000_000;
        let principal = auth
            .authenticate(Some(&format!("Bearer {ALLOWED}")), now)
            .expect("allowed");
        assert_eq!(principal.subject, "user-1");
        assert_eq!(principal.tenant, "local");
        assert!(auth
            .authenticate(Some(&format!("Bearer {WRONG_AUDIENCE}")), now)
            .is_none());
        assert!(auth
            .authenticate(Some(&format!("Bearer {EXPIRED}")), now)
            .is_none());
        assert!(auth
            .authenticate(Some(&format!("Bearer {WRONG_ISSUER}")), now)
            .is_none());
        assert!(auth
            .authenticate(Some(&format!("Bearer {UNKNOWN_KEY}")), now)
            .is_none());
        assert!(auth.authenticate(None, now).is_none());
        assert!(auth.authenticate(Some("Basic x"), now).is_none());
    }

    #[test]
    fn oidc_provider_unavailable_fails_closed() {
        let transport = ScriptedTransport::unavailable();
        let auth = OidcAuthenticator::new(&transport, ISSUER, "praxo-service", "", "", "tenant")
            .expect("auth");
        assert!(auth
            .authenticate(Some(&format!("Bearer {ALLOWED}")), 1_700_000_000)
            .is_none());
    }
}
