import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/market_updates_list.dart';
import 'package:ai_crop_disease_detection/View/new_post_screen.dart';
import 'package:ai_crop_disease_detection/View/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

/// Expert Dashboard: write new posts and manage your own posts.
class AgricultureExpertScreen extends StatefulWidget {
  const AgricultureExpertScreen({super.key});

  @override
  State<AgricultureExpertScreen> createState() =>
      _AgricultureExpertScreenState();
}

class _AgricultureExpertScreenState extends State<AgricultureExpertScreen> {
  /// "My posts" (default, with delete) or "All posts" (what farmers see).
  MarketUpdatesMode mode = MarketUpdatesMode.mine;

  Future<void> _openNewPost() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewPostScreen()),
    );
    if (posted == true && mounted) {
      setState(() => mode = MarketUpdatesMode.mine);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your update was posted. Farmers can see it now."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expert Dashboard"),
        actions: [
          IconButton(
            tooltip: "Sign out",
            icon: const Icon(Icons.logout),
            onPressed: () => confirmSignOut(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewPost,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textDark,
        icon: const Icon(Icons.edit),
        label: const Text(
          "New post",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        // Room so the last post isn't hidden behind the "New post" button.
        padding: const EdgeInsets.only(bottom: 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Share your knowledge",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.campaign,
                          color: AppColors.accent,
                          size: 40,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Post market prices, seasonal tips and disease alerts. Every farmer in the app sees them.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _openNewPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text("Write a new post"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Switch between your own posts and what farmers see.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<MarketUpdatesMode>(
                segments: const [
                  ButtonSegment(
                    value: MarketUpdatesMode.mine,
                    icon: Icon(Icons.person_outline),
                    label: Text("My posts"),
                  ),
                  ButtonSegment(
                    value: MarketUpdatesMode.active,
                    icon: Icon(Icons.groups_outlined),
                    label: Text("All posts"),
                  ),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => mode = selection.first);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                mode == MarketUpdatesMode.mine
                    ? "Your posts, newest first. Expired posts are hidden from farmers; delete any post you no longer need."
                    : "Every post farmers can see right now.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            // Keyed by mode so switching opens the right Firestore listener.
            MarketUpdatesList(
              key: ValueKey(mode),
              mode: mode,
              shrinkWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}
