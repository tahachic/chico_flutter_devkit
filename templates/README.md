# Templates

Template assets for Chico Flutter DevKit generators.

Each template lives in its own folder:

```text
templates/
  <template_id>/
    template.yaml
    *.tmpl
```

See `doc/TEMPLATE_DEVELOPMENT.md`.

Generators in this release are **code-backed** (Dart emitters). The only
shipped template assets are under `_fixture/` for engine tests.
