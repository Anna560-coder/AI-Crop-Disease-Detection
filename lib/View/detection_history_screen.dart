// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class DetectionHistoryScreen extends StatelessWidget {
//   const DetectionHistoryScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;

//     return Scaffold(
//       appBar: AppBar(title: const Text("Detection History")),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('detection_history')
//             .where('userId', isEqualTo: user?.uid)
//             //.orderBy('createdAt', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(child: Text("Error: ${snapshot.error}"));
//           }

//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(child: Text("No detection history available."));
//           }

//           final docs = snapshot.data!.docs;

//           return ListView.builder(
//             padding: const EdgeInsets.all(12),
//             itemCount: docs.length,
//             itemBuilder: (context, index) {
//               final item = docs[index].data() as Map<String, dynamic>;

//               return Card(
//                 child: ListTile(
//                   leading: item['imagePath'] != null
//                       ? Image.file(
//                           File(item['imagePath']),
//                           width: 60,
//                           height: 60,
//                           fit: BoxFit.cover,
//                         )
//                       : const Icon(Icons.image),
//                   title: Text("Disease: ${item['label']}"),
//                   subtitle: Text(
//                     "Confidence: ${(item['confidence'] as num).toStringAsFixed(2)}%\n${item['treatment']}",
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

import 'dart:io';
import 'package:ai_crop_disease_detection/Services/time_utils.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/widgets/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DetectionHistoryScreen extends StatelessWidget {
  const DetectionHistoryScreen({super.key});

  Future<void> deleteHistoryItem(
    BuildContext context,
    String docId,
    String? imagePath,
  ) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline,
            color: AppColors.danger,
            size: 32,
          ),
          title: const Text("Delete this scan?"),
          content: const Text(
            "This scan will be removed from your history for good.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Keep it"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await FirebaseFirestore.instance
            .collection('detection_history')
            .doc(docId)
            .delete();

        // Remove the locally stored copy of the image, if the app saved one.
        if (imagePath != null && imagePath.contains('detection_images')) {
          try {
            final file = File(imagePath);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }

        messenger.showSnackBar(
          const SnackBar(content: Text("The scan was deleted.")),
        );
      } catch (e) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Could not delete this item. Please try again."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Past Scans")),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: "Please log in",
          message: "Log in to see the leaves you have checked.",
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Past Scans")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('detection_history')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("Detection history error: ${snapshot.error}");
            return const EmptyState(
              icon: Icons.cloud_off,
              title: "Could not load your scans",
              message: "Please check your internet connection and try again.",
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EmptyState(
              icon: Icons.eco_outlined,
              title: "No scans yet",
              message:
                  "Every leaf you check is saved here, so you can look back at the results and advice.",
              action: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.photo_camera),
                label: const Text("Check a leaf now"),
              ),
            );
          }

          // Sort newest first on the client. Using orderBy() together with
          // where() would require a Firestore composite index.
          final docs = [...snapshot.data!.docs]
            ..sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              // Items still waiting for a server timestamp are the newest.
              if (aTime == null) return -1;
              if (bTime == null) return 1;
              return bTime.compareTo(aTime);
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  "${docs.length} ${docs.length == 1 ? 'leaf' : 'leaves'} checked. Tap a scan to see the full advice.",
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final doc = docs[index - 1];
              final item = doc.data() as Map<String, dynamic>;

              return _HistoryCard(
                item: item,
                onTap: () => _showDetails(context, item),
                onDelete: () => deleteHistoryItem(
                  context,
                  doc.id,
                  item['imagePath'] as String?,
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Bottom sheet with the full result and advice for one scan.
  void _showDetails(BuildContext context, Map<String, dynamic> item) {
    final label = item['label'] as String? ?? "Unknown";
    final healthy = isHealthyLabel(label);
    final severity = item['severityLevel'] as String? ?? "";
    final symptoms = item['symptoms'] as String? ?? "";
    final treatment = item['treatment'] as String? ?? "";
    final confidence = ((item['confidence'] as num?) ?? 0).toDouble();
    final createdAt = item['createdAt'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: _HistoryImage(path: item['imagePath'] as String?),
              ),
            ),
            const SizedBox(height: 16),
            Text(label, style: Theme.of(sheetContext).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip(label, severity),
                StatusChip(
                  label:
                      "${confidence.toStringAsFixed(0)}% · ${confidenceLabel(confidence)}",
                  color: confidenceColor(confidence),
                  icon: Icons.verified_outlined,
                ),
                if (createdAt != null)
                  StatusChip(
                    label: relativeTime(createdAt.toDate()),
                    color: AppColors.textMuted,
                    icon: Icons.schedule,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (symptoms.isNotEmpty && symptoms != "Not documented.")
              _DetailSection(
                icon: Icons.visibility_outlined,
                title: "Signs to look for",
                text: symptoms,
              ),
            if (treatment.isNotEmpty)
              _DetailSection(
                icon: Icons.healing,
                title: healthy ? "Keep it healthy" : "What to do",
                text: treatment,
              ),
          ],
        ),
      ),
    );
  }
}

/// Green "Healthy" chip, or a severity-coloured chip for a disease.
Widget _statusChip(String label, String severity) {
  if (isHealthyLabel(label)) {
    return const StatusChip(
      label: "Healthy",
      color: AppColors.healthy,
      icon: Icons.check_circle,
    );
  }
  final known = severity.isNotEmpty && severity.toLowerCase() != "unknown";
  return StatusChip(
    label: known ? "$severity severity" : "Disease found",
    color: known ? severityColor(severity) : AppColors.danger,
    icon: Icons.warning_rounded,
  );
}

/// One scan in the history list.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = item['label'] as String? ?? "Unknown";
    final severity = item['severityLevel'] as String? ?? "";
    final createdAt = item['createdAt'] as Timestamp?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: _HistoryImage(path: item['imagePath'] as String?),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    _statusChip(label, severity),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          createdAt == null
                              ? "just now"
                              : relativeTime(createdAt.toDate()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Delete this scan",
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The saved leaf photo, or a leaf icon if the photo is not on this phone.
class _HistoryImage extends StatelessWidget {
  const _HistoryImage({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: AppColors.primaryLight,
      child: Center(child: Icon(Icons.eco, color: AppColors.primary, size: 34)),
    );

    if (path == null || !File(path!).existsSync()) return placeholder;
    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      cacheWidth: 600,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
