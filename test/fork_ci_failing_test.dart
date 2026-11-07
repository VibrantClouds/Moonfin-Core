import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fork CI test: deliberately failing expect', () {
    expect(1 + 1, 3, reason: 'fork test, this should show up in the PR comment');
  });
}
