# Pre-Commit Review — Chico Flutter DevKit

**Date:** 2026-11-13  
**Version under review:** `1.0.0-dev.8`  
**Mode:** Review only — **no** staging, commit, tag, publish, or source fixes applied  

Commands executed:

| Command | Exit | Notes |
|---------|------|-------|
| `git status --short` | 0 | 1 modified, 15 untracked roots |
| `git diff --check` | **2** | Trailing whitespace in `README.md` |
| `dart pub publish --dry-run` | **0** | 1 warning: dirty git (`README.md`) |
| Secret / credential filename scan | 0 | No `.env` / key / pem / credentials files found |

Only **`README.md`** is currently tracked (`git ls-files` count = 1). This is effectively a first package commit.

---

## 1. Files recommended for commit

### Must commit (package + CLI)

| Path | Why |
|------|-----|
| `pubspec.yaml` | Package identity / version `1.0.0-dev.8` |
| `analysis_options.yaml` | Analyzer config |
| `LICENSE` | MIT |
| `CHANGELOG.md` | Release notes for `1.0.0-dev.8` |
| `README.md` | User entrypoint (**after** trailing-whitespace fix) |
| `bin/` | `devkit` executable entry |
| `lib/` | Full implementation |
| `doc/` | User-facing documentation (`GETTING_STARTED`, `OPENAPI`, …) |
| `templates/` | Shipped fixture templates + `templates/README.md` |
| `test/` | Unit + E2E + OpenAPI fixtures |
| `.gitignore` | Ignore rules for Dart/Flutter/IDE/temp |

### Should commit (repo / CI — not required on pub.dev)

| Path | Why |
|------|-----|
| `.github/workflows/ci.yml` | Multi-OS unit + Ubuntu `flutter_e2e` |

### Optional commit (maintainer / process artifacts)

| Path | Why | Pub.dev note |
|------|-----|--------------|
| `OPENAPI_SUPPORT_MATRIX.md` | Useful normative subset matrix; linked from `doc/OPENAPI.md` | Reasonable to **include** on pub |
| `AUDIT_REPORT.md` | Internal audit trail | Prefer **git yes / pub no** |
| `RELEASE_READINESS_REPORT.md` | Internal gate | Prefer **git yes / pub no** |
| `FINAL_RELEASE_VERIFICATION.md` | Internal verification | Prefer **git yes / pub no** |
| `PRE_COMMIT_REVIEW.md` | This review | Prefer **git yes / pub no** |

Dry-run currently **includes** the audit/readiness/verification reports in the publish tarball. Recommend adding a `.pubignore` (in a follow-up change, not this review) so those stay in git but off pub.dev.

---

## 2. Files recommended for exclusion

### Already ignored / correctly excluded from publish

| Path | Status |
|------|--------|
| `.dart_tool/` | Ignored; present locally; **not** in dry-run |
| `pubspec.lock` | Ignored (appropriate for a library/CLI package); **not** in dry-run |
| `build/` | Ignored; absent locally |
| `.idea/`, `.vscode/`, `*.iml` | Ignored |
| `coverage/`, `*.lcov` | Ignored |
| `*.local.yaml`, `.tmp/`, `temp/`, `tmp/` | Ignored |
| OS junk (`.DS_Store`, `Thumbs.db`) | Ignored |

### Do not commit

| Item | Reason |
|------|--------|
| `.dart_tool/` | Tool cache |
| `pubspec.lock` | Library convention; regenerable |
| Any future `*.env`, credentials, keystores | Secrets |
| Temporary Flutter apps under system temp | Not in repo (E2E cleans up) |
| Agent / IDE local state outside repo | N/A |

### `.gitignore` vs important sources

`.gitignore` does **not** exclude `lib/`, `bin/`, `test/`, `doc/`, `templates/`, or `.github/`. No important source tree is accidentally ignored. Ignoring `pubspec.lock` for this package type is intentional and correct.

`.github/` is untracked and **not** listed in the publish dry-run (pub does not ship it) — still **commit it to git** for CI.

---

## 3. Security findings

| Finding | Severity | Notes |
|---------|----------|-------|
| Live API keys / passwords / tokens in tree | **None found** | Grep for credentials patterns + secret filenames |
| Hardcoded machine paths (`C:\Users\…`) in sources | **None found** | |
| OpenAPI / codegen `apiKey` / `bearerToken` | **OK** | Generated field names / fixtures only; no real secrets |
| Fixture `tokenUrl: https://example.com/token` | **OK** | Example URL |
| Local machine config committed | **None** | `.vscode` ignored; no user-specific config tracked |
| Temporary E2E projects in repo | **None** | |
| Build artifacts staged | **None** | `.dart_tool` / lockfile ignored |

No credential blockers for commit.

---

## 4. Documentation findings

### Version consistency (`1.0.0-dev.8`)

| File | Matches? |
|------|----------|
| `pubspec.yaml` | Yes |
| `lib/src/core/version.dart` | Yes |
| `CHANGELOG.md` top section | Yes |
| `README.md` status line | Yes |
| `AUDIT_REPORT.md` / readiness / verification / OpenAPI matrix | Yes |
| `LICENSE` | MIT; README says MIT — consistent (no version string required) |

### User docs vs internal reports

| Kind | Files | Audience |
|------|-------|----------|
| **User-facing** | `README.md`, `CHANGELOG.md`, `LICENSE`, `doc/*`, `OPENAPI_SUPPORT_MATRIX.md` (normative subset) | Package consumers |
| **Internal / process** | `AUDIT_REPORT.md`, `RELEASE_READINESS_REPORT.md`, `FINAL_RELEASE_VERIFICATION.md`, `PRE_COMMIT_REVIEW.md` | Maintainers / release gate |

**Issue:** README currently links `AUDIT_REPORT.md` / `RELEASE_READINESS_REPORT.md` as primary status docs. Fine for a private/prerelease repo; for pub.dev consumers prefer pointing at `doc/GETTING_STARTED.md` / `doc/RELEASE.md` and treating audit reports as maintainer-only (and ideally `.pubignore`d).

**Issue:** README line “Generated apps (Phase 5+)” is outdated phase wording (cosmetic).

**Issue:** `git diff --check` reports trailing whitespace on `README.md:6` (`devkit` line). Fix before commit.

### Publish dry-run

- Package name/version: `chico_flutter_devkit 1.0.0-dev.8`
- Includes: `lib/`, `bin/`, `doc/`, `test/`, `templates/`, changelog, license, analysis options, internal reports
- Excludes: `.dart_tool/`, `pubspec.lock`, `.github/`
- Warning: dirty git because `README.md` is modified vs the lone tracked commit — expected until a clean commit lands

---

## 5. Final commit recommendation

**Ready to commit after minor cleanup — not ready to publish `1.0.0`.**

### Before you approve staging

1. Fix `README.md` trailing whitespace (`git diff --check` currently fails).
2. Decide whether internal reports stay on pub.dev:
   - **Recommended:** commit them to git; add `.pubignore` for `AUDIT_REPORT.md`, `RELEASE_READINESS_REPORT.md`, `FINAL_RELEASE_VERIFICATION.md`, `PRE_COMMIT_REVIEW.md` in a small follow-up (not done here).
3. Soften README status links away from audit reports for consumer clarity (optional but preferred).

### Suggested first commit scope (when approved)

```text
.gitignore
.github/
analysis_options.yaml
pubspec.yaml
LICENSE
CHANGELOG.md
README.md
bin/
lib/
doc/
templates/
test/
OPENAPI_SUPPORT_MATRIX.md
AUDIT_REPORT.md
RELEASE_READINESS_REPORT.md
FINAL_RELEASE_VERIFICATION.md
PRE_COMMIT_REVIEW.md   # optional
```

### Explicitly do **not** do next without separate approval

- `git commit` / `git tag`
- `dart pub publish` (non-dry-run)
- Version bump to `1.0.0`

### Verdict

| Question | Answer |
|----------|--------|
| Safe to commit package sources? | **Yes**, after whitespace fix (+ optional `.pubignore` for internal reports) |
| Secrets / credentials blocking? | **No** |
| `.gitignore` excluding needed sources? | **No** |
| Docs/version aligned to `1.0.0-dev.8`? | **Yes** (minor README phase wording) |
| Await owner approval to stage/commit? | **Yes — waiting** |

---

*End of pre-commit review.*
