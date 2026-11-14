# Generator guide

```bash
devkit generate <type> <name> [flags]
devkit list generators
```

Always available shared flags: `--dry-run`, `--force` / `-f`, `--tests` /
`--no-tests`, `--architecture`, `--state`, `--feature`, `--add-missing-chico`.

---

## `feature`

Scaffold a feature for the project architecture (domain/data/presentation).

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

**Honest scaffold:** datasources / some state methods may throw
`UnimplementedError`. The CLI summary reports pending implementation counts.

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

These are state scaffolds — wire them into pages yourself (TODOs are included).

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
```

| Flag | Values |
|------|--------|
| `--kind` | `unit` (default), `widget` |
| `--target` | logical folder/type hint (`model`, `service`, …) |

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
