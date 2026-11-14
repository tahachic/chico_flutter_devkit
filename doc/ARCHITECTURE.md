# Architecture

Contributor-oriented overview of how the DevKit CLI is structured.
New users should start with [GETTING_STARTED.md](GETTING_STARTED.md).

## Purpose

Chico Flutter DevKit (`devkit`) is a pure Dart CLI that accelerates Flutter
development without depending on AI coding agents. It creates projects,
generates features, integrates Chico packages, and runs diagnostics.

## Package shape

```
bin/devkit.dart                 # process entry
lib/
  chico_flutter_devkit.dart     # public exports
  src/
    cli/                        # argument parsing + thin command handlers
    core/                       # logging, errors, version, banner
    config/                     # typed config, merge, validate, migrate
    fs/                         # safe filesystem (dry-run, backups, rollback)
    naming/                     # identifier conversion
    template/                   # template engine (fixture-backed tests)
    generators/                 # code-backed generators + registry
    project/                    # project factory + starters
    integrations/chico/         # verified Chico adapters
    doctor/                     # diagnostics + safe fixes
    quality/                    # analyze/format/test/clean/upgrade
    openapi/                    # OpenAPI 3.x subset parser + IR
templates/                      # `_fixture` only (generators are code-backed)
doc/
test/
```

## Design rules

1. **Commands stay thin** — parse → resolve config → call services → print.
2. **Generators never print** — they return structured results.
3. **Config is the source of truth** — CLI flags override in memory only.
4. **No invented Chico APIs** — adapters emit only documented boot/init calls.
5. **Safe by default** — no silent overwrites; backups + batch rollback preferred.
6. **No silent success with broken output** — generators validate prerequisites.

## Configuration merge order

1. Built-in defaults  
2. User config (`~/.chico/devkit.yaml`)  
3. Project config (`.chico/devkit.yaml`)  
4. CLI overrides for the current invocation  

## Chico integration facts (verified)

| Package | Version | Boot / init |
|---------|---------|-------------|
| `chico_ui` | `^1.7.0` | `ChicoApp` / `ChicoApp.router` |
| `chico_kit` | `^1.4.0` | import only (re-exports UI) |
| `chico_services` | `^1.4.0` | `await ChicoServices.init(baseUrl: …)` |

Requires Dart `^3.8` and Flutter `>=3.32`.

## Roadmap status

Phases 1–7 are implemented. Current focus is release stabilization (see
`AUDIT_REPORT.md` and `RELEASE_READINESS_REPORT.md`).

## Generation pipeline

```text
CLI generate
  → GeneratorRunner
    → resolve config + overrides
    → GenerationContext
    → Generator.validate (prereqs / Chico deps)
    → Generator.generate → PlannedFileWrite[]
    → SafeFileSystem.applyWrites (stage → commit → rollback on failure)
    → GenerationResult
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Execution failure |
| 64 | Invalid usage |
| 65 | Configuration error |
| 66 | Not implemented |
