# Template development

## Current release model (Option B)

Generators are **code-backed**: they emit Dart source from typed builders in
`lib/src/generators/**`. They do **not** load the empty architecture folders
that previously shipped under `templates/`.

Shipped template assets:

```text
templates/
  README.md
  _fixture/          # engine + catalog unit tests only
```

The Mustache-like `TemplateEngine` remains available for future asset-driven
generators and for fixture tests.

## Adding a generator

1. Implement `Generator` (or extend `BaseGenerator`)
2. Register it in `createDefaultGeneratorRegistry()`
3. Validate prerequisites (deps / existing files) before writing
4. Add focused unit tests under `test/generators/`

## Future Option A

If the project later adopts external `.tmpl` catalogs again, place them under
`templates/<id>/` with a `template.yaml` descriptor and wire them through
`TemplateCatalog`. Do not reintroduce empty placeholder directories.
