# OpenAPI Support Matrix

**Package version:** `1.0.0-dev.10`  
**Validator:** `lib/src/openapi/support_validator.dart`  
**Parser:** `lib/src/openapi/parser.dart`

DevKit implements a **documented subset** of OpenAPI 3.x. Unsupported
constructs **fail closed** (actionable `InvalidUsageException`) and do not
write generated files.

## Supported

| Construct | Behavior | Evidence |
|-----------|----------|----------|
| OpenAPI 3.0 / 3.1 document root | Parsed | Unit **executed** |
| `info.title` / `info.version` | Required / defaulted | Unit **executed** |
| `servers[].url` | First used as default base URL | Unit **executed** |
| Path ops `get` `post` `put` `patch` `delete` | Generated client methods | Unit **executed** (`shop_api.yaml`) |
| Parameters `path` `query` `header` | Mapped to Dart args | Unit **executed** |
| `application/json` request/response bodies | Typed when schema resolves | Unit **executed** |
| `components.schemas` object / enum / array | Models generated | Unit **executed** |
| Local `$ref` `#/components/schemas/…` | Resolved + imports emitted | Unit **executed** |
| Simple `allOf` merge | Properties/required merged | Inspected + shop fixture |
| HTTP `bearer` | `OpenApiAuthType.bearer` | Unit **executed** |
| `apiKey` header/query | `OpenApiAuthType.apiKey` | Unit **executed** |
| No security schemes / empty security | `OpenApiAuthType.none` | Unit **executed** (`supported/no_security.yaml`) |
| Pagination query names | `paginated` flag | Unit **executed** |

## Unsupported (rejected)

| Construct | Error identifies | Evidence |
|-----------|------------------|----------|
| `oneOf` | construct + schema path | Unit **executed** |
| `anyOf` | construct + schema path | Unit **executed** |
| `discriminator` | construct + schema path | Unit **executed** |
| `not` | construct + schema path | Inspected (validator) |
| Nested unsupported in otherwise valid schema | property path | Unit **executed** (mixed fixture) |
| `oauth2` | scheme location; never `AuthType.none` | Unit **executed** |
| `openIdConnect` | scheme location | Unit **executed** |
| HTTP `basic` | `http.basic` | Unit **executed** |
| Unknown scheme types (e.g. `mutualTLS`) | type name | Unit **executed** |
| Security requirement → missing scheme | unknown scheme name | Unit **executed** |
| Cookie parameters | `parameter.in=cookie` | Inspected (validator) |
| Non-local `$ref` | ref value | Inspected (validator) |
| Request body without `application/json` | media types listed | Inspected (validator) |
| `head` / `options` / `trace` | method location | Inspected (validator) |
| `webhooks` / `callbacks` | location | Inspected (validator) |

## Semantic rules

1. **No security ≠ unsupported security.** A document with no schemes and no
   requirements correctly yields an unauthenticated client.
2. **Unsupported security ≠ no security.** OAuth2/OIDC/Basic/unknown schemes
   abort generation; they are never downgraded to `AuthType.none`.
3. **Unsupported schema ≠ empty model.** `oneOf`/`anyOf`/discriminator abort
   generation; they are never emitted as empty object classes.
4. **Failure writes nothing.** Generator `validate()` parses first; unsupported
   specs throw before `applyWrites` (**executed** — no `generated/` directory).

## Fixtures

| Path | Role |
|------|------|
| `test/fixtures/openapi/shop_api.yaml` | Supported multi-method + bearer |
| `test/fixtures/openapi/supported/no_security.yaml` | Explicitly unauthenticated |
| `test/fixtures/openapi/supported/api_key.yaml` | API key auth |
| `test/fixtures/openapi/unsupported/*.yaml` | Fail-closed regression set |
