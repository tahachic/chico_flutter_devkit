# Examples

## Prefer the CLI

Most users never import this package as a library. Install and use the CLI:

```bash
dart pub global activate chico_flutter_devkit
devkit --help
devkit create shop_app --architecture clean --state bloc --no-interactive
cd shop_app
devkit generate feature products --crud --pagination
devkit doctor
```

Full guides (also linked from the package README on pub.dev):

- [Getting started](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GETTING_STARTED.md)
- [Cookbook](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COOKBOOK.md)
- [Generator guide](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/GENERATOR_GUIDE.md)
- [Command reference](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/COMMAND_REFERENCE.md)
- [Create an app](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/CREATE_APP.md)
- [Troubleshooting](https://github.com/tahachic/chico_flutter_devkit/blob/main/doc/TROUBLESHOOTING.md)

## Runnable library sample

`devkit_example.dart` shows a tiny slice of the public Dart API
(`NameConverter`, package identity, default config).

```bash
dart pub get
dart run devkit_example.dart
```

Expected output shape (version matches the installed package):

```text
Chico Flutter DevKit <packageVersion>
CLI executable: devkit
NameConverter: order_item → OrderItem / order_item / orderItem
Default stack: clean + bloc
```
