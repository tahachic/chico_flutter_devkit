# Getting Started

## Install (local development)

```bash
dart pub get
dart run bin/devkit.dart --help
```

## Create a project

```bash
dart run bin/devkit.dart create shop_app \
  --architecture clean \
  --state bloc \
  --routing go_router \
  --di get_it \
  --org com.example \
  --no-interactive
```

This will:

1. Run `flutter create` (or a test double in unit tests)
2. Overlay DevKit starter files
3. Add stack + Chico dependencies
4. Write `.chico/devkit.yaml`
5. Optionally generate an example feature
6. Run `flutter pub get`

## Add Chico to an existing app

```bash
cd my_app
dart run /path/to/chico_flutter_devkit/bin/devkit.dart add chico_ui
dart run /path/to/chico_flutter_devkit/bin/devkit.dart setup chico
flutter pub get
```

Verified boot APIs:

```dart
await ChicoServices.init(baseUrl: 'https://api.example.com');
runApp(ChicoApp(home: home));
```

## Generate code

```bash
devkit generate feature products --crud --pagination
devkit generate model Product --fields id:String,name:String
```

## Diagnose and improve quality

```bash
devkit doctor
devkit doctor --fix --yes
devkit analyze
devkit format
devkit test
devkit clean
devkit upgrade --dry-run
```

## Generate an API client from OpenAPI

```bash
devkit generate api shop --spec openapi.yaml
```

See [OPENAPI.md](OPENAPI.md). Ready to publish? Follow [RELEASE.md](RELEASE.md).
