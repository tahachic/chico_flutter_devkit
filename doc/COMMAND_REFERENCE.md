# Command reference

All commands share:

```text
devkit <command> [arguments]
  -h, --help
  -V, --version
      --verbose
      --quiet
```

Typical exit codes:

| Code | Meaning |
|------|---------|
| `0` | Success |
| `64` | Invalid usage (bad args / missing prerequisites) |
| `1` | Execution failure (tools, refused overwrite, analysis, …) |

---

## `create`

Create a Flutter application with DevKit overlays and optional Chico stack.

```bash
devkit create shop_app --architecture clean --state bloc --no-interactive
devkit create shop_app --output ../apps/shop_app --org com.acme --no-example-feature
```

See [CREATE_APP.md](CREATE_APP.md) for every flag.

---

## `generate`

```bash
devkit generate <type> <name> [flags]
```

**Types:** `feature`, `model`, `widget`, `screen`, `bloc`, `cubit`, `provider`,
`repository`, `service`, `enum`, `extension`, `test`, `api`

Shared flags:

| Flag | Meaning |
|------|---------|
| `--dry-run` | Plan only; write nothing |
| `-f`, `--force` | Allow overwrite (backups when configured) |
| `--tests` / `--no-tests` | Toggle companion tests (default on) |
| `--architecture` | `clean` \| `feature_first` \| `layered` |
| `--state` | `bloc` \| `cubit` \| `riverpod` \| `provider` |
| `--feature` | Place output inside a feature |
| `--add-missing-chico` | Add missing Chico deps for UI gens (never on dry-run) |

Full examples: [GENERATOR_GUIDE.md](GENERATOR_GUIDE.md)

---

## `config`

Manage `.chico/devkit.yaml`.

```bash
devkit config init --name shop_app
devkit config show
devkit config show --json
devkit config path
devkit config set project.architecture feature_first
devkit config set flutter.state_management cubit
```

Schema: [CONFIGURATION.md](CONFIGURATION.md)

---

## `doctor`

```bash
devkit doctor
devkit doctor --json
devkit doctor --fix          # show plan, ask confirmation
devkit doctor --fix --yes     # apply safe fixes, then re-inspect
```

Safe fixes include creating missing config, `analysis_options.yaml`, and `test/`.
After `--fix`, the report shows **issues fixed** vs **remaining**.

---

## `analyze` / `format` / `test` / `clean`

```bash
devkit analyze
devkit format
devkit test
devkit clean
```

These wrap Flutter/Dart tooling for the current project.

---

## `add`

Add one Chico package to an existing app.

```bash
devkit add chico_ui
devkit add chico_kit --version "^1.4.0"
devkit add chico_services --bootstrap --force
```

| Flag | Meaning |
|------|---------|
| `--version` | Pub constraint override |
| `--bootstrap` / `--no-bootstrap` | Write `lib/core/chico_bootstrap.dart` |
| `-f`, `--force` | Overwrite bootstrap |

---

## `setup`

Configure the Chico stack (ui + kit + services by default).

```bash
devkit setup chico
devkit setup chico --force
```

---

## `upgrade`

Update DevKit-managed Chico constraints in `pubspec.yaml` toward current defaults.

```bash
devkit upgrade --dry-run
devkit upgrade
```

---

## `list`

```bash
devkit list
devkit list commands
devkit list generators
```
