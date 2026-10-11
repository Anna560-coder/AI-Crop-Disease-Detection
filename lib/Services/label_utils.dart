/// Label the model uses for photos that are not a crop leaf (a wall, a
/// person, the sky...). Must match the line in assets/labels.txt.
const String notLeafLabel = "Not a leaf";

bool isNotLeafLabel(String label) =>
    label.toLowerCase() == notLeafLabel.toLowerCase();

/// Parses the contents of assets/labels.txt into a clean list of labels.
///
/// Each label is trimmed so Windows (CRLF) line endings or stray spaces can
/// never leak into a label (e.g. "Healthy\r"), which would break the Firestore
/// lookup in DiagnosisService and the "Healthy" checks in the UI.
List<String> parseLabels(String labelData) {
  return labelData
      .split('\n')
      .map((label) => label.trim())
      .where((label) => label.isNotEmpty)
      .toList();
}
