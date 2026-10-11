/// How long until [expiresAt], for an expert's own post, e.g.
/// "Expired", "Last day today", "1 day left", "12 days left".
String expiryLabel(DateTime expiresAt, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (!expiresAt.isAfter(current)) return "Expired";
  final days = expiresAt.difference(current).inDays;
  if (days == 0) return "Last day today";
  return days == 1 ? "1 day left" : "$days days left";
}

/// Formats [time] relative to [now] (defaults to the current time),
/// e.g. "just now", "5 minutes ago", "yesterday", "3 days ago", "12/05/2026".
String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);

  // Treat small clock differences between device and server as "just now".
  if (diff.inSeconds < 60) return "just now";
  if (diff.inMinutes < 60) {
    return diff.inMinutes == 1
        ? "1 minute ago"
        : "${diff.inMinutes} minutes ago";
  }
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? "1 hour ago" : "${diff.inHours} hours ago";
  }
  if (diff.inDays == 1) return "yesterday";
  if (diff.inDays < 7) return "${diff.inDays} days ago";

  final day = time.day.toString().padLeft(2, '0');
  final month = time.month.toString().padLeft(2, '0');
  return "$day/$month/${time.year}";
}
