import '../../config/models.dart';
import '../../naming/name_converter.dart';

/// Relative output paths for a feature under a given architecture.
final class FeatureLayout {
  FeatureLayout({required this.architecture, required NormalizedName name})
    : snake = name.snakeCase,
      pascal = name.pascalCase;

  final Architecture architecture;
  final String snake;
  final String pascal;

  /// Lower-camel form of [pascal] (`Products` → `products`).
  String get camel => pascal.isEmpty
      ? pascal
      : '${pascal[0].toLowerCase()}${pascal.substring(1)}';

  String get featureRoot {
    return switch (architecture) {
      Architecture.clean || Architecture.featureFirst => 'lib/features/$snake',
      Architecture.layered => 'lib',
    };
  }

  String get entity => switch (architecture) {
    Architecture.clean ||
    Architecture.featureFirst => '$featureRoot/domain/entities/$snake.dart',
    Architecture.layered => 'lib/domain/entities/$snake.dart',
  };

  String get repositoryContract => switch (architecture) {
    Architecture.clean || Architecture.featureFirst =>
      '$featureRoot/domain/repositories/${snake}_repository.dart',
    Architecture.layered => 'lib/domain/repositories/${snake}_repository.dart',
  };

  String get getUseCase => switch (architecture) {
    Architecture.clean || Architecture.featureFirst =>
      '$featureRoot/domain/usecases/get_${snake}_list.dart',
    Architecture.layered => 'lib/domain/usecases/get_${snake}_list.dart',
  };

  /// Co-located with [getUseCase] — Search / GetPage live in the same file.
  String get listUseCases => getUseCase;

  String get model => switch (architecture) {
    Architecture.clean ||
    Architecture.featureFirst => '$featureRoot/data/models/${snake}_model.dart',
    Architecture.layered => 'lib/data/models/${snake}_model.dart',
  };

  String get remoteDatasource => switch (architecture) {
    Architecture.clean || Architecture.featureFirst =>
      '$featureRoot/data/datasources/${snake}_remote_datasource.dart',
    Architecture.layered =>
      'lib/data/datasources/${snake}_remote_datasource.dart',
  };

  String get localDatasource => switch (architecture) {
    Architecture.clean || Architecture.featureFirst =>
      '$featureRoot/data/datasources/${snake}_local_datasource.dart',
    Architecture.layered =>
      'lib/data/datasources/${snake}_local_datasource.dart',
  };

  String get repositoryImpl => switch (architecture) {
    Architecture.clean || Architecture.featureFirst =>
      '$featureRoot/data/repositories/${snake}_repository_impl.dart',
    Architecture.layered =>
      'lib/data/repositories/${snake}_repository_impl.dart',
  };

  String stateDir(StateManagement state) {
    final folder = switch (state) {
      StateManagement.bloc => 'bloc',
      StateManagement.cubit => 'cubit',
      StateManagement.riverpod => 'providers',
      StateManagement.provider => 'providers',
    };
    return switch (architecture) {
      Architecture.clean ||
      Architecture.featureFirst => '$featureRoot/presentation/$folder',
      Architecture.layered => 'lib/presentation/features/$snake/$folder',
    };
  }

  String get page => switch (architecture) {
    Architecture.clean || Architecture.featureFirst =>
      '$featureRoot/presentation/pages/${snake}_page.dart',
    Architecture.layered =>
      'lib/presentation/features/$snake/pages/${snake}_page.dart',
  };

  String get listTile => switch (architecture) {
    Architecture.clean || Architecture.featureFirst =>
      '$featureRoot/presentation/widgets/${snake}_list_tile.dart',
    Architecture.layered =>
      'lib/presentation/features/$snake/widgets/${snake}_list_tile.dart',
  };

  String packageImport(String projectName, String relativeLibPath) {
    final withoutLib = relativeLibPath.replaceFirst(RegExp(r'^lib/'), '');
    return "import 'package:$projectName/$withoutLib';";
  }
}
