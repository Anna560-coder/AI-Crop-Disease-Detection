import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_crop_disease_detection/Services/label_utils.dart';

void main() {
  test('parseLabels trims CRLF endings and skips blank lines', () {
    expect(parseLabels('Gall Midge\r\nHealthy\r\n\r\nSooty Mould\r\n'), [
      'Gall Midge',
      'Healthy',
      'Sooty Mould',
    ]);
  });

  test('assets/labels.txt has 9 clean, unique labels matching the model', () {
    final labels = parseLabels(File('assets/labels.txt').readAsStringSync());

    // 8 diseases/healthy + "Not a leaf", in the model's output order.
    expect(labels.length, 9);
    expect(labels.toSet().length, labels.length);
    expect(labels, contains('Healthy'));
    expect(labels.last, notLeafLabel);
    for (final label in labels) {
      expect(label, label.trim());
    }
  });

  test('the model file the app loads is bundled', () {
    expect(File('assets/crop_disease_model.tflite').existsSync(), isTrue);
  });

  test('isNotLeafLabel matches only the "Not a leaf" class', () {
    expect(isNotLeafLabel('Not a leaf'), isTrue);
    expect(isNotLeafLabel('not a leaf'), isTrue);
    expect(isNotLeafLabel('Healthy'), isFalse);
    expect(isNotLeafLabel('Anthracnose'), isFalse);
  });
}
