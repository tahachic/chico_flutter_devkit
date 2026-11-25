# Manual release test guide — ecommerce shop app

Use this checklist **before** publishing a stable release. Goal: prove DevKit can
scaffold a realistic shop app end-to-end on a real machine, not only CI.

**Pass rule:** every step you run must leave a checkable artifact (app runs,
analyze clean, or documented intentional failure). Mark `[ ]` → `[x]`.

**Suggested host:** Windows + one of Linux/macOS (or trust green CI `create_apk`
jobs for the second OS). Record Flutter version with `flutter --version`.

---

## 0. Prep

```bash
# Activate the candidate you intend to ship (path or pub prerelease)
dart pub global activate --source path /path/to/chico_flutter_devkit
# or: dart pub global activate chico_flutter_devkit

devkit --version          # expect the candidate version
devkit --help
which devkit || where devkit
```

- [ ] Version matches the release candidate
- [ ] On Git Bash (Windows): `devkit.bat` works if `devkit` does not

Work in a **writable** folder (not under Program Files / Git install roots):

```bash
mkdir -p ~/devkit_manual_qa && cd ~/devkit_manual_qa
```

---

## 1. Primary path — Material shop (Clean + Bloc + go_router)

This is the default “wow” path most users will hit.

### 1.1 Create

```bash
devkit create shop_app \
  --architecture clean \
  --state bloc \
  --routing go_router \
  --di get_it \
  --locales en \
  --locales fr \
  --no-example-feature \
  --no-interactive
cd shop_app
```

- [ ] Command exits 0
- [ ] Banner says Material-first (no Chico) or lists Chico only if you passed `--chico`
- [ ] `.chico/devkit.yaml` exists
- [ ] `pubspec.yaml` has `flutter_bloc`, `go_router`, `get_it`, **no** `chico_*`
- [ ] Flutter ≥ 3.47: `material_ui` / `cupertino_ui` present
- [ ] `lib/l10n/` + `l10n.yaml` exist (en + fr ARB)

### 1.2 Doctor + quality

```bash
devkit doctor
devkit format
devkit analyze
devkit test
```

- [ ] Doctor reports a coherent project (no CRITICAL false alarms)
- [ ] Format / analyze / test exit 0

### 1.3 Generate shop features (demo lists)

```bash
devkit generate feature products --crud --pagination --search --filters
devkit generate feature cart --crud
devkit generate feature orders --crud --pagination
devkit generate feature checkout
```

For each feature:

- [ ] Exit 0; summary mentions **in-memory** / demo data
- [ ] Home page gained a tile (open app later)
- [ ] Route registered under `/features/<name>`
- [ ] DI registration appended (get_it `feature_registrations.dart`)

Optional dry-run sanity:

```bash
devkit generate feature wishlist --dry-run
```

- [ ] Dry-run prints planned files and writes **nothing**

### 1.4 Models, screen, state, widget

```bash
devkit generate model Product \
  --fields id:String,name:String,price:double,inStock:bool,imageUrl:String? \
  --no-tests

devkit generate model CartItem \
  --fields id:String,productId:String,quantity:int,unitPrice:double \
  --no-tests

devkit generate screen ProductDetails --no-tests
devkit generate bloc Inventory --no-tests
devkit generate widget PriceTag --no-tests
```

- [ ] Files land under expected folders (`lib/models/`, pages, bloc, widgets)
- [ ] No generator crash; re-run without `--force` refuses overwrite

### 1.5 Repository fail-closed

```bash
devkit generate repository Orphan --no-tests ; echo exit:$?
```

- [ ] Non-zero exit
- [ ] Message mentions **prerequisites** / generate feature first

Then a valid path:

```bash
devkit generate repository products --feature products --crud --no-tests
```

- [ ] Succeeds against the existing products feature (or documents conflict clearly)

### 1.6 Run the app (manual UI)

```bash
flutter run
# or: flutter run -d windows / chrome / <device id>
```

On device/emulator:

- [ ] App starts; Home shows Welcome + feature links
- [ ] **Products** opens seeded list (not empty / not `UnimplementedError`)
- [ ]  Loading / empty / error states don’t crash if you briefly break the datasource
- [ ] **Cart** / **Orders** / **Checkout** routes open from Home
- [ ] Locale: if easy, switch device language to `fr` and confirm strings change (or call `AppLocalizations`)

### 1.7 Analyze after generation

```bash
flutter analyze --fatal-infos
flutter test
```

- [ ] Clean (or only pre-agreed infos documented)
- [ ] Widget/unit tests still pass

### 1.8 Android debug APK (mobile gate)

```bash
flutter build apk --debug
```

- [ ] APK builds (see [ANDROID.md](ANDROID.md) if plugins / compileSdk fail)

---

## 2. OpenAPI client — shop catalog API

Create a minimal supported spec (save as `openapi/shop_api.yaml`):

```yaml
openapi: 3.0.3
info:
  title: Shop API
  version: 1.0.0
servers:
  - url: https://api.shop.example.com/v1
paths:
  /products:
    get:
      operationId: listProducts
      parameters:
        - name: page
          in: query
          schema: { type: integer }
        - name: q
          in: query
          schema: { type: string }
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: array
                items: { $ref: '#/components/schemas/Product' }
    post:
      operationId: createProduct
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/ProductInput' }
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Product' }
  /products/{productId}:
    get:
      operationId: getProduct
      parameters:
        - name: productId
          in: path
          required: true
          schema: { type: string }
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Product' }
  /uploads:
    post:
      operationId: uploadProductImage
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              required: [file]
              properties:
                file: { type: string, format: binary }
                caption: { type: string }
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Product' }
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
  security:
    - bearerAuth: []
  schemas:
    Product:
      type: object
      required: [id, name, price]
      properties:
        id: { type: string }
        name: { type: string }
        price: { type: number }
        inStock: { type: boolean }
    ProductInput:
      type: object
      required: [name, price]
      properties:
        name: { type: string }
        price: { type: number }
        inStock: { type: boolean }
```

```bash
devkit generate api shop --spec openapi/shop_api.yaml --dry-run
devkit generate api shop --spec openapi/shop_api.yaml
```

- [ ] Dry-run then real generate succeed
- [ ] Client + models under `lib/api/shop/` (or configured output)
- [ ] Bearer / multipart methods present as expected

### 2.1 Fail-closed OpenAPI

```bash
# minimal unsupported snippet
cat > openapi/bad_oneof.yaml <<'EOF'
openapi: 3.0.3
info: { title: Bad, version: 1.0.0 }
paths:
  /x:
    get:
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                oneOf:
                  - { type: string }
                  - { type: integer }
EOF

devkit generate api bad --spec openapi/bad_oneof.yaml ; echo exit:$?
```

- [ ] Non-zero exit; error names `oneOf`; **no** partial files written

Full matrix: [OPENAPI_SUPPORT_MATRIX.md](../OPENAPI_SUPPORT_MATRIX.md).

### 2.2 Wire API into products remote datasource

Prefer one-shot `--spec` (fail-closed before writes):

```bash
# Fresh feature name if products already exists from §1.3.
devkit generate feature catalog --spec openapi/shop_api.yaml --api-name shop --pagination --search
flutter analyze --fatal-infos
flutter test
```

Or two-step (`--from-api`) when the client already exists:

```bash
devkit generate feature catalog --from-api shop --pagination --search --no-tests
```

- [ ] Command exits 0; summary mentions the API client (e.g. `ShopApi`)
- [ ] Remote datasource calls `listProducts` (not demo in-memory seeds)
- [ ] Home link / `/features/catalog` route present
- [ ] Mapping + use-case tests generated; `flutter test` passes
- [ ] Missing client / bad mapping fails closed (try `--from-api missing`)
- [ ] Custom region: edit inside `remote.map`, `--sync` preserves it; edit outside refuses
- [ ] `devkit doctor` shows `generate.manifest_drift` after an outside edit
- [ ] `devkit generate auth session --ui` → login page + `/features/*` guard; analyze clean
- [ ] Auth `--ui` with navigator or non–get_it refuses clearly

### 2.3 Brownfield adopt

```bash
# Separate folder: plain flutter create, then adopt
flutter create brown_app --platforms android,ios,web
cd brown_app
devkit adopt --architecture clean --state bloc --routing go_router --di get_it
flutter pub get
devkit generate feature products --no-tests
flutter analyze --fatal-infos
devkit upgrade scaffolds --dry-run
```

- [ ] Adopt writes `.chico/devkit.yaml` + anchors; unmarked Home refuses
- [ ] Feature generate + analyze clean after adopt
- [ ] `upgrade scaffolds` dry-run succeeds

---

## 3. Chico stack path

From a **new** directory (don’t reuse `shop_app`):

```bash
cd ~/devkit_manual_qa
devkit create chico_shop --chico --no-example-feature --no-interactive
cd chico_shop
devkit doctor
devkit generate feature products --crud --pagination
flutter analyze --fatal-infos
flutter build apk --debug
```

- [ ] `chico_ui` / `chico_kit` / `chico_services` in pubspec
- [ ] Root uses `ChicoApp` (not `MaterialApp`)
- [ ] `chico_services` ≥ 1.4.1 on Flutter 3.44+ Android (see [ANDROID.md](ANDROID.md))
- [ ] Feature Home link works with Chico list tile
- [ ] Debug APK builds

Add Chico to an existing Material app:

```bash
cd ../shop_app
devkit setup chico
# follow printed boot hints; flutter pub get
```

- [ ] Packages added; doctor reflects Chico

---

## 4. Alternate stacks (smoke, not full ecommerce)

Run each create in a fresh folder; stop after `flutter analyze --fatal-infos`
+ one feature generate (optional APK).

| Profile | Command | Checks |
|---------|---------|--------|
| Cubit + feature_first | `devkit create cubit_shop --architecture feature_first --state cubit --no-interactive --no-example-feature` | Cubit files; feature works |
| Riverpod | `devkit create river_shop --state riverpod --di riverpod --no-interactive --no-example-feature` | No `UnimplementedError`; Riverpod page |
| Provider | `devkit create provider_shop --state provider --no-interactive --no-example-feature` | Provider wiring |
| Manual DI | `devkit create manual_shop --di manual --no-interactive --no-example-feature` | `feature_factories` |
| Navigator 1.0 | `devkit create nav_shop --routing navigator --no-interactive --no-example-feature` | No `go_router`; `pushNamed` Home links |

- [ ] Cubit profile
- [ ] Riverpod profile
- [ ] Provider profile
- [ ] Manual DI profile
- [ ] Navigator profile

---

## 5. Config / upgrade / safety

```bash
cd shop_app
devkit config show
devkit config set flutter.state_management bloc
devkit list
devkit upgrade --dry-run
```

- [ ] Config show/set works
- [ ] `list` shows commands/generators
- [ ] Upgrade dry-run is non-destructive

Overwrite protection:

```bash
devkit generate model Product --fields id:String --no-tests
# second time without --force should refuse
devkit generate model Product --fields id:String --no-tests ; echo exit:$?
```

- [ ] Second generate refuses without `--force`

---

## 6. Cross-OS / release hygiene

| Check | How |
|-------|-----|
| Second OS | Repeat §1 create + feature + `flutter build apk --debug` on Linux/macOS, **or** confirm CI `create_apk` ×3 + `create_apk_chico` green on the release commit |
| Clean publish | From a clean git tree: `dart pub publish --dry-run` — no crash dumps, no gitignored-but-tracked surprises |
| Score | pub.dev Scores for latest prerelease: pana + dartdoc success (target 160/160) |
| Publisher | Verify publisher on pub.dev when ready |
| Version sync | `pubspec.yaml` and `lib/src/core/version.dart` match; shipping docs have **no** hardcoded `1.0.0-dev.N` |

- [ ] Second OS or CI APK matrix accepted
- [ ] Dry-run clean
- [ ] Score reviewed
- [ ] Publisher decision recorded
- [ ] Version sync OK

---

## 7. Sign-off template

```text
Tester: _______________
Date: _______________
Flutter: _______________
DevKit: _______________
OS #1: _______________  result: PASS / FAIL
OS #2 / CI APK: _______________  result: PASS / FAIL

Primary shop_app (§1): PASS / FAIL
OpenAPI (§2): PASS / FAIL
Chico (§3): PASS / FAIL
Alt stacks (§4): PASS / FAIL / PARTIAL
Hygiene (§6): PASS / FAIL

Blockers:
-
-

Approve stable publish?  YES / NO
```

---

## Related docs

- [CREATE_APP.md](CREATE_APP.md) — create flags
- [GENERATOR_GUIDE.md](GENERATOR_GUIDE.md) — generators
- [COOKBOOK.md](COOKBOOK.md) — short recipes
- [OPENAPI.md](OPENAPI.md) + [OPENAPI_SUPPORT_MATRIX.md](../OPENAPI_SUPPORT_MATRIX.md)
- [ANDROID.md](ANDROID.md) — compileSdk / `chico_services`
- [RELEASE.md](RELEASE.md) — trust freeze + publish steps
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
