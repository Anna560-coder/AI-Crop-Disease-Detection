import 'package:cloud_firestore/cloud_firestore.dart';

class DiagnosisService {
  final CollectionReference diseasesRef = FirebaseFirestore.instance.collection(
    'diseases',
  );

  /// Looks up structured disease info from Firestore.
  /// Falls back to safe defaults so the app never breaks even if a
  /// label has no matching document yet.
  Future<Map<String, dynamic>> getDiseaseInfo(String label) async {
    try {
      final doc = await diseasesRef.doc(label).get();

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
