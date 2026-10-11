import 'package:ai_crop_disease_detection/Services/market_update_service.dart';
import 'package:ai_crop_disease_detection/View/market_updates_list.dart';
import 'package:flutter/material.dart';

/// Read-only screen where farmers view posts from Agriculture Experts.
class MarketUpdatesScreen extends StatefulWidget {
  const MarketUpdatesScreen({super.key});

  @override
  State<MarketUpdatesScreen> createState() => _MarketUpdatesScreenState();
}

class _MarketUpdatesScreenState extends State<MarketUpdatesScreen> {
  final MarketUpdateService _marketUpdateService = MarketUpdateService();

  @override
  void initState() {
    super.initState();
    // Opening the screen means the farmer has now seen all posts.
    _marketUpdateService.markAllSeen();
  }

  @override
  void dispose() {
    // Mark again on leaving, so posts that arrived while the screen was open
    // don't show up as unread afterwards.
    _marketUpdateService.markAllSeen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Market Updates")),
      body: const MarketUpdatesList(),
    );
  }
}
