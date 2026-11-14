# Chico Flutter DevKit

Professional Flutter development toolkit — project creation, code generation,
diagnostics, and Chico ecosystem integration.

**CLI command:** `devkit`

**Status:** Stabilization (`1.0.0-dev.9`) — see [Getting started](doc/GETTING_STARTED.md) and the [release checklist](doc/RELEASE.md).

## What works today

- Full generator suite (`feature`, `model`, `widget`, `screen`, state, repository, …)
- `devkit create <name>` Flutter app factory + Chico integrations
- `devkit add chico_*` / `devkit setup chico`
- `devkit doctor` diagnostics with safe `--fix`
- `devkit analyze` / `format` / `test` / `clean` / `upgrade`
- `devkit generate api` from OpenAPI 3.x specs

## Install (development)

```bash
dart pub get
dart run bin/devkit.dart --help
```

Global activation (once published):

```bash
dart pub global activate chico_flutter_devkit
devkit --help
```

## Quick start

```bash
# Create an app
dart run bin/devkit.dart create shop_app --architecture clean --state bloc --no-interactive

# Or configure an existing project
dart run bin/devkit.dart config init --name shop_app
dart run bin/devkit.dart setup chico
dart run bin/devkit.dart generate feature products --dry-run
dart run bin/devkit.dart doctor
dart run bin/devkit.dart analyze
dart run bin/devkit.dart generate api shop --spec openapi.yaml --dry-run
```

## Chico packages

Apps created with DevKit (or configured via `setup chico`) can integrate these
published packages:

| Package | Default constraint | Notes |
|---------|--------------------|--------|
| `chico_ui` | `^1.7.0` | `ChicoApp`, design system widgets |
| `chico_kit` | `^1.4.0` | Helpers; re-exports `chico_ui` |
| `chico_services` | `^1.3.0` | `ChicoServices.init(baseUrl: …)` |

Versions are configurable in `.chico/devkit.yaml`.

## Documentation

- [Getting started](doc/GETTING_STARTED.md)
- [Architecture](doc/ARCHITECTURE.md)
- [Configuration](doc/CONFIGURATION.md)
- [Generator guide](doc/GENERATOR_GUIDE.md)
- [OpenAPI clients](doc/OPENAPI.md)
- [OpenAPI support matrix](OPENAPI_SUPPORT_MATRIX.md)
- [Release checklist](doc/RELEASE.md)
- [Template development](doc/TEMPLATE_DEVELOPMENT.md)
- [Changelog](CHANGELOG.md)

## Development

```bash
dart format .
dart analyze
dart test
```

## License

MIT
