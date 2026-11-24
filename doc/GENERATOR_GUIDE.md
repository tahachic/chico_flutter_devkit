# Generator guide

```bash
devkit generate <type> <name> [flags]
devkit list generators
```

Always available shared flags: `--dry-run`, `--force` / `-f`, `--tests` /
`--no-tests`, `--architecture`, `--state`, `--feature`, `--add-missing-chico`.

---

## `feature`

Generate a **runnable demo feature** (domain/data/presentation): seeded
in-memory list, wired state, GoRoute, DI hooks (get_it / Riverpod barrel /
manual factories), and a Home link.

```bash
devkit generate feature products
devkit generate feature products --crud --pagination --search --filters --local
devkit generate feature catalog --architecture layered --state riverpod --no-tests
```

| Flag | Effect |
|------|--------|
| `--crud` | create/update/delete on repository + remote |
| `--pagination` | page APIs + UI hook comments |
| `--search` / `--filters` | search/filter hooks |
| `--local` | local datasource |
| `--remote` / `--no-remote` | remote datasource (default on) |
| `--fields` | entity/model fields |
| `--from-api <name>` | Wire remote datasource to `lib/api/<name>/generated` (fail-closed) |
| `--spec <path>` | Generate API client from OpenAPI then wire the feature (one command) |
| `--api-name <name>` | Override API client folder when using `--spec` (default: feature snake) |

Open **Home → feature name** or `/features/<name>` after generate (go_router
`context.go` or Navigator `pushNamed`, matching create `--routing`). Demo data
is not production CRUD — swap the datasource for your API when ready.

### OpenAPI → runnable screen (`--spec`)

```bash
devkit generate feature products --spec openapi/shop_api.yaml --pagination --search
devkit generate feature products --spec openapi/shop_api.yaml --api-name shop --crud
```

`--spec` and `--from-api` are mutually exclusive. Preflight parses OpenAPI and
validates a list op + field mapping **before any writes**. On success: write the
API client under `lib/api/<name>/generated`, then the wired feature + DI + routes.
API-wired features also emit remote mapping + use-case load/error unit tests
(when tests are enabled).

### Wire an existing client (`--from-api`)

```bash
devkit generate api shop --spec openapi/shop_api.yaml
devkit generate feature products --from-api shop --pagination --search
# With --crud, the API must expose create/update/delete for the list item type.
```

Fail-closed when the client is missing, no `Future<List<…>>` list method exists,
or a required feature field cannot be mapped from the API model. Shared flags:
`--dry-run`, `--force`, `--sync` (refresh unchanged manifest files; preserves
`// <devkit:custom id="…">` regions).

### Custom regions

Generated remote datasources (and auth UI/router stubs) include empty custom
regions. On `--sync` / regenerate, matching region bodies are re-injected.
Edits **outside** regions still refuse `--sync` (use `--force`).
### Layout (clean / feature-first)

```text
lib/features/<name>/
  data/datasources/
  data/models/
  data/repositories/
  domain/entities/
  domain/repositories/
  domain/usecases/
  presentation/<bloc|cubit|providers>/
  presentation/pages/
  presentation/widgets/
```

---

## `model`

```bash
devkit generate model Product --fields id:String,name:String,price:double?
devkit generate model Product --from-json product.json
```

Always emits `fromJson`, `toJson`, `copyWith`, `==` / `hashCode`.

Default path: `lib/models/<snake>.dart`

---

## `widget`

```bash
devkit generate widget ProductCard
devkit generate widget ProductCard --feature products
```

Uses Chico widgets when Chico is enabled in config; otherwise Material.

---

## `screen`

```bash
devkit generate screen ProductDetails
devkit generate screen ProductDetails --feature products --no-tests
```

Default path: `lib/presentation/pages/<name>_page.dart`  
With `--feature`: under that feature’s `presentation/pages/`.

---

## `bloc` / `cubit` / `provider`

```bash
devkit generate bloc Products
devkit generate cubit Cart --feature products
devkit generate provider Session --state riverpod
```

Standalone state files are scaffolds. Prefer `generate feature`, which wires
state into a working list page.

---

## `repository`

Generates contract + implementation into an **existing** feature.

```bash
devkit generate feature products --remote
devkit generate repository products --feature products --crud
```

| Flag | Effect |
|------|--------|
| `--crud` / `--pagination` / `--search` | API surface |
| `--remote` / `--no-remote` | require remote datasource (default on) |
| `--local` | require local datasource |

**Fail-closed:** missing entity/model/datasource → clear error, no files written.

---

## `service`

```bash
devkit generate service NotificationService
```

Interface + implementation (+ optional test using `flutter_test` in Flutter apps).

---

## `enum`

```bash
devkit generate enum OrderStatus --values pending,shipped,delivered
```

`--values` is required.

---

## `extension`

```bash
devkit generate extension StringX --on String
```

---

## `test`

```bash
devkit generate test Product --kind unit --target model
devkit generate test ProductCard --kind widget --target widget
devkit generate test products --kind unit --target feature
```

| Flag | Values |
|------|--------|
| `--kind` | `unit` (default), `widget` |
| `--target` | logical folder/type hint (`model`, `service`, `feature`, …) |

`--target feature` fails closed if the feature is missing; refreshes
feature-oriented unit stubs when it exists.

---

## `auth`

```bash
devkit generate auth session
devkit generate auth session --ui
```

Creates:

- `lib/core/auth/session_token_store.dart` — in-memory token holder
- `lib/core/auth/session_auth.dart` — façade for generated `*ApiAuth` bearer tokens
- `lib/core/config/app_config.dart` — flavors via `--dart-define=ENV=dev|staging|prod`
- `lib/core/di/auth_registrations.dart` — get_it registrations (when DI is get_it)

With `--ui`:

- `lib/features/auth/presentation/pages/login_page.dart` — stub email/password
  (any non-empty password → `signInStub`)
- Route `/login` + guard: unauthenticated `/features/*` → `/login`
- Hooks `registerAuth` into get_it injector when present

Without `--ui`, behavior matches 1.1.0 (token store + AppConfig only).
Fail-closed when router/injector DevKit anchors are missing.
Tokens are stubs until you fill credentials. Only the `session` pack is supported.
---

## `api` (OpenAPI)

```bash
devkit generate api shop --spec openapi.yaml
devkit generate api shop --spec openapi.json --base-url https://api.example.com --force
```

| Flag | Meaning |
|------|---------|
| `--spec` | **Required** OpenAPI 3.x YAML/JSON |
| `--base-url` | Override `servers[0]` |
| `--output` | Default `lib/api/<name>` |

Supported auth: HTTP bearer, HTTP basic, API key (header/query).  
Supported bodies: `application/json` and `multipart/form-data` uploads.  
Unsupported constructs (`oneOf`, OAuth2, …) fail closed before writes.

Output lives under `generated/` for safe regeneration. See [OPENAPI.md](OPENAPI.md).

---

## UI + Chico dependencies

When `chico.ui` / `chico.kit` are enabled, widget/screen/feature UI imports Chico
packages. Missing or incompatible pubspec constraints fail with actionable
errors. Use:

```bash
devkit add chico_ui
# or
devkit generate widget X --add-missing-chico
```

---

## Adding a generator (contributors)

1. Implement `Generator` (or extend `BaseGenerator`)
2. Register in `createDefaultGeneratorRegistry()`
3. Add unit tests under `test/generators/`
