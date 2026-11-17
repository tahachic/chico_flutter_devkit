# OpenAPI client generation

```bash
devkit generate api shop --spec path/to/openapi.yaml
devkit generate api shop --spec openapi.json --base-url https://api.example.com --force
```

Related: [Support matrix](../OPENAPI_SUPPORT_MATRIX.md) · [Cookbook](COOKBOOK.md#openapi-client) · [Generator guide](GENERATOR_GUIDE.md#api-openapi)

## Supported OpenAPI subset

DevKit parses **OpenAPI 3.0 / 3.1** YAML or JSON and generates only from the
spec — it does not invent endpoints.

This is a **subset**, not full OpenAPI compatibility.
See also [`OPENAPI_SUPPORT_MATRIX.md`](../OPENAPI_SUPPORT_MATRIX.md).

| Area | Support |
|------|---------|
| Paths | `get`, `post`, `put`, `patch`, `delete` |
| Parameters | path, query, header |
| Bodies | `application/json` request/response; `multipart/form-data` requests |
| Schemas | objects, enums, arrays, `$ref`, simple `allOf` |
| Auth | HTTP bearer, HTTP basic, API key (header/query) |
| Pagination | detects `page` / `limit` / `offset` / `cursor` query params |
| No security | Explicit absence of security ⇒ unauthenticated client |

## Fail-closed unsupported constructs

Unsupported constructs are **rejected before any files are written**.
Generation does **not** silently:

- turn `oneOf` / `anyOf` / `discriminator` into empty object models
- turn OAuth2 / OpenID / unknown schemes into `AuthType.none`

Errors include construct name, JSON/YAML location, reason, and suggested action.

## Explicitly unsupported

- `oneOf` / `anyOf` / `not` / discriminators
- Remote `$ref` (non-`#/components/schemas/…`)
- Cookie parameters
- OAuth2 / OpenID Connect / unknown security scheme types
- Form-urlencoded-only request bodies (no JSON and no multipart)
- Modeled error response schemas (non-2xx bodies are not typed)
- `head` / `options` / `trace` operations
- Callbacks, links, webhooks

## Multipart uploads

When an operation uses `multipart/form-data`:

- Object properties become method parameters
- `format: binary` / `byte` → `List<int>` (+ optional `…Filename`)
- Other scalar properties → form fields
- If both JSON and multipart are listed, **JSON is preferred** for codegen

## Output layout

```text
lib/api/<name>/
  README.md
  generated/          # regenerated — do not edit
    client.dart
    auth.dart
    exception.dart
    models/
```

Put wrappers **outside** `generated/`. Re-run with `--force` to refresh.

## Notes

- Client uses `dart:io` `HttpClient` (no extra dependency).
- Default base URL comes from `servers[0]` unless `--base-url` is set.
- Client class name is `<Name>Api` unless the name already ends with `Api`/`Client`.
