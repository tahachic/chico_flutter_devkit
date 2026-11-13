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

Manual smoke:

```bash
dart pub global activate --source path .
devkit --version
devkit --help
devkit create demo_app --no-interactive
cd demo_app
devkit doctor
devkit generate feature products --dry-run
```

## Publish

1. Clear CRITICAL/HIGH silent-success defects
2. Bump `pubspec.yaml` / `lib/src/core/version.dart` to the release version
3. Update `CHANGELOG.md`
4. Tag the release (`v1.0.0`) — **manual only**
5. `dart pub publish`
6. Verify `dart pub global activate chico_flutter_devkit`

## Notes

- Keep Chico package constraints configurable; do not invent Chico APIs
- Prefer `1.0.0` only after Windows + macOS/Linux validation
- This toolkit will not auto-publish or auto-tag
