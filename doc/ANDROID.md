# Android / plugin matrix

Notes for apps created with DevKit (especially with `--chico` / `chico_services`).
DevKit does not ship Android Gradle files itself — Flutter’s template + plugin
constraints determine compileSdk / AGP behavior.

## Current floors (Flutter stable)

| Layer | Typical value | Notes |
|-------|---------------|--------|
| Flutter | stable (3.x) | Apps inherit Flutter’s Android embedding |
| Dart SDK | `^3.8` (package) / Flutter’s bundled Dart | DevKit unit CI pins Dart 3.8.0 |
| AGP / Built-in Kotlin | Flutter template default | AGP 9.x is common on current stable |
| Default `compileSdk` | **36** on current Flutter templates | Do not raise unless a plugin requires it |

Exact AGP / NDK versions come from the Flutter SDK you install — run
`flutter doctor -v` in the app after create.

## Chico packages and Android

| Package | Default constraint | Android impact |
|---------|--------------------|----------------|
| `chico_ui` | `^1.7.0` | Pure Dart / Flutter widgets — no native plugins |
| `chico_kit` | `^1.4.0` | Re-exports UI — no native plugins |
| `chico_services` | `^1.4.1` recommended | Pulls plugins (e.g. `permission_handler`) |

### `chico_services` and `permission_handler`

- **`chico_services` 1.4.0** could resolve `permission_handler` **13**, which
  wants **compileSdk 37** — that conflicts with Flutter’s default **36** under
  AGP 9 / Built-in Kotlin.
- **`chico_services` ≥ 1.4.1** caps `permission_handler` below 13 so apps keep
  compileSdk 36.

DevKit defaults the services constraint to **`^1.4.1`**. After create:

```bash
flutter pub get
# Lockfile should resolve chico_services ≥ 1.4.1
```

If you must stay on an older services line, either:

- omit services: `devkit create app --chico --no-chico-services`, or
- add Chico later without services: `devkit add chico_ui` / `chico_kit` only

## Create modes vs Android risk

| Create flags | Native plugin surface |
|--------------|------------------------|
| Material default (no `--chico`) | Flutter template only — lowest risk |
| `--chico` | ui + kit + services — watch services / PH |
| `--chico --no-chico-services` | Design system without services plugins |

## CI smoke (this repo)

GitHub Actions (`.github/workflows/ci.yml`):

1. **unit** — Ubuntu / Windows / macOS (`dart test`, no Flutter)
2. **flutter_e2e** — Ubuntu tagged E2E
3. **create_apk** — each OS: `devkit create` (Material) → `flutter build apk --debug`
4. **create_apk_chico** — Ubuntu: `devkit create --chico` → debug APK

Use these jobs as the regression net for Android packaging breaks.

## Local smoke

```bash
dart pub global activate --source path .
devkit create android_smoke --no-interactive --no-example-feature
cd android_smoke
flutter build apk --debug

# Optional Chico path
devkit create chico_smoke --chico --no-interactive --no-example-feature
cd chico_smoke && flutter build apk --debug
```

## When builds fail

1. `flutter doctor -v` — missing Android SDK / licenses
2. Check `compileSdk` vs plugin requirements in the error log
3. With Chico services: ensure `chico_services` ≥ 1.4.1
4. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
