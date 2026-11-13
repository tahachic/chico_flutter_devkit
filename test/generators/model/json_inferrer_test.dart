import 'package:chico_flutter_devkit/chico_flutter_devkit.dart';
import 'package:chico_flutter_devkit/src/generators/model/json_model_inferrer.dart';
import 'package:test/test.dart';

void main() {
  test('infers primitive and datetime fields', () {
    final fields = JsonModelInferrer.fromJsonString('''
{
  "id": "1",
  "count": 3,
  "price": 9.5,
  "active": true,
  "created_at": "2024-05-01T12:00:00Z"
}
''');

    expect(
      fields.map((f) => f.name),
      containsAll(['id', 'count', 'price', 'active', 'createdAt']),
    );
    expect(fields.firstWhere((f) => f.name == 'createdAt').type, 'DateTime');
    expect(fields.firstWhere((f) => f.name == 'price').type, 'double');
  });

  test('rejects invalid json', () {
    expect(
      () => JsonModelInferrer.fromJsonString('{bad'),
      throwsA(isA<InvalidUsageException>()),
    );
  });
}
