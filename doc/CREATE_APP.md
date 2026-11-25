# Create an app

```bash
devkit create <name> [options]
```

`<name>` must be a valid Dart package name (`shop_app`, not `ShopApp`).

Create is **Material-first**. Chico packages are opt-in via `--chico` (or
individual `--chico-*` flags), interactive confirm, or later
`devkit setup chico` / `devkit add`.

## Minimal examples

```bash
# Interactive prompts (when a terminal is available)
devkit create shop_app

# Non-interactive Material defaults (Clean + Bloc + go_router + get_it)
devkit create shop_app --no-interactive

# Same stack with full Chico (ui + kit + services)
devkit create shop_app --chico --no-interactive

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
| `--routing` | `go_router` (default), `navigator` | go_router or Navigator 1.0 named routes |
| `--di` | `get_it` (default), `riverpod`, `manual` | Full composition roots (modules / container / factories) |
| `--org` | `com.example` | Reverse-DNS for `flutter create` |
| `-o`, `--output` | `./<name>` | Target directory (must be empty/new) |
| `--platforms` | `android,ios,web` | Passed to `flutter create` (add `windows,macos,linux` as needed) |
| `--interactive` / `--no-interactive` | interactive on by default | Use `--no-interactive` in CI/scripts |
| `--chico` | off | Enable full Chico stack (ui + kit + services) |
| `--chico-ui` / `--no-chico-ui` | off | Toggle `chico_ui` (also implied by `--chico`) |
| `--chico-kit` / `--no-chico-kit` | off | Toggle `chico_kit` (also implied by `--chico`) |
| `--chico-services` / `--no-chico-services` | off | Toggle `chico_services` (also implied by `--chico`) |
| `--localization` / `--no-localization` | on | `flutter gen-l10n` (ARB + `l10n.yaml`) |
| `--locales` | `en` | Locales for ARB files (repeatable / comma-separated) |
| `--dark-mode` / `--no-dark-mode` | on | Theme helpers |
| `--logging` / `--no-logging` | on | Logger helper |
| `--error-handling` / `--no-error-handling` | on | Error type helper |
| `--example-feature` / `--no-example-feature` | on | Generate `example` feature |
| `--pub-get` / `--no-pub-get` | on | Run `flutter pub get` at the end |

With `--chico`, you can peel packages off with `--no-chico-ui`,
`--no-chico-kit`, or `--no-chico-services`.

## What gets created

Typical overlay (Material + go_router + get_it):

```text
shop_app/
  .chico/devkit.yaml
  lib/
    main.dart
    app.dart                      # MaterialApp.router + AppTheme
    core/
      di/injector.dart
      routing/app_router.dart
      theme/app_theme.dart
      …
    features/
      home/presentation/pages/home_page.dart
      example/…                   # when --example-feature
  test/widget_test.dart
  pubspec.yaml                    # + go_router, flutter_bloc, …
```

With `--chico`, overlays use `ChicoApp` / `ChicoScaffold`, add Chico pubspec
deps, and write `chico_bootstrap` helpers as needed.

## After create

```bash
cd shop_app
devkit doctor
flutter run

# Optional — add Chico later
devkit setup chico
```

## DI composition roots

| `--di` | What you get |
|--------|----------------|
| `get_it` | `core_module` + `feature_registrations`; pages resolve via `getIt<>()` |
| `riverpod` | `appContainer` + `UncontrolledProviderScope`; feature provider barrel |
| `manual` | `AppServices` / `ServiceLocator` + `FeatureFactories` for features |

## Localization

With `--localization` (default):

- `l10n.yaml` + `lib/l10n/app_<locale>.arb`
- `flutter_localizations` + `intl` + `flutter: generate: true`
- `MaterialApp` / `ChicoApp` wired to `AppLocalizations`
- Home uses generated strings (`welcomeMessage`, …)

Example: `devkit create shop_app --locales en --locales fr --no-interactive`

## Routing

| `--routing` | Behavior |
|-------------|----------|
| `go_router` | `MaterialApp.router` / `ChicoApp.router` + `featureRoutes` GoRoute list |
| `navigator` | `initialRoute` + named `routes` map; Home uses `Navigator.pushNamed` |

## Honest limitations

- ARB starter strings cover `en` / `fr` / `ar` / `es` / `de`; other locales copy English until you translate
