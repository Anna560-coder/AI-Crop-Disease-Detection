import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;

class MarketUpdateService {
  /// Categories an Agriculture Expert can post under. firestore.rules only
  /// accepts these exact values, so keep both lists in sync.
  static const List<String> categories = [
    "Market Price Update",
    "Seasonal Advice",
    "Alert",
  ];

  /// How long a post can be shown to farmers. firestore.rules rejects
  /// anything longer than 100 days.
  static const Map<String, Duration> showForOptions = {
    "3 days": Duration(days: 3),
    "1 week": Duration(days: 7),
    "2 weeks": Duration(days: 14),
    "1 month": Duration(days: 30),
    "3 months": Duration(days: 90),
  };

  /// Sensible default for each category: prices change quickly, seasonal
  /// advice stays useful for longer.
  static String defaultShowFor(String category) {
    switch (category) {
      case "Market Price Update":
        return "1 week";
      case "Alert":
        return "2 weeks";
      default:
        return "1 month";
    }
  }

  /// Longest side of a post photo, in pixels, and the largest photo
  /// (base64 characters) firestore.rules accepts.
  static const int imageMaxSide = 800;
  static const int imageMaxBase64Length = 500000;

  /// Field names stored on each post.
  static const String expiresAtField = 'expiresAt';
  static const String imageField = 'image';

  /// Max posts loaded at once, to keep the screen and data use small.
  static const int listLimit = 50;

  final CollectionReference<Map<String, dynamic>> _updatesRef =
      FirebaseFirestore.instance.collection('market_updates');

  /// true while a post should still be shown to farmers. Posts created
  /// before expiry dates existed (no expiresAt) are always shown.
  static bool isActive(Map<String, dynamic> post, {DateTime? now}) {
    final expiresAt = post[expiresAtField];
    if (expiresAt is! Timestamp) return true;
    return expiresAt.toDate().isAfter(now ?? DateTime.now());
  }

  /// Shrinks a photo so it fits inside a Firestore document: longest side
  /// [imageMaxSide] px, JPEG, then base64. Lowers quality until it fits.
  /// Returns null if the bytes are not an image.
  static String? encodePostImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final oriented = img.bakeOrientation(decoded);
    final longest = math.max(oriented.width, oriented.height);
    final resized = longest > imageMaxSide
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? imageMaxSide : null,
            height: oriented.height > oriented.width ? imageMaxSide : null,
          )
        : oriented;

    for (final quality in [75, 60, 45, 30]) {
      final encoded = base64Encode(img.encodeJpg(resized, quality: quality));
      if (encoded.length <= imageMaxBase64Length) return encoded;
    }
    return null;
  }

  /// Writes a new post to `market_updates`. Returns null on success or an
  /// error message to show the user.
  Future<String?> createUpdate({
    required String category,
    required String title,
    required String message,
    required Duration showFor,
    String? imageBase64,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "You must be logged in to post.";

    try {
      await _updatesRef.add({
        'authorId': user.uid,
        'category': category,
        'title': title.trim(),
        'message': message.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        expiresAtField: Timestamp.fromDate(DateTime.now().add(showFor)),
        if (imageBase64 != null) imageField: imageBase64,
      });
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return "Only Agriculture Experts can post updates.";
      }
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  /// Deletes one of the expert's own posts (firestore.rules allows only the
  /// author to delete). Returns null on success or an error message.
  Future<String?> deleteUpdate(String postId) async {
    try {
      await _updatesRef.doc(postId).delete();
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return "You can only delete your own posts.";
      }
      return "Could not delete the post. Please try again.";
    } catch (_) {
      return "Could not delete the post. Please try again.";
    }
  }

  /// Latest posts, newest first. A single-field orderBy needs no composite
  /// index. Expired posts are filtered out on the screen with [isActive].
  Stream<QuerySnapshot<Map<String, dynamic>>> watchUpdates() {
    return _updatesRef
        .orderBy('createdAt', descending: true)
        .limit(listLimit)
        .snapshots();
  }

  /// The logged-in expert's own posts, including expired ones. Sorted on
  /// the screen, because where() + orderBy() would need a composite index.
  Stream<QuerySnapshot<Map<String, dynamic>>>? watchMyUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return _updatesRef.where('authorId', isEqualTo: user.uid).snapshots();
  }

  // ---- Unread badge ----
  // The time a farmer last opened Market Updates is stored on their own
  // profile (farmers/{uid}.lastSeenMarketUpdates), so the unread count is
  // the same on every device they log in from.

  static const String lastSeenField = 'lastSeenMarketUpdates';

  /// The logged-in user's profile document, for reading lastSeenMarketUpdates.
  Stream<DocumentSnapshot<Map<String, dynamic>>>? watchProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('farmers')
        .doc(user.uid)
        .snapshots();
  }

  /// Posts created after [lastSeen]. A null [lastSeen] means the farmer has
  /// never opened Market Updates, so every post counts as unread.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchUpdatesSince(
    Timestamp? lastSeen,
  ) {
    if (lastSeen == null) return _updatesRef.snapshots();
    return _updatesRef.where('createdAt', isGreaterThan: lastSeen).snapshots();
  }

  /// Records that the farmer has now seen every post, clearing the badge.
  Future<void> markAllSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(user.uid)
          .update({lastSeenField: FieldValue.serverTimestamp()});
    } catch (e) {
      // Not critical: the badge just stays until the next successful update.
    }
  }
}
