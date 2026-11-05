import 'package:cloud_firestore/cloud_firestore.dart';

class DiagnosisService {
  final CollectionReference diseasesRef = FirebaseFirestore.instance.collection(
    'diseases',
  );

  /// Downloads all disease info while online, so Firestore's local cache can
  /// answer lookups later when the farmer has no internet.
  Future<void> cacheForOffline() async {
    try {
      await diseasesRef.get().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Offline now: whatever was cached earlier is still used.
    }
  }

  /// Fresh copy if the server answers quickly, otherwise the cached copy.
  Future<DocumentSnapshot> _readDisease(String label) async {
    final doc = diseasesRef.doc(label);
    try {
      return await doc
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return doc.get(const GetOptions(source: Source.cache));
    }
  }

  /// Looks up structured disease info from Firestore.
  /// Falls back to safe defaults so the app never breaks even if a
  /// label has no matching document yet.
  Future<Map<String, dynamic>> getDiseaseInfo(String label) async {
    try {
      final doc = await _readDisease(label);

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          "symptoms": data["symptoms"] ?? "Not documented.",
          "severity_level": data["severity_level"] ?? "Unknown",
          "crop_type": data["crop_type"] ?? "Unknown",
          "treatment_advice":
              data["treatment_advice"] ??
              "Consult an agricultural expert for proper treatment advice.",
        };
      }
    } catch (e) {
      // Firestore unreachable or lookup failed — fall through to default.
    }

    return {
      "symptoms": "Not documented.",
      "severity_level": "Unknown",
      "crop_type": "Unknown",
      "treatment_advice":
          "Consult an agricultural expert for proper treatment advice.",
    };
  }
}
