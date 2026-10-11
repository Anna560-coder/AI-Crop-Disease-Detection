import 'package:ai_crop_disease_detection/Services/market_update_service.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/market_updates_screen.dart';
import 'package:ai_crop_disease_detection/View/widgets/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// "Market Updates" button for FarmerScreen with a red badge in the top
/// corner showing how many posts the farmer has not viewed yet.
class MarketUpdatesButton extends StatefulWidget {
  const MarketUpdatesButton({super.key});

  @override
  State<MarketUpdatesButton> createState() => _MarketUpdatesButtonState();
}

class _MarketUpdatesButtonState extends State<MarketUpdatesButton> {
  final MarketUpdateService _service = MarketUpdateService();

  // Streams are created once and reused, so rebuilding FarmerScreen (e.g.
  // while an image is analysed) doesn't reopen Firestore listeners.
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _unreadStream;
  Timestamp? _unreadStreamSince;

  @override
  void initState() {
    super.initState();
    _profileStream = _service.watchProfile();
  }

  /// Returns the unread-posts stream, only recreating it when lastSeen changes.
  Stream<QuerySnapshot<Map<String, dynamic>>> _unreadSince(
    Timestamp? lastSeen,
  ) {
    if (_unreadStream == null || _unreadStreamSince != lastSeen) {
      _unreadStreamSince = lastSeen;
      _unreadStream = _service.watchUpdatesSince(lastSeen);
    }
    return _unreadStream!;
  }

  @override
  Widget build(BuildContext context) {
    // Not logged in: show the plain button with no badge.
    if (_profileStream == null) return _button(0);

    // 1) Listen to the farmer's profile to get lastSeenMarketUpdates.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        if (!profileSnapshot.hasData) return _button(0);

        final profile = profileSnapshot.data!.data() ?? {};
        const field = MarketUpdateService.lastSeenField;

        // Field present but null = the "mark as seen" write is still waiting
        // for the server timestamp, so the farmer has just viewed everything.
        if (profile.containsKey(field) && profile[field] == null) {
          return _button(0);
        }
        final lastSeen = profile[field] as Timestamp?;

        // 2) Count posts newer than lastSeen (live, so new posts appear on
        //    the badge without refreshing).
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _unreadSince(lastSeen),
          builder: (context, updatesSnapshot) {
            // Expired posts are hidden from farmers, so they don't count.
            final unread =
                updatesSnapshot.data?.docs
                    .where((d) => MarketUpdateService.isActive(d.data()))
                    .length ??
                0;
            return _button(unread);
          },
        );
      },
    );
  }

  Widget _button(int unread) {
    return HomeActionTile(
      icon: Icons.storefront,
      title: "Market Updates",
      subtitle: unread > 0
          ? "$unread new ${unread == 1 ? 'post' : 'posts'} from experts"
          : "Prices, tips and alerts from experts",
      color: AppColors.info,
      badgeCount: unread,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MarketUpdatesScreen()),
        );
      },
    );
  }
}
