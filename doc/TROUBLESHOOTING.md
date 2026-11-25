# Troubleshooting

## `devkit: command not found`

1. Confirm activation:

   ```bash
   dart pub global activate chico_flutter_devkit
   dart pub global list
   ```

2. Add Pub global bin to `PATH`:

   | OS | Typical path |
   |----|----------------|
   | Windows | `%LOCALAPPDATA%\Pub\Cache\bin` |
   | macOS / Linux | `$HOME/.pub-cache/bin` |

3. On **Git Bash**, use `devkit.bat` (Pub installs a `.bat` shim).

   ```bash
   devkit.bat --version
   # or
   cmd //c "devkit --version"
   ```

---

## Create fails: directory not empty

`devkit create` refuses non-empty targets. Use a new folder or `--output` to a
fresh path.

---

## Android build fails (compileSdk / permission_handler)

See [ANDROID.md](ANDROID.md). Short version:

- Prefer Material create if you do not need Chico plugins
- With Chico services, use **`chico_services` ≥ 1.4.1** (caps `permission_handler`)
- Or create with `--chico --no-chico-services`

---

## Which routing should I pick?

- `--routing go_router` (default) — declarative routes, deep links, `context.go`
- `--routing navigator` — Navigator 1.0 named routes, `Navigator.pushNamed`

Both get feature Home links and `/features/<name>` registration.

---

## Repository generation fails with “prerequisites are missing”

Generate a feature first:

```bash
devkit generate feature products --remote
devkit generate repository products --feature products
```

DevKit will **not** write broken repository files that import missing types.

---

## Missing Chico dependency error

```text
Missing Chico dependency required by generated UI.
  - chico_ui  →  devkit add chico_ui
```

Fix options:

```bash
devkit add chico_ui
devkit add chico_kit
# or explicitly during generate:
devkit generate widget PriceTag --add-missing-chico
```

`--dry-run` never modifies `pubspec.yaml`.

Incompatible version constraints also fail with a clear message — DevKit does
**not** overwrite existing constraints.

---

## `flutter analyze --fatal-infos` fails on Material deprecation

On Flutter **3.47+**, `package:flutter/material.dart` is deprecated in favor of
`package:material_ui`. DevKit create detects Flutter ≥ 3.47 and for Material-first
apps:

- adds `material_ui` (+ `cupertino_ui`)
- scaffolds with `package:material_ui/material_ui.dart`
- runs `dart fix --apply --code=migrate_design_widgets` after gen-l10n

Chico-enabled apps keep `flutter/widgets.dart` + Chico (no Material import).

On older Flutter (< 3.47), Material-first apps still use `flutter/material.dart`.

---

## OpenAPI generation fails

Unsupported constructs fail **before any files are written**. The error lists:

- construct name (`oneOf`, `oauth2`, …)
- location in the document
- reason + suggested action

See [OPENAPI.md](OPENAPI.md) and [OPENAPI_SUPPORT_MATRIX.md](../OPENAPI_SUPPORT_MATRIX.md).

### `--spec` vs `--from-api`

| Flag | Use when |
|------|----------|
| `feature --spec <file>` | Need client + wired feature in one command |
| `feature --from-api <name>` | Client already under `lib/api/<name>/generated` |

Passing both fails closed. Spec file not found / no list op / unmappable fields
also fail **before** writing API or feature files.

---

## `--sync` refused / custom regions

```text
Refusing to sync user-edited generated file.
```

`--sync` only refreshes files that still match the generate manifest **or** differ
only inside `// <devkit:custom id="…">` regions. Edits outside regions need
`--force` (or restore the file). Region-only edits are preserved on sync.

Doctor may report `generate.manifest_drift` when hashes diverge — same recovery.

---

## `devkit adopt` refuses Home / router / DI

Adopt never overwrites a custom Home without markers. Add:

```dart
// <devkit:home-features>
// </devkit:home-features>
```

inside the Home children list, then re-run. Existing `app_router.dart` /
`feature_routes.dart` / DI files must already contain DevKit anchors (or be
removed so adopt can scaffold them).

---

## Auth `--ui` fails (missing anchors)

`generate auth session --ui` requires:

- Project config: `--routing go_router` and `--di get_it`
- `lib/core/routing/app_router.dart` with `AppRouter` and `featureRoutes`
- `lib/core/di/injector.dart` with `registerFeatures(getIt);`

Navigator / Riverpod / manual DI refuse `--ui` (no pretend guard). Create or
`adopt` with go_router + get_it, or generate auth without `--ui`.

---

## Overwrite refused

```text
Refusing to overwrite existing file.
```

Use `--force` (backups may be created) or delete the file first. Prefer
`--dry-run` to inspect the plan.

---

## Doctor still shows warnings after `--fix`

`--fix` only applies **safe** repairs (config, analysis options, test dir).
Remaining items (missing `pubspec.lock`, missing Chico deps, empty test files)
need manual follow-up (`flutter pub get`, `devkit setup chico`, write tests).

---

## Feature list shows demo / sample data

Expected. `generate feature` wires a **seeded in-memory list** so Home → feature
works out of the box. Replace the datasource (and any remaining TODOs in CRUD
hooks) with your API or OpenAPI client when you leave the demo stage.

---

## Still stuck?

```bash
devkit --verbose <command>
devkit doctor --json
```

Open an issue with the command, OS, Flutter version, and the full error output:
https://github.com/tahachic/chico_flutter_devkit/issues
