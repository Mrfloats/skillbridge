import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'booking_detail_screen.dart';

/// Upcoming and past bookings for a client or provider (FR-5.10).
class BookingsListScreen extends StatelessWidget {
  final AppUser user;
  final bool asProvider;
  const BookingsListScreen({super.key, required this.user, required this.asProvider});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(asProvider ? 'Jobs' : 'My bookings'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(58),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'History')]),
            ),
          ),
        ),
        body: StreamBuilder<List<Booking>>(
          stream: Db.instance.bookingsFor(user.uid, asProvider: asProvider),
          builder: (context, snap) {
            if (snap.hasError) return EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load bookings', message: '${snap.error}');
            if (!snap.hasData) return const SkeletonList();
            final all = snap.data!;
            final active = all.where((b) => BookingStatus.active.contains(b.status)).toList()
              ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
            final past = all.where((b) => !BookingStatus.active.contains(b.status)).toList();
            return TabBarView(children: [
              _List(bookings: active, user: user, asProvider: asProvider, emptyText: asProvider ? 'No active jobs. New requests appear here.' : 'No active bookings. Find a provider from Home.'),
              _List(bookings: past, user: user, asProvider: asProvider, emptyText: 'Nothing here yet.'),
            ]);
          },
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<Booking> bookings;
  final AppUser user;
  final bool asProvider;
  final String emptyText;
  const _List({required this.bookings, required this.user, required this.asProvider, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return EmptyState(icon: Icons.event_busy_rounded, title: emptyText);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final b = bookings[i];
        return Reveal(
          index: i,
          child: BookingCard(
            booking: b,
            otherName: asProvider ? b.clientName : b.providerName,
            photoUrl: asProvider ? null : b.providerPhotoUrl,
            showPrice: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id, user: user))),
          ),
        );
      },
    );
  }
}

/// One booking in a list: who, what, when and its current status.
class BookingCard extends StatelessWidget {
  final Booking booking;
  final String otherName;
  final String? photoUrl;
  final bool showPrice;
  final VoidCallback onTap;
  const BookingCard({super.key, required this.booking, required this.otherName, this.photoUrl, this.showPrice = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final b = booking;
    return HoverCard(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(url: photoUrl, name: otherName),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.serviceTitle, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(otherName, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 14, color: c.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${fmtDate(b.serviceDate)} · ${b.timeSlot}${showPrice && b.quotedFeeCents != null ? ' · ${money(b.quotedFeeCents!)}' : ''}',
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            StatusChip(b.status),
          ]),
        ),
      ]),
    );
  }
}
