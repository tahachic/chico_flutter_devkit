# Chico Flutter DevKit — examples

Most users should install the CLI:

```bash
dart pub global activate chico_flutter_devkit
devkit --help
devkit create shop_app --architecture clean --state bloc --no-interactive
```

## Library snippet

`devkit_example.dart` shows a tiny use of the public Dart API
(`NameConverter`, package identity). Run it from this folder:

```bash
dart pub get
dart run devkit_example.dart
```
