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

1. Commit package sources (see commit candidate list in `FINAL_RELEASE_VERIFICATION.md`).
2. Prove GitHub Actions green (unit ×3 OS + Ubuntu E2E).
3. Re-run publish dry-run on clean tree.
4. Manual version bump — **not** done in this sprint.

---

## Do not

- Auto-publish
- Create git tags
- Bump to `1.0.0` without owner approval
