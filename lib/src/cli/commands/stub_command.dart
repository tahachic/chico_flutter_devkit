import '../../core/exceptions.dart';
import '../command.dart';

/// Placeholder for commands scheduled for later phases.
final class StubCommand extends DevKitCommand {
  StubCommand({
    required super.logger,
    required super.configService,
    required super.projectRootProvider,
    required String name,
    required String description,
    required this.phase,
  }) : _name = name,
       _description = description;

  final String _name;
  final String _description;
  final String phase;

  @override
  String get name => _name;

  @override
  String get description => _description;

  @override
  Future<int> run() async {
    throw NotImplementedException(
      '`$name` is not implemented yet.',
      details: 'Scheduled for $phase. See doc/ARCHITECTURE.md for the roadmap.',
    );
  }
}
