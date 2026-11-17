# Release checklist

Use this before publishing `chico_flutter_devkit` to pub.dev.

## Definition of success

A developer can, from a normal terminal **without any AI service**:

1. Install the toolkit (`dart pub global activate chico_flutter_devkit`)
2. Create a Flutter project with supported architecture/state (`go_router` routing)
3. Integrate `chico_ui`, `chico_kit`, and `chico_services`
4. Generate feature **scaffolds** (not turnkey CRUD)
5. Generate models and screens
6. Generate state-management components
7. Generate an API client from a supported OpenAPI 3.x subset
8. Run project diagnostics (`doctor`) with accurate post-fix status
9. Format / analyze / test / clean / upgrade
10. Manage configuration

Gate documents: `AUDIT_REPORT.md`, `RELEASE_READINESS_REPORT.md`.

## Pre-publish steps

```bash
dart format --set-exit-if-changed .
dart analyze
dart test
dart test -t flutter_e2e
dart pub publish --dry-run
```

CI (`.github/workflows/ci.yml`) should be green:

- **unit** × Ubuntu / Windows / macOS
- **flutter_e2e** (Ubuntu)
- **create_apk** × 3 OS (Material create → debug APK)
- **create_apk_chico** (Ubuntu, `--chico` → debug APK)

Android floors: [ANDROID.md](ANDROID.md).

Manual smoke:

```bash
dart pub global activate --source path .
devkit --version
devkit --help
devkit create demo_app --no-interactive
cd demo_app
devkit doctor
devkit generate feature products --dry-run
flutter build apk --debug   # optional local Android gate
```

## Publish

1. Clear CRITICAL/HIGH silent-success defects
2. Bump **both** `pubspec.yaml` and `lib/src/core/version.dart` to the same
   version (never docs-only version strings — `dart test` enforces sync)
3. Update `CHANGELOG.md`
4. Confirm shipping docs do **not** hardcode a package version string (README,
   example, `doc/`, `OPENAPI_SUPPORT_MATRIX.md`) — use `devkit --version` instead
5. Tag the release (`v1.0.0`) — **manual only**
6. `dart pub publish`
7. Verify `dart pub global activate chico_flutter_devkit` and `devkit --version`

## Trust freeze before `1.0.0` (Phase 8)

Do **not** bump to `1.0.0` until all of the following are true:

1. **Remote CI green** on the package commit: unit ×3 OS, `flutter_e2e`,
   `create_apk` ×3, `create_apk_chico`
2. **Manual smoke on ≥2 OS** (Windows + Linux or macOS): create → feature →
   analyze → debug APK (or documented skip)
3. **Clean publish dry-run** (no gitignored-but-tracked files; no crash dumps
   in the archive)
4. **pub.dev score card** reviewed for the latest prerelease (pana + dartdoc
   not failed/aborted; wait out `[pending analysis]` if needed)
5. **Publisher** verified on pub.dev (currently “unverified uploader”) when ready
6. **Owner approval** to leave prerelease — tagging `v1.0.0` is manual only

Prerelease ships continue as `1.0.0-dev.N` until that gate.

## Notes

- Keep Chico package constraints configurable; do not invent Chico APIs
- Prefer `1.0.0` only after Windows + macOS/Linux validation
- This toolkit will not auto-publish or auto-tag
- Do not auto-bump to `1.0.0`
