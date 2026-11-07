import 'package:flutter_test/flutter_test.dart';

void main() {
  test('example: a deliberately failing expect', () {
    expect(1 + 1, 3, reason: 'example PR, this shows up in the PR comment');
  });
}
