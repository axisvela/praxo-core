use std::error::Error;
use std::fmt;

use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Principal {
    pub subject: String,
    pub tenant: String,
    pub expires: Option<i64>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthError {
    message: String,
}

impl AuthError {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }

    pub fn message(&self) -> &str {
        &self.message
    }
}

impl fmt::Display for AuthError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.message)
    }
}

impl Error for AuthError {}

pub trait Transport {
    fn get_json(&self, url: &str) -> Result<(u16, String), AuthError>;

    fn post_form(
        &self,
        url: &str,
        form: &[(&str, &str)],
        authorization: Option<&str>,
    ) -> Result<(u16, String), AuthError>;
}

pub struct ContextAuthenticator {
    tenant: String,
}

impl ContextAuthenticator {
    pub fn new(tenant: impl Into<String>) -> Self {
        Self {
            tenant: tenant.into(),
        }
    }

    pub fn authenticate(&self, principal: Option<&str>) -> Option<Principal> {
        let subject = principal.filter(|value| !value.is_empty())?;
        Some(Principal {
            subject: subject.to_string(),
            tenant: self.tenant.clone(),
            expires: None,
        })
    }
}

pub struct IntrospectionAuthenticator<'a> {
    transport: &'a dyn Transport,
    endpoint: String,
    client_id: String,
    client_secret: String,
    tenant_claim: String,
}

impl<'a> IntrospectionAuthenticator<'a> {
    pub fn new(
        transport: &'a dyn Transport,
        endpoint: impl Into<String>,
        client_id: impl Into<String>,
        client_secret: impl Into<String>,
    ) -> Self {
        Self {
            transport,
            endpoint: endpoint.into(),
            client_id: client_id.into(),
            client_secret: client_secret.into(),
            tenant_claim: "tenant".to_string(),
        }
    }

    pub fn with_tenant_claim(mut self, tenant_claim: impl Into<String>) -> Self {
        let claim = tenant_claim.into();
        self.tenant_claim = if claim.is_empty() {
            "tenant".to_string()
        } else {
            claim
        };
        self
    }

    pub fn authenticate(&self, authorization: Option<&str>, now: i64) -> Option<Principal> {
        let authorization = authorization?;
        let token = authorization.strip_prefix("Bearer ")?.trim();
        if token.is_empty() {
            return None;
        }
        let form = [
            ("token", token),
            ("client_id", self.client_id.as_str()),
            ("client_secret", self.client_secret.as_str()),
        ];
        let basic = self.basic_auth();
        let (status, body) = self
            .transport
            .post_form(&self.endpoint, &form, basic.as_deref())
            .ok()?;
        if status != 200 {
            return None;
        }
        let payload: Value = serde_json::from_str(&body).ok()?;
        if !payload.is_object() {
            return None;
        }
        if payload.get("active").and_then(Value::as_bool) != Some(true) {
            return None;
        }
        let subject = payload.get("sub").and_then(Value::as_str)?;
        if subject.is_empty() {
            return None;
        }
        let tenant = payload
            .get(self.tenant_claim.as_str())
            .and_then(Value::as_str)?;
        if tenant.is_empty() {
            return None;
        }
        let expires = payload.get("exp").and_then(Value::as_i64)?;
        if expires <= now {
            return None;
        }
        Some(Principal {
            subject: subject.to_string(),
            tenant: tenant.to_string(),
            expires: Some(expires),
        })
    }

    fn basic_auth(&self) -> Option<String> {
        if self.client_id.is_empty() {
            return None;
        }
        let raw = format!("{}:{}", self.client_id, self.client_secret);
        Some(format!("Basic {}", base64_encode(raw.as_bytes())))
    }
}

pub struct RevocationClient<'a> {
    transport: &'a dyn Transport,
    endpoint: String,
    client_id: String,
    client_secret: String,
}

impl<'a> RevocationClient<'a> {
    pub fn new(
        transport: &'a dyn Transport,
        endpoint: impl Into<String>,
        client_id: impl Into<String>,
        client_secret: impl Into<String>,
    ) -> Self {
        Self {
            transport,
            endpoint: endpoint.into(),
            client_id: client_id.into(),
            client_secret: client_secret.into(),
        }
    }

    pub fn revoke(&self, token: &str) -> Result<(), AuthError> {
        if token.is_empty() {
            return Err(AuthError::new("revocation token is required"));
        }
        let form = [
            ("token", token),
            ("token_type_hint", "access_token"),
            ("client_id", self.client_id.as_str()),
            ("client_secret", self.client_secret.as_str()),
        ];
        let basic = self.basic_auth();
        let result = self
            .transport
            .post_form(&self.endpoint, &form, basic.as_deref());
        match result {
            Ok((200, _body)) => Ok(()),
            _ => Err(AuthError::new("token revocation failed")),
        }
    }

    fn basic_auth(&self) -> Option<String> {
        if self.client_id.is_empty() {
            return None;
        }
        let raw = format!("{}:{}", self.client_id, self.client_secret);
        Some(format!("Basic {}", base64_encode(raw.as_bytes())))
    }
}

fn base64_encode(input: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut output = String::new();
    for chunk in input.chunks(3) {
        let first = chunk[0] as u32;
        let second = chunk.get(1).copied().unwrap_or(0) as u32;
        let third = chunk.get(2).copied().unwrap_or(0) as u32;
        let triple = (first << 16) | (second << 8) | third;
        output.push(ALPHABET[((triple >> 18) & 0x3f) as usize] as char);
        output.push(ALPHABET[((triple >> 12) & 0x3f) as usize] as char);
        if chunk.len() > 1 {
            output.push(ALPHABET[((triple >> 6) & 0x3f) as usize] as char);
        } else {
            output.push('=');
        }
        if chunk.len() > 2 {
            output.push(ALPHABET[(triple & 0x3f) as usize] as char);
        } else {
            output.push('=');
        }
    }
    output
}

#[cfg(test)]
mod tests {
    use std::cell::RefCell;

    use super::*;

    #[derive(Debug, Clone)]
    struct Call {
        url: String,
        form: Vec<(String, String)>,
        authorization: Option<String>,
    }

    struct ScriptedTransport {
        response: Result<(u16, String), AuthError>,
        calls: RefCell<Vec<Call>>,
    }

    impl ScriptedTransport {
        fn ok(status: u16, body: impl Into<String>) -> Self {
            Self {
                response: Ok((status, body.into())),
                calls: RefCell::new(Vec::new()),
            }
        }

        fn error() -> Self {
            Self {
                response: Err(AuthError::new("unavailable")),
                calls: RefCell::new(Vec::new()),
            }
        }

        fn calls(&self) -> Vec<Call> {
            self.calls.borrow().clone()
        }
    }

    impl Transport for ScriptedTransport {
        fn get_json(&self, _url: &str) -> Result<(u16, String), AuthError> {
            Err(AuthError::new("not used"))
        }

        fn post_form(
            &self,
            url: &str,
            form: &[(&str, &str)],
            authorization: Option<&str>,
        ) -> Result<(u16, String), AuthError> {
            self.calls.borrow_mut().push(Call {
                url: url.to_string(),
                form: form
                    .iter()
                    .map(|(key, value)| (key.to_string(), value.to_string()))
                    .collect(),
                authorization: authorization.map(str::to_string),
            });
            self.response.clone()
        }
    }

    fn active_body(now: i64) -> String {
        format!(
            r#"{{"active":true,"sub":"user-1","tenant":"tenant-a","exp":{}}}"#,
            now + 60
        )
    }

    fn form_value<'a>(call: &'a Call, key: &str) -> Option<&'a str> {
        call.form
            .iter()
            .find(|(name, _)| name == key)
            .map(|(_, value)| value.as_str())
    }

    #[test]
    fn authentication_contract() {
        let now = 1_700_000_000;

        let context = ContextAuthenticator::new("tenant-a");
        let principal = context.authenticate(Some("user-1")).expect("context");
        assert_eq!(principal.subject, "user-1");
        assert_eq!(principal.tenant, "tenant-a");
        assert_eq!(principal.expires, None);
        assert!(context.authenticate(None).is_none());
        assert!(context.authenticate(Some("")).is_none());

        let success = ScriptedTransport::ok(200, active_body(now));
        let auth = IntrospectionAuthenticator::new(
            &success,
            "https://idp.example/introspect",
            "svc",
            "secret",
        );
        let principal = auth
            .authenticate(Some("Bearer token-1"), now)
            .expect("success");
        assert_eq!(principal.subject, "user-1");
        assert_eq!(principal.tenant, "tenant-a");
        assert_eq!(principal.expires, Some(now + 60));
        let calls = success.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].url, "https://idp.example/introspect");
        assert_eq!(form_value(&calls[0], "token"), Some("token-1"));
        assert_eq!(form_value(&calls[0], "client_id"), Some("svc"));
        assert_eq!(form_value(&calls[0], "client_secret"), Some("secret"));
        assert_eq!(
            calls[0].authorization.as_deref(),
            Some("Basic c3ZjOnNlY3JldA==")
        );

        let local = ScriptedTransport::ok(200, active_body(now));
        let local_auth =
            IntrospectionAuthenticator::new(&local, "https://idp.example", "svc", "secret");
        assert!(local_auth.authenticate(None, now).is_none());
        assert!(local_auth.authenticate(Some("Basic token"), now).is_none());
        assert!(local_auth.authenticate(Some("Bearer   "), now).is_none());
        assert!(local.calls().is_empty());

        let rejected = [
            r#"{"active":false,"sub":"user-1","tenant":"tenant-a","exp":1700000060}"#.to_string(),
            r#"{"active":true,"sub":"","tenant":"tenant-a","exp":1700000060}"#.to_string(),
            r#"{"active":true,"tenant":"tenant-a","exp":1700000060}"#.to_string(),
            r#"{"active":true,"sub":"user-1","tenant":"","exp":1700000060}"#.to_string(),
            r#"{"active":true,"sub":"user-1","exp":1700000060}"#.to_string(),
            r#"{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000000}"#.to_string(),
            r#"{"active":true,"sub":"user-1","tenant":"tenant-a"}"#.to_string(),
            "not-json".to_string(),
            "[]".to_string(),
        ];
        for body in rejected {
            let transport = ScriptedTransport::ok(200, body);
            let auth = IntrospectionAuthenticator::new(&transport, "https://idp.example", "", "");
            assert!(auth.authenticate(Some("Bearer token-1"), now).is_none());
        }

        let failure = ScriptedTransport::ok(500, active_body(now));
        let failure_auth = IntrospectionAuthenticator::new(&failure, "https://idp.example", "", "");
        assert!(failure_auth
            .authenticate(Some("Bearer token-1"), now)
            .is_none());

        let transport_error = ScriptedTransport::error();
        let error_auth =
            IntrospectionAuthenticator::new(&transport_error, "https://idp.example", "", "");
        assert!(error_auth
            .authenticate(Some("Bearer token-1"), now)
            .is_none());

        let custom = ScriptedTransport::ok(
            200,
            format!(
                r#"{{"active":true,"sub":"user-1","org":"org-a","exp":{}}}"#,
                now + 60
            ),
        );
        let custom_auth = IntrospectionAuthenticator::new(&custom, "https://idp.example", "", "")
            .with_tenant_claim("org");
        let principal = custom_auth
            .authenticate(Some("Bearer token-1"), now)
            .expect("custom tenant");
        assert_eq!(principal.tenant, "org-a");

        let revocation = ScriptedTransport::ok(200, "");
        let client =
            RevocationClient::new(&revocation, "https://idp.example/revoke", "svc", "secret");
        assert!(client.revoke("token-1").is_ok());
        let calls = revocation.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(form_value(&calls[0], "token"), Some("token-1"));
        assert_eq!(
            form_value(&calls[0], "token_type_hint"),
            Some("access_token")
        );
        assert_eq!(
            calls[0].authorization.as_deref(),
            Some("Basic c3ZjOnNlY3JldA==")
        );

        let rejected_revocation = ScriptedTransport::ok(400, "");
        let rejected_client =
            RevocationClient::new(&rejected_revocation, "https://idp.example/revoke", "", "");
        let error = rejected_client.revoke("token-1").unwrap_err();
        assert_eq!(error.message(), "token revocation failed");

        let revocation_error = ScriptedTransport::error();
        let error_client =
            RevocationClient::new(&revocation_error, "https://idp.example/revoke", "", "");
        let error = error_client.revoke("token-1").unwrap_err();
        assert_eq!(error.message(), "token revocation failed");

        let empty = ScriptedTransport::ok(200, "");
        let empty_client = RevocationClient::new(&empty, "https://idp.example/revoke", "", "");
        let error = empty_client.revoke("").unwrap_err();
        assert_eq!(error.message(), "revocation token is required");
        assert!(empty.calls().is_empty());
    }
}
