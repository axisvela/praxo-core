#include "authentication.h"

#include <stdio.h>
#include <string.h>

static int failures = 0;

#define CHECK(condition) \
    do { \
        if (!(condition)) { \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #condition); \
            failures += 1; \
        } \
    } while (0)

#define NOW 1700000000LL

typedef struct {
    int calls;
    const char *url;
    char form[512];
    char authorization[256];
    int status;
    const char *body;
    int error;
} FakeTransport;

static int fake_transport(const char *url, const char *form,
        const char *authorization, int *status, const char **body,
        void *context) {
    FakeTransport *fake = context;
    fake->calls += 1;
    fake->url = url;
    snprintf(fake->form, sizeof(fake->form), "%s", form == NULL ? "" : form);
    snprintf(fake->authorization, sizeof(fake->authorization), "%s",
             authorization == NULL ? "" : authorization);
    if (fake->error != 0) {
        return 1;
    }
    *status = fake->status;
    *body = fake->body;
    return 0;
}

static void reset_fake(FakeTransport *fake, int status, const char *body) {
    fake->calls = 0;
    fake->url = NULL;
    fake->form[0] = '\0';
    fake->authorization[0] = '\0';
    fake->status = status;
    fake->body = body;
    fake->error = 0;
}

static void init_auth(ServiceAuthIntrospector *auth, FakeTransport *fake,
        const char *client_id, const char *client_secret,
        const char *tenant_claim) {
    service_auth_introspector_init(auth, fake_transport, fake,
            "https://idp.example/introspect", client_id, client_secret,
            tenant_claim);
}

static void expect_rejected(const char *body, int status, int error) {
    FakeTransport fake;
    reset_fake(&fake, status, body);
    fake.error = error;
    ServiceAuthIntrospector auth;
    init_auth(&auth, &fake, "", "", "tenant");
    ServiceAuthPrincipal principal;
    CHECK(!service_auth_introspect(&auth, "Bearer token-1", NOW, &principal));
    CHECK(principal.subject == NULL);
    CHECK(principal.tenant == NULL);
}

static void test_success(void) {
    FakeTransport fake;
    reset_fake(&fake, 200,
            "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000060}");
    ServiceAuthIntrospector auth;
    init_auth(&auth, &fake, "svc", "secret", "tenant");
    ServiceAuthPrincipal principal;
    CHECK(service_auth_introspect(&auth, "Bearer token-1", NOW, &principal));
    CHECK(strcmp(principal.subject, "user-1") == 0);
    CHECK(strcmp(principal.tenant, "tenant-a") == 0);
    CHECK(principal.expires == NOW + 60);
    CHECK(fake.calls == 1);
    CHECK(strcmp(fake.url, "https://idp.example/introspect") == 0);
    CHECK(strstr(fake.form, "token=token-1") != NULL);
    CHECK(strstr(fake.form, "client_id=svc") != NULL);
    CHECK(strstr(fake.form, "client_secret=secret") != NULL);
    CHECK(strcmp(fake.authorization, "Basic c3ZjOnNlY3JldA==") == 0);
    service_auth_principal_free(&principal);
    CHECK(principal.subject == NULL);
    CHECK(principal.tenant == NULL);
}

static void test_local_rejections(void) {
    FakeTransport fake;
    reset_fake(&fake, 200,
            "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000060}");
    ServiceAuthIntrospector auth;
    init_auth(&auth, &fake, "svc", "secret", "tenant");
    ServiceAuthPrincipal principal;
    CHECK(!service_auth_introspect(&auth, NULL, NOW, &principal));
    CHECK(!service_auth_introspect(&auth, "Basic token", NOW, &principal));
    CHECK(!service_auth_introspect(&auth, "Bearer   ", NOW, &principal));
    CHECK(fake.calls == 0);
}

static void test_rejected_bodies(void) {
    expect_rejected(
            "{\"active\":false,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000060}", 200, 0);
    expect_rejected(
            "{\"active\":true,\"tenant\":\"tenant-a\",\"exp\":1700000060}",
            200, 0);
    expect_rejected(
            "{\"active\":true,\"sub\":\"\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000060}", 200, 0);
    expect_rejected(
            "{\"active\":true,\"sub\":\"user-1\",\"exp\":1700000060}", 200, 0);
    expect_rejected(
            "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"\","
            "\"exp\":1700000060}", 200, 0);
    expect_rejected(
            "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000000}", 200, 0);
    expect_rejected(
            "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\"}",
            200, 0);
    expect_rejected("not-json", 200, 0);
    expect_rejected(
            "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000060}", 500, 0);
    expect_rejected(
            "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000060}", 200, 1);
}

static void test_no_basic_without_client_id(void) {
    FakeTransport fake;
    reset_fake(&fake, 200,
            "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000060}");
    ServiceAuthIntrospector auth;
    init_auth(&auth, &fake, "", "", "tenant");
    ServiceAuthPrincipal principal;
    CHECK(service_auth_introspect(&auth, "Bearer token-1", NOW, &principal));
    CHECK(fake.authorization[0] == '\0');
    service_auth_principal_free(&principal);
}

static void test_custom_tenant_claim(void) {
    FakeTransport fake;
    reset_fake(&fake, 200,
            "{\"active\":true,\"sub\":\"user-1\",\"org\":\"org-a\","
            "\"exp\":1700000060}");
    ServiceAuthIntrospector auth;
    init_auth(&auth, &fake, "", "", "org");
    ServiceAuthPrincipal principal;
    CHECK(service_auth_introspect(&auth, "Bearer token-1", NOW, &principal));
    CHECK(strcmp(principal.tenant, "org-a") == 0);
    service_auth_principal_free(&principal);
}

static void init_revoker(ServiceAuthRevoker *client, FakeTransport *fake,
        const char *client_id, const char *client_secret) {
    service_auth_revoker_init(client, fake_transport, fake,
            "https://idp.example/revoke", client_id, client_secret);
}

static void test_revocation(void) {
    FakeTransport fake;
    reset_fake(&fake, 200, "");
    ServiceAuthRevoker client;
    init_revoker(&client, &fake, "svc", "secret");
    CHECK(service_auth_revoke(&client, "token-1"));
    CHECK(fake.calls == 1);
    CHECK(strstr(fake.form, "token=token-1") != NULL);
    CHECK(strstr(fake.form, "token_type_hint=access_token") != NULL);
    CHECK(strstr(fake.form, "client_id=svc") != NULL);
    CHECK(strstr(fake.form, "client_secret=secret") != NULL);
    CHECK(strcmp(fake.authorization, "Basic c3ZjOnNlY3JldA==") == 0);

    reset_fake(&fake, 400, "");
    CHECK(!service_auth_revoke(&client, "token-1"));

    reset_fake(&fake, 200, "");
    fake.error = 1;
    CHECK(!service_auth_revoke(&client, "token-1"));

    FakeTransport local;
    reset_fake(&local, 200, "");
    ServiceAuthRevoker local_client;
    init_revoker(&local_client, &local, "svc", "secret");
    CHECK(!service_auth_revoke(&local_client, ""));
    CHECK(local.calls == 0);
}

int main(void) {
    test_success();
    test_local_rejections();
    test_rejected_bodies();
    test_no_basic_without_client_id();
    test_custom_tenant_claim();
    test_revocation();
    if (failures != 0) {
        return 1;
    }
    printf("C service auth tests passed\n");
    return 0;
}
