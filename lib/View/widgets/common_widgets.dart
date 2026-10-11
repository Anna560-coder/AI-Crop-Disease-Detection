import 'package:ai_crop_disease_detection/Services/auth_services.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/login_screen.dart';
import 'package:flutter/material.dart';

/// Round leaf logo used on the welcome, login and signup screens.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.eco, color: AppColors.primary, size: size * 0.58),
    );
  }
}

/// Small coloured pill, e.g. "High severity" or "Healthy".
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly message shown when a list has nothing in it yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Large tappable tile with an icon, title and short description.
/// Used for the main actions on the farmer home screen.
class HomeActionTile extends StatelessWidget {
  const HomeActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.primary,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(
                  badgeCount > 9 ? "9+" : "$badgeCount",
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: AppColors.danger,
                largeSize: 22,
                offset: const Offset(8, -8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading used on long screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
          ],
          Text(text, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

// ---------------- Diagnosis display helpers ----------------

bool isHealthyLabel(String label) => label.toLowerCase() == "healthy";

/// Colour for a severity level stored in Firestore (High/Moderate/Low).
Color severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case "high":
      return AppColors.danger;
    case "moderate":
    case "medium":
      return AppColors.warning;
    case "low":
      return AppColors.healthy;
    default:
      return AppColors.textMuted;
  }
}

/// Plain-language description of model confidence (0-100).
String confidenceLabel(double confidence) {
  if (confidence >= 85) return "Very sure";
  if (confidence >= 60) return "Fairly sure";
  return "Not sure";
}

Color confidenceColor(double confidence) {
  if (confidence >= 85) return AppColors.healthy;
  if (confidence >= 60) return AppColors.warning;
  return AppColors.danger;
}

// ---------------- Sign out ----------------

/// Asks the user to confirm, signs out, and returns to the login screen
/// (clearing the back stack so Back cannot return to a logged-in screen).
Future<void> confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.logout, color: AppColors.primary, size: 32),
      title: const Text("Sign out?"),
      content: const Text(
        "You will need your email and password to log in again.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("Sign out"),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  await AuthServices().signOut();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
