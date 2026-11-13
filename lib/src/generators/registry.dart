import '../core/exceptions.dart';
import 'api/api_generator.dart';
import 'enum_gen/enum_generator.dart';
import 'extension_gen/extension_generator.dart';
import 'feature/feature_generator.dart';
import 'generator.dart';
import 'model/model_generator.dart';
import 'repository/repository_generator.dart';
import 'screen/screen_generator.dart';
import 'service/service_generator.dart';
import 'state/bloc_generator.dart';
import 'state/cubit_generator.dart';
import 'state/provider_generator.dart';
import 'test_gen/test_generator.dart';
import 'widget/widget_generator.dart';

/// Registry of available generators.
final class GeneratorRegistry {
  GeneratorRegistry({Iterable<Generator> generators = const []}) {
    for (final generator in generators) {
      register(generator);
    }
  }

  final Map<String, Generator> _generators = {};

  void register(Generator generator) {
    final key = generator.name.trim().toLowerCase();
    if (key.isEmpty) {
      throw const ExecutionException('Generator name must not be empty.');
    }
    if (_generators.containsKey(key)) {
      throw ExecutionException('Generator "$key" is already registered.');
    }
    _generators[key] = generator;
  }

  bool contains(String name) => _generators.containsKey(name.toLowerCase());

  Generator? maybeGet(String name) => _generators[name.toLowerCase()];

  Generator get(String name) {
    final generator = maybeGet(name);
    if (generator == null) {
      final available = names.isEmpty
          ? 'none registered yet'
          : names.join(', ');
      throw InvalidUsageException(
        'Unknown generator "$name".',
        details: 'Available generators: $available',
      );
    }
    return generator;
  }

  List<String> get names => _generators.keys.toList(growable: false)..sort();

  List<Generator> get all =>
      names.map((name) => _generators[name]!).toList(growable: false);
}

/// Default registry for the shipped CLI.
GeneratorRegistry createDefaultGeneratorRegistry() {
  return GeneratorRegistry(
    generators: [
      ApiGenerator(),
      FeatureGenerator(),
      ModelGenerator(),
      WidgetGenerator(),
      ScreenGenerator(),
      BlocGenerator(),
      CubitGenerator(),
      ProviderGenerator(),
      RepositoryGenerator(),
      ServiceGenerator(),
      EnumGenerator(),
      ExtensionGenerator(),
      TestGenerator(),
    ],
  );
}
