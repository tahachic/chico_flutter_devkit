# Changelog

All notable changes to this project will be documented in this file.

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
