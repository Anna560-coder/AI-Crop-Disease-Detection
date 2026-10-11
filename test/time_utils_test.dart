import 'package:flutter_test/flutter_test.dart';

import 'package:ai_crop_disease_detection/Services/time_utils.dart';

void main() {
  final now = DateTime(2026, 10, 2, 12, 0);

  test('relativeTime formats recent and older timestamps', () {
    expect(
      relativeTime(now.subtract(const Duration(seconds: 20)), now: now),
      'just now',
    );
    // Server clock slightly ahead of the device.
    expect(
      relativeTime(now.add(const Duration(seconds: 5)), now: now),
      'just now',
    );
    expect(
      relativeTime(now.subtract(const Duration(minutes: 1)), now: now),
      '1 minute ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(minutes: 45)), now: now),
      '45 minutes ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(hours: 3)), now: now),
      '3 hours ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 1)), now: now),
      'yesterday',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 4)), now: now),
      '4 days ago',
    );
    expect(relativeTime(DateTime(2026, 5, 12), now: now), '12/05/2026');
  });
}
