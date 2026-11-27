# Changelog

All notable changes to this project will be documented in this file.

## 1.4.0

### Changed

- Feature `--search` / `--pagination` wire TextField and Previous/Next through
  Search/GetPage use cases and bloc/cubit/provider/riverpod state
- `--filters` is comment-only (documented; no fake UI)
- CI Flutter jobs pin `3.50.0`; doctor warns when `material_ui` is missing on
  Flutter ≥ 3.47
- Adopt refuse messages include recovery paths + `upgrade scaffolds` hint
- Auth `--ui` login shows an explicit stub-credentials banner
- Docs honesty (GENERATOR_GUIDE, ARCHITECTURE Phase 8/9); removed dead
  `StubCommand`; thin service/test generators labeled as scaffolds
- Manual release guide adds desktop `--platforms` smoke checklist

### Fixed

- Local-only features with `--search` / `--pagination` implement repository
  methods via local datasource

## 1.4.0-dev.4

Docs honesty + remove `StubCommand` (folded into 1.4.0).

## 1.4.0-dev.3

Adopt / auth banner / MANUAL platforms (folded into 1.4.0).

## 1.4.0-dev.2

CI pin + doctor material_ui (folded into 1.4.0).

## 1.4.0-dev.1

Wired search/pagination (folded into 1.4.0).

## 1.3.1

### Fixed

- Auth `--ui` login page import uses `package:material_ui/material_ui.dart`
  (was `material.dart`, which does not exist)
- `devkit adopt` adds `material_ui` / `cupertino_ui` and writes Home with the
  correct import when Flutter ≥ 3.47 (avoids `--fatal-infos` deprecation)

## 1.3.0

### Added

- **`devkit adopt`** — brownfield Flutter apps into the DevKit matrix (fail-closed)
- **`create --platforms`** — desktop-capable Flutter create pass-through
- **`devkit upgrade scaffolds`** — refresh DevKit route/DI anchor stubs
- Feature `--search` / `--pagination` real UI chrome; layout-aware screen/test

### Changed

- Home upsert refuses unmarked Home (no silent replace)
- Auth `--ui` requires go_router + get_it (refuses navigator / other DI)

### Docs

- Entry-point + adopt / platforms / scaffolds / architecture honesty coverage

## 1.3.0-dev.4

### Added

- **`devkit upgrade scaffolds`** — refresh DevKit route/DI anchor stubs;
  doctor drift details suggest `--sync` / `upgrade scaffolds`

## 1.3.0-dev.3

### Added

- **`create --platforms`** — pass-through to `flutter create` (default
  `android,ios,web`)
- Feature `--search` / `--pagination` emit real TextField + Previous/Next UI
- Screen / `test --target feature` honor layered `FeatureLayout` paths

### Docs

- Honest note: `clean` ≡ `feature_first` layout; layered shell paths documented

## 1.3.0-dev.2

### Changed

- **`auth session --ui`** refuses navigator and non–get_it DI (no silent
  broken guards); requires go_router + get_it + DevKit anchors

## 1.3.0-dev.1

### Added

- **`devkit adopt`** — brownfield config + DevKit anchors (fail-closed on unmarked
  Home / foreign router/DI); ensures stack pubspec deps

### Fixed

- Feature Home upsert **refuses** existing Home without `devkit:home-features`
  markers (no more silent replace)

## 1.2.1

### Docs

- README / COMMAND_REFERENCE / GETTING_STARTED / OPENAPI / TROUBLESHOOTING
  catch-up for `--spec`, `--from-api`, auth `--ui`, `--sync`, custom region ids,
  and `generate.manifest_drift`

## 1.2.0

### Added

- **`generate feature --spec`** — OpenAPI → API client + wired feature in one
  command (`--api-name`; exclusive with `--from-api`; fail-closed preflight)
- **Custom regions** preserved on `--sync`; doctor `generate.manifest_drift`
- **`generate auth session --ui`** — login page + `/features/*` route guard
- API-wired features emit remote mapping + use-case load/error unit tests;
  `generate test <name> --target feature` refreshes feature-oriented stubs

### Docs

- GENERATOR_GUIDE / COOKBOOK / MANUAL_RELEASE_TEST updated for 1.2.0 paths

## 1.2.0-dev.4

### Added

- API-wired features emit **remote mapping** + **use-case load/error** unit tests
- `generate test <feature> --kind unit --target feature` refreshes feature stubs

## 1.2.0-dev.3

### Added

- **`generate auth session --ui`** — login page, `/login` route, and
  `/features/*` redirect guard (get_it `registerAuth` hook)

## 1.2.0-dev.2

### Added

- **Custom regions** (`// <devkit:custom id="…">`) preserved across `--sync`
- Doctor warning `generate.manifest_drift` when manifest hashes diverge

## 1.2.0-dev.1

### Added

- **`generate feature --spec`** — OpenAPI → API client + wired remote DS + DI +
  page in one command (`--api-name` override; mutually exclusive with `--from-api`)
- Preflight `ApiFeatureWire.validateFromDocument` fails closed before any writes

## 1.1.0

### Added

- **`--from-api <name>`** on `generate feature` — wires remote datasource to
  `lib/api/<name>/generated` (list + optional page/q; `--crud` when create/
  update/delete exist). Fail-closed on missing client, no list op, or
  unmappable required fields
- **`--sync`** — refresh unchanged generated files via
  `.chico/generate_manifest.yaml`; refuses user-edited files (use `--force`)
- **`generate auth session`** — token store, SessionAuth façade for API bearer
  hooks, and `AppConfig` flavors via `--dart-define=ENV=dev|staging|prod`

### Fixed

- OpenAPI client no longer emits unused multipart helpers when the spec has no
  multipart ops; void responses no longer bind an unused `response` variable
  (keeps `flutter analyze --fatal-infos` clean)

### Docs

- GENERATOR_GUIDE / COOKBOOK / MANUAL_RELEASE_TEST §2.2 updated for `--from-api`

## 1.0.0

### Added

- First stable release of `chico_flutter_devkit` (`devkit` CLI)
- Manual ecommerce release walkthrough: [doc/MANUAL_RELEASE_TEST.md](doc/MANUAL_RELEASE_TEST.md)

### Notes

- Material-first create on Flutter ≥ 3.47 uses `material_ui` / `cupertino_ui`
  with gen-l10n delegate patching for analyze `--fatal-infos` on current stable
- OpenAPI generate remains fail-closed for unsupported constructs
- Feature scaffolds ship with demo in-memory datasources (wire your API client
  when ready)
- Prerelease history: `1.0.0-dev.1` … `1.0.0-dev.27`

## 1.0.0-dev.27

### Fixed

- gen-l10n Material UI patch also drops unused `flutter/widgets` and
  `flutter_localizations` imports (CI `analyze --fatal-infos`)

## 1.0.0-dev.26

### Fixed

- Feature Home link adds `go_router` import when the page uses `material_ui`
  (fixes `context.go` undefined on Flutter 3.50 e2e)
- Patch gen-l10n `GlobalMaterial`/`GlobalCupertino` delegates onto `material_ui`
  after create so analyze `--fatal-infos` stays clean

## 1.0.0-dev.25

### Fixed

- `dart format` on files from the Material UI migration (CI format gate)

## 1.0.0-dev.24

### Fixed

- **Flutter 3.50 Material deprecation:** Material-first `create` on Flutter ≥ 3.47
  uses `package:material_ui` (+ `dart fix migrate_design_widgets` after gen-l10n)
  so `flutter analyze --fatal-infos` passes on current stable CI

## 1.0.0-dev.23

### Fixed

- README / example doc links use absolute GitHub URLs so dartdoc on pub.dev does
  not warn on broken relative paths

## 1.0.0-dev.22

### Added

- **Trust freeze** checklist in `doc/RELEASE.md` (Phase 8 gates before `1.0.0`)

### Fixed

- Publish hygiene: ignore/remove JVM crash dumps; drop stale gitignored OpenAPI
  fixture that triggered pub dry-run warnings

## 1.0.0-dev.21

### Added

- **Stability CI:** multi-OS `create` → `flutter build apk --debug`, plus Ubuntu
  `--chico` APK smoke (`.github/workflows/ci.yml`)
- **Android matrix doc** (`doc/ANDROID.md`) — compileSdk / AGP /
  `chico_services` / `permission_handler`
- Default `chico_services` constraint raised to `^1.4.1`

### Fixed

- Drop deprecated `synthetic-package` from generated `l10n.yaml` (Flutter 3.44+)

## 1.0.0-dev.20

### Added

- **OpenAPI HTTP Basic** auth (`username` / `password` → `Authorization: Basic`)
- **OpenAPI multipart/form-data** uploads (`List<int>` file parts + form fields)
- Docs/matrix updated for the expanded OpenAPI subset

## 1.0.0-dev.19

### Added

- **Navigator routing:** `--routing navigator` scaffolds Navigator 1.0 named
  routes (`AppRouter.routes` + feature map); feature Home links use
  `Navigator.pushNamed`
- Docs refreshed for Phases 1–4 (README, troubleshooting, cookbook, architecture)

## 1.0.0-dev.18

### Added

- **Real localization:** create writes `l10n.yaml` + ARB files, enables
  `flutter gen-l10n`, adds `flutter_localizations` / `intl`, and wires
  `AppLocalizations` into Material/Chico roots and Home
- `--locales` multi-option for ARB languages (default `en`)

## 1.0.0-dev.17

### Added

- **DI depth:** get_it `core_module` + feature registrations; Riverpod
  `appContainer` / `UncontrolledProviderScope` + feature provider barrel;
  manual `AppServices` + `FeatureFactories`
- Feature pages resolve the graph via `getIt<>()` or `FeatureFactories` when
  those DI modes are selected

## 1.0.0-dev.16

### Changed

- **Create is Material-first:** `--chico-ui` / `--chico-kit` / `--chico-services`
  default off; use `--chico` (or interactive confirm / `setup chico`) to opt in
- Material apps get `AppTheme` wired into `MaterialApp` and a clearer home page

## 1.0.0-dev.15

### Added

- **Feature loop:** generated features ship with seeded in-memory data, a wired
  list page (bloc/cubit/provider/riverpod), GoRoute registration, get_it hooks,
  and a Home link — open `/features/<name>` with no hand-wiring

### Changed

- Create overlays include `feature_routes.dart` / `feature_registrations.dart`
  and ProviderScope when Riverpod is selected

## 1.0.0-dev.14

### Fixed

- Remove hardcoded `1.0.0-dev.10` from README / example / docs (pub.dev was
  showing a stale version)
- Add `version_sync_test` so pubspec ↔ `packageVersion` and shipping docs cannot
  drift again

## 1.0.0-dev.13

### Fixed

- Generated unit tests use `package:flutter_test/flutter_test.dart` (Flutter apps
  do not depend on `package:test`)
- Screen/widget tests that wrap with `ChicoApp` now import `chico_kit` /
  `chico_ui` so `flutter analyze` on `test/` succeeds
- Keep `lib/src/core/version.dart` in sync with `pubspec.yaml` (`1.0.0-dev.13`)

## 1.0.0-dev.12

### Notes

- On Flutter 3.44 / AGP 9.0.1, resolve `chico_services` **≥ 1.4.1**
  (`flutter pub upgrade chico_services`). 1.4.0 pulled `permission_handler` 13
  (`compileSdk 37`); 1.4.1 caps it so apps keep Flutter’s default compileSdk 36.
- Default constraint remains `^1.4.0` (allows 1.4.1+).

## 1.0.0-dev.11

### Changed

- Default `chico_services` constraint to `^1.4.0` (Built-in Kotlin / AGP 9
  plugin floors; requires Flutter ≥ 3.44)

## 1.0.0-dev.10

### Added

- Full user documentation hub on pub.dev: expanded README, Getting Started,
  Create App, Command Reference, Cookbook, Troubleshooting, and richer
  Generator Guide / example README

## 1.0.0-dev.9

### Added

- `example/` directory with a runnable public-API snippet for pub.dev documentation scoring

### Notes

- Ensure the GitHub repository is public so homepage/repository/issue tracker URLs resolve on pub.dev

## 1.0.0-dev.8

### Fixed

- Repository generator fails closed when entity/model/datasources are missing
- Chico UI generators require declared pubspec deps (optional `--add-missing-chico`)
- ChicoDependencyGuard rejects incompatible / malformed version constraints (never overwrites existing)
- SafeFileSystem stages writes and rolls back on mid-batch failure
- Doctor `--fix` re-inspects and reports remaining issues
- Pub package docs layout: `docs/` → `doc/`
- Generated feature messaging clarifies scaffold vs complete CRUD
- Widget/screen tests wrap with `ChicoApp` when Chico is enabled
- OpenAPI generation fails closed on `oneOf` / `anyOf` / discriminator / OAuth2 / OIDC / Basic / unknown schemes (no silent empty models or AuthType.none)

### Added

- Tagged Flutter E2E suite (`dart test -t flutter_e2e`) with file/content assertions
- Focused E2E: repository fail-closed + widget under feature-first/cubit
- OpenAPI support validator + fixture matrix (`OPENAPI_SUPPORT_MATRIX.md`)
- Expanded OpenAPI fixture (GET/POST/PUT/PATCH/DELETE, nested models)

## 1.0.0-dev.7

### Added

- Phase 7 OpenAPI client generation + release polish:
  - `devkit generate api <name> --spec openapi.yaml|.json`
  - OpenAPI 3.x subset parser (paths, schemas, params, JSON bodies, bearer/apiKey)
  - Isolated output under `lib/api/<name>/generated/` for safe regeneration
  - Models, client, auth config, exception types, pagination detection
  - Release checklist and OpenAPI docs

## 1.0.0-dev.6

### Added

- Phase 6 doctor and quality commands:
  - `devkit doctor` with category report, `--json`, and safe `--fix`
  - `devkit analyze` / `format` / `test` / `clean`
  - `devkit upgrade` for DevKit-managed Chico dependency constraints
  - Injected `ToolRunner` / `FakeToolRunner` for hermetic tests

## 1.0.0-dev.5

### Added

- Phase 5 project creation and Chico integrations:
  - `devkit create <name>` with architecture/state/routing/DI/Chico flags
  - Interactive prompts when a terminal is available
  - Starter overlay: main/app/theme/router/DI/home/error/logging/l10n/README
  - Example feature generation
  - `devkit add chico_ui|chico_kit|chico_services`
  - `devkit setup chico` with verified bootstrap helper
  - Pubspec dependency editor (`yaml_edit`)

## 1.0.0-dev.4

### Added

- Phase 4 generators:
  - `bloc`, `cubit`, `provider` (ChangeNotifier or Riverpod via `--state`)
  - `repository`, `service`
  - `enum` (`--values`), `extension` (`--on`), `test` (`--kind`, `--target`)
- Shared state-code builder for consistent state scaffolding
- CLI options: `--values`, `--on`, `--kind`, `--target`

## 1.0.0-dev.3

### Added

- Phase 3 generators:
  - `devkit generate feature` (clean / feature_first / layered)
  - `devkit generate model` (`--fields`, `--from-json`)
  - `devkit generate widget` (shared or `--feature` local)
  - `devkit generate screen`
- Feature options: `--crud`, `--pagination`, `--search`, `--filters`,
  `--local`, `--remote` / `--no-remote`, `--tests` / `--no-tests`
- Chico-aware widget/screen output when integrations are enabled
- Generator guide documentation

## 1.0.0-dev.2

### Added

- Phase 2 generation infrastructure:
  - Naming utilities (`NameConverter`) for snake/camel/pascal/kebab conversion
  - Safe filesystem manager with dry-run, backups, overwrite protection, and
    path traversal guards
  - Template engine (`{{var}}`, `{{#if}}`, `{{#unless}}`, `{{#each}}`)
  - Template catalog + `_fixture` template for tests
  - Generator contract, registry, runner, and `BaseGenerator`
  - Real `devkit generate` command wired to the registry (`--dry-run`, `--force`)
  - `devkit list --type generators` reads the live registry
- Template development documentation

## 1.0.0-dev.1

### Added

- Phase 1 foundation for Chico Flutter DevKit.
- CLI executable entrypoint `devkit` with banner, `--help`, and `--version`.
- Consistent exit codes for success, usage, config, not-implemented, and failure.
- Structured logging via `mason_logger`.
- Versioned configuration model (`schemaVersion: 1`) with defaults, validation,
  merge (defaults → user → project → CLI overrides), and serialization.
- `devkit config show|init|set|path`
- `devkit list`
- Stub commands for Phases 3–6: `create`, `generate`, `doctor`, `analyze`,
  `format`, `test`, `clean`, `upgrade`, `add`, `setup`
- Unit and CLI tests for configuration and command wiring.
- Architecture and configuration documentation.
