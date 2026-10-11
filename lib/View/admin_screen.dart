import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            tooltip: "Sign out",
            icon: const Icon(Icons.logout),
            onPressed: () => confirmSignOut(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const EmptyState(
            icon: Icons.admin_panel_settings_outlined,
            title: "Admin tools are coming soon",
            message:
                "For now, manage users and disease information in the Firebase console.",
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    "Make someone an expert",
                    icon: Icons.verified_user_outlined,
                  ),
                  Text(
                    "1. Ask them to sign up in the app.\n"
                    "2. In Firebase console, open Firestore → farmers.\n"
                    "3. Find their document and change role to Expert.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Only admins can change roles. The app's security rules block users from doing it themselves.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
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
