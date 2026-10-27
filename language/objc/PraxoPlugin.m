#import "PraxoWire.h"
#import "PraxoJSON.h"

#import <math.h>

static NSSet<NSString *> *PXRTopKeys(void) {
    return [NSSet setWithArray:@[
        @"schemaVersion", @"id", @"version", @"kind", @"entrypoint",
        @"protocol", @"capabilities", @"permissions", @"limits",
        @"isolation", @"health", @"signature", @"sbom",
    ]];
}

static NSSet<NSString *> *PXREntrypointKeys(void) {
    return [NSSet setWithArray:@[@"type", @"command", @"module", @"image",
                                  @"args", @"dir"]];
}

static NSSet<NSString *> *PXRPermissionKeys(void) {
    return [NSSet setWithArray:@[@"filesystem", @"network", @"env"]];
}

static NSSet<NSString *> *PXRLimitKeys(void) {
    return [NSSet setWithArray:@[@"memoryMB", @"cpuMillis", @"timeoutMs",
                                  @"maxInflight"]];
}

static NSSet<NSString *> *PXRHealthKeys(void) {
    return [NSSet setWithArray:@[@"method", @"intervalMs"]];
}

static NSSet<NSString *> *PXRSignatureKeys(void) {
    return [NSSet setWithArray:@[@"algorithm", @"keyId"]];
}

static BOOL PXRManifestFail(NSError **error, NSString *message) {
    if (error != NULL) {
        *error = PXRError(PXRWireErrorInvalidManifest, message);
    }
    return NO;
}

static BOOL PXRCheckKeys(NSDictionary<NSString *, id> *value,
                         NSSet<NSString *> *allowed,
                         NSString *where,
                         NSError **error) {
    for (NSString *key in value) {
        if (![allowed containsObject:key]) {
            return PXRManifestFail(error, [NSString stringWithFormat:
                @"plugin: manifest: unknown field %@ in %@", key, where]);
        }
    }
    return YES;
}

static NSDictionary<NSString *, id> *PXRAsObject(id value,
                                                 NSString *where,
                                                 NSError **error) {
    if (value == nil) {
        return @{};
    }
    if (![value isKindOfClass:[NSDictionary class]]) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: %@ must be an object", where]);
        return nil;
    }
    return value;
}

static NSString *PXRAsString(id value, NSString *where, NSError **error) {
    if (![value isKindOfClass:[NSString class]]) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: %@ must be a string", where]);
        return nil;
    }
    return value;
}

static NSNumber *PXRAsInteger(id value, NSString *where, NSError **error) {
    if (!PXRIsNumberValue(value)) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: %@ must be an integer", where]);
        return nil;
    }
    NSNumber *number = value;
    double raw = number.doubleValue;
    if (trunc(raw) != raw || raw < (double)NSIntegerMin ||
        raw > (double)NSIntegerMax) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: %@ must be an integer", where]);
        return nil;
    }
    return number;
}

static BOOL PXRTextPresent(id value) {
    return [value isKindOfClass:[NSString class]] && [value length] > 0;
}

static BOOL PXRKnownKind(NSString *kind) {
    return [[NSSet setWithArray:@[
        @"tool.provider.v1", @"model.provider.v1", @"policy.provider.v1",
        @"memory.provider.v1", @"sandbox.provider.v1",
    ]] containsObject:kind];
}

NSDictionary<NSString *, id> * _Nullable PXRParseManifest(
    NSString *raw, NSError **error) {
    if (raw == nil || [[raw stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
        PXRManifestFail(error, @"plugin: manifest is empty");
        return nil;
    }
    id parsed = nil;
    if (!PXRParseJSONText(raw, &parsed, error)) {
        return nil;
    }
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        PXRManifestFail(error, @"plugin: manifest must be an object");
        return nil;
    }
    NSDictionary<NSString *, id> *root = parsed;
    if (!PXRCheckKeys(root, PXRTopKeys(), @"manifest", error)) {
        return nil;
    }
    NSNumber *schemaVersion = PXRAsInteger(root[@"schemaVersion"],
                                          @"schemaVersion", error);
    if (schemaVersion == nil) {
        return nil;
    }
    if (schemaVersion.integerValue != 1) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: schemaVersion = %@, want 1", schemaVersion]);
        return nil;
    }
    NSString *identifier = PXRAsString(root[@"id"], @"id", error);
    if (identifier == nil) {
        return nil;
    }
    NSString *idPattern =
        @"^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+"
         "[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$";
    if (!PXRMatchesFull(idPattern, identifier)) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: id %@ is not reverse-DNS", identifier]);
        return nil;
    }
    NSString *version = PXRAsString(root[@"version"], @"version", error);
    if (version == nil) {
        return nil;
    }
    NSString *versionPattern =
        @"^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)"
         "(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?$";
    if (!PXRMatchesFull(versionPattern, version)) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: version %@ is not semver", version]);
        return nil;
    }
    NSString *kind = PXRAsString(root[@"kind"], @"kind", error);
    if (kind == nil) {
        return nil;
    }
    if (!PXRKnownKind(kind)) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: kind %@ is not a known contract", kind]);
        return nil;
    }
    NSString *protocolName = PXRAsString(root[@"protocol"], @"protocol", error);
    if (protocolName == nil) {
        return nil;
    }
    if (![protocolName isEqualToString:@"jsonrpc-2"]) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: protocol = %@, want jsonrpc-2", protocolName]);
        return nil;
    }
    NSDictionary<NSString *, id> *entrypoint =
        PXRAsObject(root[@"entrypoint"], @"entrypoint", error);
    if (entrypoint == nil ||
        !PXRCheckKeys(entrypoint, PXREntrypointKeys(), @"entrypoint", error)) {
        return nil;
    }
    NSString *entryType = PXRAsString(entrypoint[@"type"], @"entrypoint.type", error);
    if (entryType == nil) {
        return nil;
    }
    NSString *required = nil;
    if ([entryType isEqualToString:@"process"]) {
        required = @"command";
    } else if ([entryType isEqualToString:@"wasm"]) {
        required = @"module";
    } else if ([entryType isEqualToString:@"container"]) {
        required = @"image";
    } else {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: unknown entrypoint type %@", entryType]);
        return nil;
    }
    if (!PXRTextPresent(entrypoint[required])) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: %@ entrypoint requires %@", entryType, required]);
        return nil;
    }
    NSString *isolation = PXRAsString(root[@"isolation"], @"isolation", error);
    if (isolation == nil) {
        return nil;
    }
    if (![isolation isEqualToString:entryType]) {
        PXRManifestFail(error, [NSString stringWithFormat:
            @"plugin: manifest: isolation %@ does not match entrypoint %@",
            isolation, entryType]);
        return nil;
    }
    NSDictionary<NSString *, id> *permissions =
        PXRAsObject(root[@"permissions"], @"permissions", error);
    if (permissions == nil ||
        !PXRCheckKeys(permissions, PXRPermissionKeys(), @"permissions", error)) {
        return nil;
    }
    NSDictionary<NSString *, id> *limits =
        PXRAsObject(root[@"limits"], @"limits", error);
    if (limits == nil ||
        !PXRCheckKeys(limits, PXRLimitKeys(), @"limits", error)) {
        return nil;
    }
    for (NSString *key in limits) {
        NSNumber *value = PXRAsInteger(limits[key],
                                       [NSString stringWithFormat:@"limits.%@", key],
                                       error);
        if (value == nil) {
            return nil;
        }
        if (value.integerValue < 0) {
            PXRManifestFail(error, @"plugin: manifest: limits must not be negative");
            return nil;
        }
    }
    NSDictionary<NSString *, id> *health =
        PXRAsObject(root[@"health"], @"health", error);
    if (health == nil ||
        !PXRCheckKeys(health, PXRHealthKeys(), @"health", error)) {
        return nil;
    }
    if (root[@"signature"] != nil) {
        NSDictionary<NSString *, id> *signature =
            PXRAsObject(root[@"signature"], @"signature", error);
        if (signature == nil ||
            !PXRCheckKeys(signature, PXRSignatureKeys(), @"signature", error)) {
            return nil;
        }
        if (!PXRTextPresent(signature[@"algorithm"]) ||
            !PXRTextPresent(signature[@"keyId"])) {
            PXRManifestFail(error,
                @"plugin: manifest: signature requires algorithm and keyId");
            return nil;
        }
    }
    NSMutableArray<NSString *> *capabilities = [NSMutableArray array];
    id rawCapabilities = root[@"capabilities"];
    if (rawCapabilities != nil) {
        if (![rawCapabilities isKindOfClass:[NSArray class]]) {
            PXRManifestFail(error,
                @"plugin: manifest: capabilities must be an array");
            return nil;
        }
        for (id item in rawCapabilities) {
            NSString *capability = PXRAsString(item, @"capabilities", error);
            if (capability == nil) {
                return nil;
            }
            if (capability.length == 0) {
                PXRManifestFail(error,
                    @"plugin: manifest: capability must not be empty");
                return nil;
            }
            if ([capabilities indexOfObject:capability] != NSNotFound) {
                PXRManifestFail(error,
                    @"plugin: manifest: duplicate capability");
                return nil;
            }
            [capabilities addObject:capability];
        }
    }
    NSMutableDictionary<NSString *, id> *manifest = [NSMutableDictionary dictionary];
    manifest[@"schemaVersion"] = schemaVersion;
    manifest[@"id"] = identifier;
    manifest[@"version"] = version;
    manifest[@"kind"] = kind;
    manifest[@"entrypoint"] = entrypoint;
    manifest[@"protocol"] = protocolName;
    manifest[@"capabilities"] = capabilities;
    manifest[@"permissions"] = permissions;
    manifest[@"limits"] = limits;
    manifest[@"health"] = health;
    manifest[@"isolation"] = isolation;
    if (root[@"signature"] != nil) {
        manifest[@"signature"] = root[@"signature"];
    }
    if (root[@"sbom"] != nil) {
        manifest[@"sbom"] = root[@"sbom"];
    }
    return manifest;
}
