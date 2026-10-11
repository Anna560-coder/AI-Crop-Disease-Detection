import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:ai_crop_disease_detection/Services/market_update_service.dart';
import 'package:ai_crop_disease_detection/Services/time_utils.dart';

void main() {
  final now = DateTime(2026, 10, 9, 12);

  group('post expiry', () {
    test('posts are shown until expiresAt, then hidden', () {
      final post = {
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 2))),
      };
      expect(MarketUpdateService.isActive(post, now: now), isTrue);
      expect(
        MarketUpdateService.isActive(
          post,
          now: now.add(const Duration(days: 3)),
        ),
        isFalse,
      );
    });

    test('older posts without an expiry date are still shown', () {
      expect(MarketUpdateService.isActive({'title': 'Old post'}), isTrue);
    });

    test('each category has a sensible default duration', () {
      expect(
        MarketUpdateService.defaultShowFor("Market Price Update"),
        "1 week",
      );
      expect(MarketUpdateService.defaultShowFor("Alert"), "2 weeks");
      expect(MarketUpdateService.defaultShowFor("Seasonal Advice"), "1 month");
      for (final category in MarketUpdateService.categories) {
        expect(
          MarketUpdateService.showForOptions,
          contains(MarketUpdateService.defaultShowFor(category)),
        );
      }
    });

    test('no duration exceeds the 100-day limit in firestore.rules', () {
      for (final d in MarketUpdateService.showForOptions.values) {
        expect(d.inDays, lessThanOrEqualTo(100));
      }
    });

    test('expiryLabel describes the time left', () {
      expect(
        expiryLabel(now.add(const Duration(days: 12, hours: 1)), now: now),
        "12 days left",
      );
      expect(
        expiryLabel(now.add(const Duration(days: 1, hours: 1)), now: now),
        "1 day left",
      );
      expect(
        expiryLabel(now.add(const Duration(hours: 5)), now: now),
        "Last day today",
      );
      expect(
        expiryLabel(now.subtract(const Duration(hours: 1)), now: now),
        "Expired",
      );
    });
  });

  group('post photos', () {
    void expectFitsInPost(String? encoded) {
      expect(encoded, isNotNull);
      expect(
        encoded!.length,
        lessThanOrEqualTo(MarketUpdateService.imageMaxBase64Length),
      );
      final decoded = img.decodeJpg(base64Decode(encoded))!;
      expect(
        max(decoded.width, decoded.height),
        lessThanOrEqualTo(MarketUpdateService.imageMaxSide),
      );
    }

    test('a real photo is shrunk to fit inside a post', () {
      final bytes = File('assets/disease_leaf.png').readAsBytesSync();
      expectFitsInPost(MarketUpdateService.encodePostImage(bytes));
    });

    test('a large, detailed camera-sized photo still fits', () {
      // Random noise is the hardest case for JPEG compression.
      final random = Random(1);
      final photo = img.Image(width: 4000, height: 3000);
      for (final pixel in photo) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      expectFitsInPost(
        MarketUpdateService.encodePostImage(
          Uint8List.fromList(img.encodeJpg(photo, quality: 95)),
        ),
      );
    });

    test('a file that is not an image is rejected', () {
      expect(
        MarketUpdateService.encodePostImage(
          Uint8List.fromList(utf8.encode("not an image")),
        ),
        isNull,
      );
    });
  });
}
