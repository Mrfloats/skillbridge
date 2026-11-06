import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'booking_detail_screen.dart';

/// In-app notification list (FR-10.2).
class NotificationsScreen extends StatelessWidget {
  final AppUser user;
  const NotificationsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<AppNotification>>(
        stream: Db.instance.notifications(user.uid),
        builder: (context, snap) {
          if (!snap.hasData) return const SkeletonList();
          final list = snap.data!;
          if (list.isEmpty) return const EmptyState(icon: Icons.notifications_none_rounded, title: "You're all caught up");
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final n = list[i];
              return Reveal(
                index: i,
                child: HoverCard(
                  color: n.isRead ? null : Color.alphaBlend(c.primaryContainer.withAlpha(150), c.surfaceContainerLowest),
                  onTap: () {
                    if (!n.isRead) Db.instance.markNotificationRead(n.id);
                    if ((n.type == 'booking' || n.type == 'review' || n.type == 'chat') && n.refId != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: n.refId!, user: user)));
                    }
                  },
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: n.isRead ? c.surfaceContainerHigh : c.primaryContainer, shape: BoxShape.circle),
                      child: Icon(
                        n.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                        size: 20,
                        color: n.isRead ? c.onSurfaceVariant : c.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: t.titleSmall?.copyWith(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(n.body, style: t.bodySmall),
                        const SizedBox(height: 6),
                        Text(fmtDateTime(n.createdAt), style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
