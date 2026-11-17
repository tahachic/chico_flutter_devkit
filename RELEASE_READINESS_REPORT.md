# Release Readiness Report

**Package:** `chico_flutter_devkit`  
**Version under test:** `1.0.0-dev.8`  
**Updated:** 2026-11-13 (OpenAPI correctness + dependency guard sprint)  

See also: `FINAL_RELEASE_VERIFICATION.md`, `OPENAPI_SUPPORT_MATRIX.md`, `AUDIT_REPORT.md`.

---

## Verdict

**READY AFTER MINOR FIXES** — not cleared for `1.0.0` until git commit + proven multi-OS CI.

Silent OpenAPI misgeneration and Chico constraint gaps identified in verification are **fixed** with **executed** regression tests on Windows.

---

## Findings fixed this sprint

| Issue | Fix | Evidence |
|-------|-----|----------|
| `oneOf` → empty object | `OpenApiSupportValidator` fail-closed | Unit **executed** |
| `oauth2` → `AuthType.none` | Reject unsupported schemes; never downgrade | Unit **executed** |
| Mixed supported/unsupported schemas | Nested walk rejects `oneOf` in properties | Unit **executed** |
| Misleading generated files on failure | Validate before writes; no `generated/` | Unit **executed** |
| Chico version conflicts | `pub_semver` intersection check | Unit **executed** |
| Overwrite existing constraints | add-missing only for absent packages | Unit **executed** |
| E2E exit-code-only | File/content asserts + focused second E2E | E2E **executed** (2 passed) |

---

## Quality gates (Windows host)

| Gate | Result |
|------|--------|
| `dart analyze` | Pass |
| `dart test --exclude-tags flutter_e2e` | **117 passed** |
| `dart test -t flutter_e2e` | **2 passed** |
| `dart pub publish --dry-run` | Exit 0; dirty-git warning |

Linux/macOS: **Configured only** (CI workflow).

---

## Remaining before `1.0.0`

See **Trust freeze** in `doc/RELEASE.md` (Phase 8). Summary:

1. Commit + push package sources; prove GitHub Actions green (unit ×3 OS,
   `flutter_e2e`, `create_apk` ×3, `create_apk_chico`).
2. Manual smoke on ≥2 OS.
3. Clean publish dry-run; review pub.dev score card for latest prerelease.
4. Manual version bump to `1.0.0` — **owner approval only** (never auto).

Enhancement Phases 1–8 (trust freeze docs + publish hygiene) shipped through
`1.0.0-dev.22`. `1.0.0` still requires owner approval after remote CI proof.

---

## Do not

- Auto-publish
- Create git tags
- Bump to `1.0.0` without owner approval
