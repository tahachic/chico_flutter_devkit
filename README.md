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
# 1. Create a Flutter app (Clean Architecture + Bloc + Chico + go_router)
devkit create shop_app --architecture clean --state bloc --no-interactive
cd shop_app

# 2. Diagnose
devkit doctor

# 3. Generate a feature scaffold
devkit generate feature products --crud --pagination --search

# 4. Generate a model and a screen
devkit generate model Sku --fields id:String,code:String,price:double?
devkit generate screen SkuDetails --no-tests

# 5. Quality gates
devkit format
devkit analyze
devkit test
flutter run
```

Full walkthrough: [doc/GETTING_STARTED.md](doc/GETTING_STARTED.md)  
End-to-end recipes: [doc/COOKBOOK.md](doc/COOKBOOK.md)

---

## What you can do

| Goal | Command | Guide |
|------|---------|-------|
| Create a new app | `devkit create <name>` | [Create an app](doc/CREATE_APP.md) |
| Configure a project | `devkit config init` / `show` / `set` | [Configuration](doc/CONFIGURATION.md) |
| Add Chico packages | `devkit add` / `setup chico` | [Cookbook](doc/COOKBOOK.md#add-chico-to-an-existing-app) |
| Generate features, models, UI, state | `devkit generate …` | [Generator guide](doc/GENERATOR_GUIDE.md) |
| Generate OpenAPI clients | `devkit generate api` | [OpenAPI](doc/OPENAPI.md) |
| Diagnose / repair | `devkit doctor [--fix]` | [Command reference](doc/COMMAND_REFERENCE.md#doctor) |
| Analyze / format / test / clean | `devkit analyze` etc. | [Command reference](doc/COMMAND_REFERENCE.md) |
| Upgrade Chico constraints | `devkit upgrade` | [Command reference](doc/COMMAND_REFERENCE.md#upgrade) |
| List commands / generators | `devkit list` | [Command reference](doc/COMMAND_REFERENCE.md#list) |

---

## Documentation map

| Doc | Audience | Contents |
|-----|----------|----------|
| [Getting started](doc/GETTING_STARTED.md) | New users | Install, first project, first generate |
| [Create an app](doc/CREATE_APP.md) | New users | Every `create` flag with examples |
| [Command reference](doc/COMMAND_REFERENCE.md) | Everyone | All commands, flags, exit codes |
| [Generator guide](doc/GENERATOR_GUIDE.md) | Everyday use | Every generator with copy-paste examples |
| [Cookbook](doc/COOKBOOK.md) | Everyday use | Real workflows (feature, JSON model, OpenAPI, …) |
| [Configuration](doc/CONFIGURATION.md) | Everyday use | `.chico/devkit.yaml` schema |
| [OpenAPI clients](doc/OPENAPI.md) | API work | Supported subset + fail-closed rules |
| [OpenAPI support matrix](OPENAPI_SUPPORT_MATRIX.md) | API work | Construct-by-construct matrix |
| [Troubleshooting](doc/TROUBLESHOOTING.md) | When stuck | PATH, analyze, deps, repository prereqs |
| [Architecture](doc/ARCHITECTURE.md) | Contributors | How the CLI is structured |
| [Template development](doc/TEMPLATE_DEVELOPMENT.md) | Contributors | Template engine notes |
| [Release checklist](doc/RELEASE.md) | Maintainers | Publish gates |
| [Example](example/README.md) | pub.dev / library | Runnable public-API sample |
| [Changelog](CHANGELOG.md) | Everyone | Version history |

---

## Chico packages

Created apps (or `devkit setup chico`) can integrate:

| Package | Default constraint | Role |
|---------|--------------------|------|
| [`chico_ui`](https://pub.dev/packages/chico_ui) | `^1.7.0` | `ChicoApp`, design-system widgets |
| [`chico_kit`](https://pub.dev/packages/chico_kit) | `^1.4.0` | Helpers; re-exports `chico_ui` |
| [`chico_services`](https://pub.dev/packages/chico_services) | `^1.4.0` (≥ **1.4.1** on Flutter 3.44) | `ChicoServices.init(baseUrl: …)` |

Versions are configurable in `.chico/devkit.yaml`. UI generators **fail closed**
if required Chico deps are missing (or use `--add-missing-chico`).

---

## Safety defaults

- **No silent overwrites** — re-generation refuses unless `--force`
- **`--dry-run`** — preview files without writing
- **Backups** — overwrite can keep `.bak.*` files (config)
- **Repository generator** — requires an existing feature; never emits broken imports
- **OpenAPI** — unsupported constructs (`oneOf`, OAuth2, …) abort with clear errors
- **Features are scaffolds** — TODOs / `UnimplementedError` where you must wire real code

---

## Library example

Most people use the CLI. The package also exposes a Dart API:

```bash
cd example
dart pub get
dart run devkit_example.dart
```

See [example/README.md](example/README.md).

---

## Support

- Issues: [GitHub Issues](https://github.com/tahachic/chico_flutter_devkit/issues)
- Source: [GitHub Repository](https://github.com/tahachic/chico_flutter_devkit)

## License

MIT
