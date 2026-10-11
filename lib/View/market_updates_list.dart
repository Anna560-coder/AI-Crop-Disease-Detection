import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_crop_disease_detection/Services/market_update_service.dart';
import 'package:ai_crop_disease_detection/Services/time_utils.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/widgets/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Which posts a [MarketUpdatesList] shows.
enum MarketUpdatesMode {
  /// Every post that has not expired: what farmers see.
  active,

  /// The logged-in expert's own posts, including expired ones, with
  /// expiry information and a delete button.
  mine,
}

/// List of `market_updates` posts, newest first.
/// Used by MarketUpdatesScreen (farmers) and AgricultureExpertScreen.
class MarketUpdatesList extends StatefulWidget {
  const MarketUpdatesList({
    super.key,
    this.shrinkWrap = false,
    this.mode = MarketUpdatesMode.active,
  });

  /// Set to true when placed inside another scrollable (e.g. a Column in a
  /// SingleChildScrollView).
  final bool shrinkWrap;
  final MarketUpdatesMode mode;

  static IconData categoryIcon(String category) {
    switch (category) {
      case "Market Price Update":
        return Icons.payments_outlined;
      case "Seasonal Advice":
        return Icons.wb_sunny_outlined;
      case "Alert":
        return Icons.warning_amber_rounded;
      default:
        return Icons.campaign_outlined;
    }
  }

  static Color categoryColor(String category) {
    switch (category) {
      case "Market Price Update":
        return AppColors.info;
      case "Seasonal Advice":
        return AppColors.primary;
      case "Alert":
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  State<MarketUpdatesList> createState() => _MarketUpdatesListState();
}

class _MarketUpdatesListState extends State<MarketUpdatesList> {
  final MarketUpdateService _service = MarketUpdateService();

  // Created once so parent rebuilds don't reopen the Firestore listener.
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _stream =
      widget.mode == MarketUpdatesMode.mine
      ? _service.watchMyUpdates()
      : _service.watchUpdates();

  bool get _mine => widget.mode == MarketUpdatesMode.mine;

  Future<void> _confirmDelete(String postId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline,
          color: AppColors.danger,
          size: 32,
        ),
        title: const Text("Delete this post?"),
        content: Text(
          "\"$title\" will be removed for all farmers. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Keep it"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await _service.deleteUpdate(postId);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? "The post was deleted.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: "Please log in",
        message: "Log in to see market updates.",
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Market updates error: ${snapshot.error}");
          return const EmptyState(
            icon: Icons.cloud_off,
            title: "Could not load updates",
            message: "Please check your internet connection and try again.",
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        var docs = snapshot.data?.docs ?? [];
        if (_mine) {
          // Newest first (sorted here to avoid a composite index).
          docs = [...docs]
            ..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              if (aTime == null) return -1;
              if (bTime == null) return 1;
              return bTime.compareTo(aTime);
            });
        } else {
          // Farmers never see expired posts.
          docs = docs
              .where((d) => MarketUpdateService.isActive(d.data()))
              .toList();
        }

        if (docs.isEmpty) {
          return EmptyState(
            icon: Icons.storefront_outlined,
            title: _mine ? "You have no posts yet" : "No updates yet",
            message: _mine
                ? "Tap \"New post\" to share prices, tips or alerts with farmers."
                : "Market prices, seasonal tips and alerts from agriculture experts will appear here.",
          );
        }

        return ListView.separated(
          shrinkWrap: widget.shrinkWrap,
          physics: widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final post = doc.data();
            return MarketUpdateCard(
              key: ValueKey(doc.id),
              post: post,
              onDelete: _mine
                  ? () => _confirmDelete(doc.id, post['title'] as String? ?? "")
                  : null,
            );
          },
        );
      },
    );
  }
}

/// One post. With [onDelete] it also shows expiry information and a
/// delete button (the expert's own posts).
class MarketUpdateCard extends StatelessWidget {
  const MarketUpdateCard({super.key, required this.post, this.onDelete});

  final Map<String, dynamic> post;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final category = post['category'] as String? ?? "Update";
    final createdAt = post['createdAt'] as Timestamp?;
    final expiresAt = post[MarketUpdateService.expiresAtField] as Timestamp?;
    final image = post[MarketUpdateService.imageField] as String?;
    final active = MarketUpdateService.isActive(post);
    final color = MarketUpdatesList.categoryColor(category);

    return Opacity(
      // Expired own posts are greyed out: farmers can no longer see them.
      opacity: active ? 1 : 0.6,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          // Coloured strip on the left shows the category at a glance.
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (image != null) _PostImage(base64Data: image),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: StatusChip(
                            label: category,
                            color: color,
                            icon: MarketUpdatesList.categoryIcon(category),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.schedule,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          // A brand-new post has no server timestamp yet.
                          createdAt == null
                              ? "just now"
                              : relativeTime(createdAt.toDate()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post['title'] as String? ?? "",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post['message'] as String? ?? "",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.4),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            active
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: active
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              expiresAt == null
                                  ? "Shown to farmers (no end date)"
                                  : active
                                  ? "Shown to farmers · ${expiryLabel(expiresAt.toDate())}"
                                  : "Expired · farmers can no longer see it",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: onDelete,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            label: const Text("Delete"),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A post photo stored as base64. Decoded once; tap to view full screen.
class _PostImage extends StatefulWidget {
  const _PostImage({required this.base64Data});

  final String base64Data;

  @override
  State<_PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<_PostImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    try {
      _bytes = base64Decode(widget.base64Data);
    } catch (_) {
      _bytes = null;
    }
  }

  void _openFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: const Text("Photo"),
          ),
          body: Center(
            child: InteractiveViewer(maxScale: 5, child: Image.memory(_bytes!)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _openFullScreen,
      child: Stack(
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: Image.memory(
              _bytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    "Tap to enlarge",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
