# Generator Guide

## Commands

```bash
devkit generate feature products
devkit generate model Product --fields id:String,name:String,price:double?
devkit generate model Product --from-json product.json
devkit generate widget ProductCard
devkit generate widget ProductCard --feature products
devkit generate screen ProductDetails
devkit generate screen ProductDetails --feature products
devkit generate bloc Products
devkit generate cubit Products --feature products
devkit generate provider Products --state riverpod
devkit generate feature products
devkit generate repository products --feature products --crud
devkit generate service NotificationService
devkit generate enum OrderStatus --values pending,shipped,delivered
devkit generate extension StringX --on String
devkit generate test Product --kind unit --target model
devkit generate api shop --spec openapi.yaml
devkit generate api shop --spec openapi.json --base-url https://api.example.com --force
```

## Shared flags

| Flag | Meaning |
|------|---------|
| `--dry-run` | Preview files only |
| `--force` / `-f` | Overwrite existing files (backups when configured) |
| `--architecture` | `clean` \| `feature_first` \| `layered` |
| `--state` | `bloc` \| `cubit` \| `riverpod` \| `provider` |
| `--tests` / `--no-tests` | Toggle test generation |

## Feature flags

| Flag | Meaning |
|------|---------|
| `--crud` | create/update/delete on repository + remote datasource |
| `--pagination` | `fetchPage` APIs + UI hook comment |
| `--search` | `search` APIs + UI hook comment |
| `--filters` | UI hook comment |
| `--local` | local datasource + cache |
| `--remote` / `--no-remote` | remote datasource (default on) |
| `--fields` | entity/model fields (`id:String,name:String`) |
| `--values` | Enum values (`pending,shipped`) |
| `--on` | Extension target type (`String`) |
| `--kind` | Test kind (`unit` \| `widget`) |
| `--target` | Test target folder/type (`model`, `service`, …) |
| `--spec` | OpenAPI 3.x YAML/JSON path (`api` generator) |
| `--base-url` | Override OpenAPI server URL (`api` generator) |
| `--output` | API client output directory (default `lib/api/<name>`) |
| `--add-missing-chico` | Explicitly add missing Chico deps required by UI gens |

## Feature layouts

### Clean / feature-first

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

### Layered

```text
lib/data/...
lib/domain/...
lib/presentation/features/<name>/...
```

## Model notes

- Always generates `fromJson`, `toJson`, `copyWith`, and `==`/`hashCode`
- `--from-json` infers types from a JSON object (or first array element)
- Nested objects become `Map<String, dynamic>` in this phase

## Repository notes

- Requires an existing feature entity + model + at least one datasource
- Prefer `devkit generate feature <name>` first
- Standalone generation without prerequisites fails with exit code 64

## Feature notes

- Output is a **scaffold**, not a finished CRUD app
- Datasource/state methods may contain `UnimplementedError` / TODO wiring points
- CLI summary reports pending implementation counts

## API notes

- Requires `--spec` pointing at OpenAPI 3.x YAML or JSON
- Writes under `lib/api/<name>/generated/` for safe regeneration
- Details: [OPENAPI.md](OPENAPI.md)

## UI packages

When `chico.ui` / `chico.kit` are enabled in `.chico/devkit.yaml`, widgets and
screens use verified Chico APIs (`ChicoScaffold`, `ChicoListTile`, …).
Otherwise Material widgets are generated.

## Adding a generator

1. Implement `Generator` (or extend `BaseGenerator`)
2. Register it in `createDefaultGeneratorRegistry()`
3. Add focused unit tests under `test/generators/`
