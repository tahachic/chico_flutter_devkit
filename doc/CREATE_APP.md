# Create an app

```bash
devkit create <name> [options]
```

`<name>` must be a valid Dart package name (`shop_app`, not `ShopApp`).

## Minimal examples

```bash
# Interactive prompts (when a terminal is available)
devkit create shop_app

# Non-interactive defaults (Clean + Bloc + go_router + get_it + Chico)
devkit create shop_app --no-interactive

# Feature-first + Cubit, custom org, custom output folder
devkit create catalog_app \
  --architecture feature_first \
  --state cubit \
  --org com.acme \
  --output ../apps/catalog_app \
  --no-interactive
```

## Options

| Flag | Values / default | Notes |
|------|------------------|-------|
| `--architecture` | `clean` (default), `feature_first`, `layered` | Folder layout for features |
| `--state` | `bloc` (default), `cubit`, `riverpod`, `provider` | State management deps + scaffolds |
| `--routing` | `go_router` only | Navigator is rejected with a clear error |
| `--di` | `get_it` (default), `riverpod`, `manual` | `get_it` is scaffolded; others are honest stubs |
| `--org` | `com.example` | Reverse-DNS for `flutter create` |
| `-o`, `--output` | `./<name>` | Target directory (must be empty/new) |
| `--interactive` / `--no-interactive` | interactive on by default | Use `--no-interactive` in CI/scripts |
| `--chico-ui` / `--no-chico-ui` | on | Toggle `chico_ui` |
| `--chico-kit` / `--no-chico-kit` | on | Toggle `chico_kit` |
| `--chico-services` / `--no-chico-services` | on | Toggle `chico_services` |
| `--localization` / `--no-localization` | on | Lightweight scaffold (not `gen-l10n`) |
| `--dark-mode` / `--no-dark-mode` | on | Theme helpers |
| `--logging` / `--no-logging` | on | Logger helper |
| `--error-handling` / `--no-error-handling` | on | Error type helper |
| `--example-feature` / `--no-example-feature` | on | Generate `example` feature |
| `--pub-get` / `--no-pub-get` | on | Run `flutter pub get` at the end |

## What gets created

Typical overlay (Chico + go_router + get_it):

```text
shop_app/
  .chico/devkit.yaml
  lib/
    main.dart
    app.dart
    core/
      di/injector.dart
      routing/app_router.dart
      theme/app_theme.dart
      chico_bootstrap.dart        # when Chico enabled
      …
    features/
      home/presentation/pages/home_page.dart
      example/…                   # when --example-feature
  test/widget_test.dart
  pubspec.yaml                    # + go_router, flutter_bloc, chico_*, …
```

## After create

```bash
cd shop_app
devkit doctor
flutter run
```

## Honest limitations

- Localization is a **lightweight string map**, not `flutter gen-l10n`
- Riverpod / manual DI generate **composition-root stubs** (documented TODOs)
- Only **go_router** routing is supported in this release
