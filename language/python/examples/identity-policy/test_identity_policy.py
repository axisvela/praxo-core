import unittest

from identity_policy import Principal, run_case


def error_code(error: Exception | None) -> str:
    return getattr(error, "code", "") if error is not None else ""


class IdentityPolicyTests(unittest.TestCase):
    def test_missing_principal_is_denied(self):
        calls, error = run_case(None)
        self.assertEqual(calls, 0)
        self.assertEqual(error_code(error), "AGENT_POLICY_DENIED")

    def test_inactive_principal_is_denied(self):
        calls, error = run_case(Principal("actor-1", "acme", "operator", active=False))
        self.assertEqual(calls, 0)
        self.assertEqual(error_code(error), "AGENT_POLICY_DENIED")

    def test_model_claimed_role_is_ignored(self):
        calls, error = run_case(
            Principal("actor-1", "acme", "viewer"),
            claimed_role="admin",
        )
        self.assertEqual(calls, 0)
        self.assertEqual(error_code(error), "AGENT_POLICY_DENIED")

    def test_tenant_mismatch_is_denied(self):
        calls, error = run_case(
            Principal("actor-1", "acme", "operator"),
            claimed_tenant="other",
        )
        self.assertEqual(calls, 0)
        self.assertEqual(error_code(error), "AGENT_POLICY_DENIED")

    def test_verified_operator_is_allowed(self):
        calls, error = run_case(Principal("actor-1", "acme", "operator"))
        self.assertIsNone(error)
        self.assertEqual(calls, 1)


if __name__ == "__main__":
    unittest.main()
