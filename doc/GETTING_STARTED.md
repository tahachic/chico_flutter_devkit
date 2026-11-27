# Getting started

This guide takes you from zero to a running Flutter app with DevKit generators.

## 1. Prerequisites

- Flutter SDK on `PATH` (`flutter --version`)
- Dart SDK (comes with Flutter) `^3.8.0`
- Git (recommended)

## 2. Install DevKit

```bash
dart pub global activate chico_flutter_devkit
devkit --version   # prints the installed package version
```

### Windows note

| Shell | How to invoke |
|-------|----------------|
| CMD / PowerShell | `devkit …` |
| Git Bash | `devkit.bat …` |

If the command is not found, add Pub’s bin folder to `PATH`:

`%LOCALAPPDATA%\Pub\Cache\bin`

## 3. Create your first app

```bash
devkit create shop_app \
  --architecture clean \
  --state bloc \
  --routing go_router \
  --di get_it \
  --org com.example \
  --no-interactive

# Optional Chico design system:
#   devkit create shop_app --chico --no-interactive
# or later:  devkit setup chico

cd shop_app
```

What this does:

1. Runs `flutter create`
2. Overlays DevKit starter files (`main.dart`, `app.dart`, router, DI, home)
3. Adds stack dependencies (Material-first; Chico only with `--chico`)
4. Sets up `flutter gen-l10n` (`l10n.yaml` + ARB) unless `--no-localization`
5. Writes `.chico/devkit.yaml`
6. Optionally generates an `example` feature
7. Runs `flutter pub get`

Details: [CREATE_APP.md](CREATE_APP.md)

## 4. Verify the project

```bash
devkit doctor
flutter analyze --fatal-infos
flutter test
flutter run
```

## 5. Generate your first feature

```bash
devkit generate feature products --crud --pagination --search --local
```

This writes a **scaffold** under `lib/features/products/` (entity, model,
datasources, repository, use case, Bloc, page, widget, tests).

Open the CLI summary: it reports how many methods still need your implementation.

Then analyze:

```bash
devkit analyze
```

## 6. Add a model and a screen

```bash
devkit generate model Product --fields id:String,name:String,price:double?,inStock:bool
devkit generate screen ProductDetails --feature products
```

## 7. OpenAPI → runnable screen (optional)

One command generates the API client and wires the feature remote datasource:

```bash
# Place your OpenAPI file at openapi/shop_api.yaml first
devkit generate feature catalog --spec openapi/shop_api.yaml --api-name shop --pagination --search
flutter analyze --fatal-infos
flutter test
```

Or two steps: `generate api shop --spec …` then `generate feature catalog --from-api shop`.
Do not pass `--spec` and `--from-api` together.

## 8. Auth session + login UI (optional)

```bash
devkit generate auth session --ui
```

Adds a `flutter_secure_storage`-backed session store, stub sign-in, preview
sign-out, `/login` page, and redirects unauthenticated `/features/*` to login
(go_router + get_it). Without `--ui`, only the token / `AppConfig` scaffold is
written. Create/adopt also wire Android/iOS ENV flavors (`--dart-define=ENV=`).

## 9. Common next steps

| I want to… | Do this |
|------------|---------|
| Preview without writing | add `--dry-run` |
| Overwrite generated files | add `--force` |
| Refresh unchanged gens (keep custom regions) | add `--sync` |
| Generate from JSON | `devkit generate model Product --from-json sample.json` |
| Generate an API client only | `devkit generate api shop --spec openapi.yaml` |
| Fix doctor issues | `devkit doctor --fix --yes` |
| See all generators | `devkit list generators` |

Continue with:

- [Cookbook](COOKBOOK.md) — full recipes (OpenAPI → screen, auth UI, sync)
- [Generator guide](GENERATOR_GUIDE.md) — every generator
- [Command reference](COMMAND_REFERENCE.md) — every command
- [Troubleshooting](TROUBLESHOOTING.md) — when something fails
