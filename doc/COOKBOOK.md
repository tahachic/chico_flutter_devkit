# Cookbook

Copy-paste recipes for common DevKit workflows.

> Tip: add `--dry-run` to any `generate` command to preview files first.

---

## Create a Clean + Bloc shop app

```bash
devkit create shop_app --architecture clean --state bloc --no-interactive
cd shop_app
devkit doctor
flutter run
```

Material-first by default (no Chico). Add design system later with
`devkit setup chico`, or create with `--chico`.

---

## Create with Chico + French locale

```bash
devkit create shop_app --chico --locales en --locales fr --no-interactive
```

---

## Create with Riverpod DI (or manual factories)

```bash
devkit create river_app --state riverpod --di riverpod --no-interactive
devkit create manual_app --state bloc --di manual --no-interactive
```

---

## Create with Navigator 1.0 (no go_router)

```bash
devkit create nav_app --routing navigator --no-interactive
```

Feature Home links use `Navigator.pushNamed('/features/<name>')`.

---

## Android smoke (debug APK)

```bash
devkit create android_smoke --no-interactive --no-example-feature
cd android_smoke
flutter build apk --debug
```

Chico path and plugin floors: [ANDROID.md](ANDROID.md).

---

## Create a Feature-first + Cubit app without the example feature

```bash
devkit create catalog_app \
  --architecture feature_first \
  --state cubit \
  --no-example-feature \
  --no-interactive
```

---

## Generate a runnable feature (demo list)

```bash
devkit generate feature products \
  --crud \
  --pagination \
  --search \
  --filters \
  --local
```

Run the app and open **Home → Products** (route `/features/products`). You get
a seeded in-memory list with state wired. Replace the datasource with your API
(or an OpenAPI client) when you leave the demo stage.

---

## Generate a model from fields

```bash
devkit generate model Product \
  --fields id:String,name:String,price:double?,inStock:bool \
  --no-tests
```

Output: `lib/models/product.dart` with `fromJson` / `toJson` / `copyWith`.

---

## Generate a model from JSON

`sample_product.json`:

```json
{
  "id": "p1",
  "name": "Coffee",
  "price": 3.5,
  "tags": ["hot", "drink"],
  "createdAt": "2026-01-01T10:00:00.000Z"
}
```

```bash
devkit generate model Product --from-json sample_product.json
```

Nested objects become `Map<String, dynamic>` in this release.

---

## Feature-local widget and screen

```bash
devkit generate widget ProductCard --feature products
devkit generate screen ProductDetails --feature products
```

If Chico is enabled and packages are missing:

```bash
devkit generate widget ProductCard --feature products --add-missing-chico
# or
devkit add chico_ui
devkit add chico_kit
```

---

## Standalone state classes

```bash
devkit generate bloc Inventory --no-tests
devkit generate cubit Cart --feature products
devkit generate provider Session --state riverpod
```

---

## Repository into an existing feature

```bash
# 1) Feature first (creates entity/model/datasources/repository)
devkit generate feature orders --remote

# 2) Regenerate / extend repository later
devkit generate repository orders --feature orders --crud --force
```

Without the feature prerequisites, generation **fails closed** with a clear error
(exit `64`) and writes nothing.

---

## Service, enum, extension, test

```bash
devkit generate service NotificationService
devkit generate enum OrderStatus --values pending,shipped,delivered,cancelled
devkit generate extension StringX --on String
devkit generate test Product --kind unit --target model
devkit generate test ProductCard --kind widget --target widget
```

---

## OpenAPI client

```bash
devkit generate api shop --spec openapi.yaml
devkit generate api shop --spec openapi.yaml --base-url https://api.example.com --force
```

Regenerate safely — only files under `lib/api/shop/generated/` are replaced.
Keep wrappers **outside** `generated/`.

Auth helpers cover bearer, basic (`username`/`password`), and API keys.
Multipart operations emit `List<int>` file params + form fields.

Unsupported constructs (`oneOf`, OAuth2, …) abort with actionable errors.
See [OPENAPI.md](OPENAPI.md).

---

## OpenAPI → runnable screen (one command)

```bash
devkit generate feature products --spec openapi.yaml --api-name shop --pagination --search
devkit generate auth session --ui
```

Or wire an existing client:

```bash
devkit generate api shop --spec openapi.yaml
devkit generate feature products --from-api shop --pagination --search
devkit generate auth session
```

`--spec` / `--from-api` fail closed if the client is missing or fields cannot map.
Use `--sync` later to refresh unchanged generated files; edits inside
`// <devkit:custom id="…">` regions are preserved. Outside-region edits refuse
`--sync` (use `--force`). `devkit doctor` warns on `generate.manifest_drift`.

---

## Add Chico to an existing app

```bash
cd my_existing_app
devkit config init --name my_existing_app
devkit setup chico
flutter pub get
```

Or one package at a time:

```bash
devkit add chico_ui --bootstrap
devkit add chico_kit
devkit add chico_services
```

Verified boot pattern:

```dart
WidgetsFlutterBinding.ensureInitialized();
await ChicoServices.init(baseUrl: 'https://api.example.com');
runApp(const MyApp()); // typically ChicoApp / ChicoApp.router
```

---

## Doctor repair loop

```bash
devkit doctor
devkit doctor --fix --yes
devkit doctor          # confirm remaining issues
```

---

## Quality loop before a PR

```bash
devkit format
devkit analyze
devkit test
```

---

## Preview everything without writing

```bash
devkit generate feature products --dry-run
devkit generate api shop --spec openapi.yaml --dry-run
devkit upgrade --dry-run
```
