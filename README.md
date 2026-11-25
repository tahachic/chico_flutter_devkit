# Chico Flutter DevKit

Professional Flutter development toolkit — create apps, generate Clean Architecture
features, integrate Chico packages, diagnose projects, and generate OpenAPI clients.

**CLI:** `devkit` · **License:** MIT · Version: run `devkit --version` (or see pub.dev)

> On **Git Bash (Windows)**, Pub installs `devkit.bat`. Use `devkit.bat …` or run
> commands from **CMD / PowerShell** where `devkit` works.

---

## Table of contents

1. [Install](#install)
2. [60-second quick start](#60-second-quick-start)
3. [What you can do](#what-you-can-do)
4. [Documentation map](#documentation-map)
5. [Chico packages](#chico-packages)
6. [Safety defaults](#safety-defaults)
7. [Library example](#library-example)
8. [Support](#support)

---

## Install

### Global (recommended)

```bash
dart pub global activate chico_flutter_devkit
devkit --version
devkit --help
```

Ensure Pub’s global bin folder is on your `PATH`
(`%LOCALAPPDATA%\Pub\Cache\bin` on Windows).

### From this repository (contributors)

```bash
dart pub get
dart run bin/devkit.dart --help
```

---

## 60-second quick start

```bash
# 1. Create a Flutter app (Clean + Bloc + go_router; Material by default)
devkit create shop_app --architecture clean --state bloc --no-interactive
# Opt in to Chico: add --chico  (or later: devkit setup chico)
cd shop_app

# 2. Diagnose
devkit doctor

# 3. Generate a feature scaffold (demo in-memory list)
devkit generate feature products --crud --pagination --search

# Or OpenAPI → API client + wired screen in one command:
#   devkit generate feature products --spec openapi/shop_api.yaml --api-name shop

# 4. Optional auth UI (login + /features/* guard)
#   devkit generate auth session --ui

# 5. Generate a model and a screen
devkit generate model Sku --fields id:String,code:String,price:double?
devkit generate screen SkuDetails --no-tests

# 6. Quality gates
devkit format
devkit analyze
devkit test
flutter run
```

Full walkthrough: [Getting started](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GETTING_STARTED.md)  
End-to-end recipes: [Cookbook](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COOKBOOK.md)

---

## What you can do

| Goal | Command | Guide |
|------|---------|-------|
| Create a new app | `devkit create <name>` | [Create an app](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/CREATE_APP.md) |
| Adopt an existing Flutter app | `devkit adopt` | [Cookbook](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COOKBOOK.md#adopt-an-existing-flutter-app) |
| Configure a project | `devkit config init` / `show` / `set` | [Configuration](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/CONFIGURATION.md) |
| Add Chico packages | `devkit add` / `setup chico` | [Cookbook](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COOKBOOK.md#add-chico-to-an-existing-app) |
| Generate features, models, UI, state | `devkit generate …` | [Generator guide](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GENERATOR_GUIDE.md) |
| OpenAPI → client | `devkit generate api --spec` | [OpenAPI](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/OPENAPI.md) |
| OpenAPI → runnable feature | `devkit generate feature --spec` | [Generator guide](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GENERATOR_GUIDE.md#openapi--runnable-screen-spec) |
| Auth session (+ login UI) | `devkit generate auth session [--ui]` | [Generator guide](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GENERATOR_GUIDE.md#auth) |
| Safe regenerate | `generate … --sync` (custom regions) | [Generator guide](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GENERATOR_GUIDE.md#custom-regions) |
| Diagnose / repair | `devkit doctor [--fix]` | [Command reference](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COMMAND_REFERENCE.md#doctor) |
| Analyze / format / test / clean | `devkit analyze` etc. | [Command reference](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COMMAND_REFERENCE.md) |
| Upgrade Chico constraints | `devkit upgrade` | [Command reference](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COMMAND_REFERENCE.md#upgrade) |
| List commands / generators | `devkit list` | [Command reference](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COMMAND_REFERENCE.md#list) |

---

## Documentation map

| Doc | Audience | Contents |
|-----|----------|----------|
| [Getting started](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GETTING_STARTED.md) | New users | Install, first project, first generate |
| [Create an app](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/CREATE_APP.md) | New users | Every `create` flag with examples |
| [Command reference](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COMMAND_REFERENCE.md) | Everyone | All commands, flags, exit codes |
| [Generator guide](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GENERATOR_GUIDE.md) | Everyday use | Every generator with copy-paste examples |
| [Cookbook](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COOKBOOK.md) | Everyday use | Real workflows (feature, JSON model, OpenAPI, …) |
| [Configuration](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/CONFIGURATION.md) | Everyday use | `.chico/devkit.yaml` schema |
| [OpenAPI clients](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/OPENAPI.md) | API work | Supported subset + fail-closed rules |
| [OpenAPI support matrix](https://github.com/tahachic/chico_flutter_devkit/blob/main/OPENAPI_SUPPORT_MATRIX.md) | API work | Construct-by-construct matrix |
| [Android / plugins](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/ANDROID.md) | Mobile | compileSdk, AGP, `chico_services` / PH |
| [Troubleshooting](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/TROUBLESHOOTING.md) | When stuck | PATH, analyze, deps, repository prereqs |
| [Architecture](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/ARCHITECTURE.md) | Contributors | How the CLI is structured |
| [Template development](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/TEMPLATE_DEVELOPMENT.md) | Contributors | Template engine notes |
| [Release checklist](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/RELEASE.md) | Maintainers | Publish gates |
| [Manual release test](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/MANUAL_RELEASE_TEST.md) | Maintainers | Ecommerce shop QA before a stable ship |
| [Example](https://github.com/tahachic/chico_flutter_devkit/blob/main/example/README.md) | pub.dev / library | Runnable public-API sample |
| [Changelog](https://github.com/tahachic/chico_flutter_devkit/blob/main/CHANGELOG.md) | Everyone | Version history |

---

## Chico packages

Created apps opt in with `devkit create … --chico` or `devkit setup chico`:

| Package | Default constraint | Role |
|---------|--------------------|------|
| [`chico_ui`](https://pub.dev/packages/chico_ui) | `^1.7.0` | `ChicoApp`, design-system widgets |
| [`chico_kit`](https://pub.dev/packages/chico_kit) | `^1.4.0` | Helpers; re-exports `chico_ui` |
| [`chico_services`](https://pub.dev/packages/chico_services) | `^1.4.1` | `ChicoServices.init(baseUrl: …)` |

Versions are configurable in `.chico/devkit.yaml`. UI generators **fail closed**
if required Chico deps are missing (or use `--add-missing-chico`).

---

## Safety defaults

- **No silent overwrites** — re-generation refuses unless `--force`
- **`--dry-run`** — preview files without writing
- **Backups** — overwrite can keep `.bak.*` files (config)
- **Repository generator** — requires an existing feature; never emits broken imports
- **OpenAPI** — unsupported constructs (`oneOf`, OAuth2, …) abort with clear errors
- **`--sync`** — refreshes unchanged manifest files; preserves
  `// <devkit:custom id="…">` regions; refuses outside edits
- **Features ship a demo list** — seeded in-memory data + Home link; or wire with
  `--spec` / `--from-api`

---

## Library example

Most people use the CLI. The package also exposes a Dart API:

```bash
cd example
dart pub get
dart run devkit_example.dart
```

See [example/README.md](https://github.com/tahachic/chico_flutter_devkit/blob/main/example/README.md).

---

## Support

- Issues: [GitHub Issues](https://github.com/tahachic/chico_flutter_devkit/issues)
- Source: [GitHub Repository](https://github.com/tahachic/chico_flutter_devkit)

## License

MIT
