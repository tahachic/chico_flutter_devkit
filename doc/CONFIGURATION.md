# Configuration

DevKit uses a versioned YAML configuration file.

Related: [Getting started](GETTING_STARTED.md) · [Command reference](COMMAND_REFERENCE.md#config)

## Locations

| Scope | Path |
|-------|------|
| Project | `.chico/devkit.yaml` |
| User | `~/.chico/devkit.yaml` (`%USERPROFILE%\.chico\devkit.yaml` on Windows) |

## Merge order

Defaults → user → project → CLI overrides (in-memory only).

## Schema version

```yaml
schemaVersion: 1
```

Unsupported newer schemas fail with a clear upgrade message. Migrators will be
added when the schema advances.

## Example

```yaml
schemaVersion: 1

project:
  name: shop_app
  architecture: clean          # feature_first | clean | layered
  organization: com.example

flutter:
  state_management: bloc       # bloc | cubit | riverpod | provider
  routing: go_router           # go_router | navigator
  dependency_injection: get_it # get_it | riverpod | manual
  localization:
    enabled: true
    languages:
      - en
      - fr

chico:
  ui:
    enabled: true
    version: "^1.7.0"
  kit:
    enabled: true
    version: "^1.4.0"
  services:
    enabled: true
    version: "^1.3.0"

features:
  default_architecture: clean
  generate_tests: true
  generate_documentation: true

code_style:
  trailing_commas: true
  prefer_const: true
  line_length: 100

generation:
  overwrite: false
  create_backups: true
```

## Commands

```bash
devkit config init [--name NAME] [--organization ORG] [--force]
devkit config show [--json]
devkit config set <dotted.key> <value>
devkit config path [--user]
```

### `config set` examples

```bash
devkit config set project.architecture clean
devkit config set flutter.state_management riverpod
devkit config set generation.overwrite true
devkit config set flutter.localization.languages [en,fr,ar]
```

## Validation rules (Phase 1)

- `project.name` must be a valid Dart package name
- `project.organization` must look like reverse-DNS (`com.example`)
- `code_style.line_length` must be between 40 and 200
- Localization languages required when localization is enabled
- `chico.kit` requires `chico.ui`
- `chico.services` requires `chico.kit`
- Package version strings must look like pub constraints

## Defaults for Chico packages

| Package | Default constraint |
|---------|--------------------|
| `chico_ui` | `^1.7.0` |
| `chico_kit` | `^1.4.0` |
| `chico_services` | `^1.3.0` |
