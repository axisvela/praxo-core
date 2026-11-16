#ifndef PRAXO_SERVICE_AUTHENTICATION_H
#define PRAXO_SERVICE_AUTHENTICATION_H

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    char *subject;
    char *tenant;
    int64_t expires;
} ServiceAuthPrincipal;

typedef int (*ServiceAuthTransport)(const char *url, const char *form,
        const char *authorization, int *status, const char **body,
        void *context);

typedef struct {
    ServiceAuthTransport transport;
    void *context;
    const char *endpoint;
    const char *client_id;
    const char *client_secret;
    const char *tenant_claim;
} ServiceAuthIntrospector;

typedef struct {
    ServiceAuthTransport transport;
    void *context;
    const char *endpoint;
    const char *client_id;
    const char *client_secret;
} ServiceAuthRevoker;

void service_auth_introspector_init(ServiceAuthIntrospector *auth,
        ServiceAuthTransport transport, void *context,
        const char *endpoint, const char *client_id,
        const char *client_secret, const char *tenant_claim);

bool service_auth_introspect(const ServiceAuthIntrospector *auth,
        const char *authorization, int64_t now,
        ServiceAuthPrincipal *principal);

void service_auth_principal_free(ServiceAuthPrincipal *principal);

void service_auth_revoker_init(ServiceAuthRevoker *client,
        ServiceAuthTransport transport, void *context,
        const char *endpoint, const char *client_id,
        const char *client_secret);

bool service_auth_revoke(const ServiceAuthRevoker *client,
        const char *token);

#endif
