import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import '../client/provider_detail_screen.dart';
import '../shared/booking_detail_screen.dart';
import '../shared/notifications_screen.dart';
import 'provider_setup_screen.dart';
import 'verification_screen.dart';

/// Provider dashboard: requests, calendar, earnings, ratings, availability (FR-11).
class ProviderDashboardScreen extends StatelessWidget {
  final AppUser user;
  const ProviderDashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProviderProfile?>(
      stream: Db.instance.provider(user.uid),
      builder: (context, pSnap) {
        final p = pSnap.data;
        if (p == null) return const Scaffold(body: Loading());
        return Scaffold(
          appBar: AppBar(
            leading: const Center(child: BrandMark(size: 32)),
            title: const Text('Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(user: user))),
              ),
            ],
          ),
          body: StreamBuilder<List<Booking>>(
            stream: Db.instance.bookingsFor(user.uid, asProvider: true),
            builder: (context, bSnap) {
              final bookings = bSnap.data ?? [];
              return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                _VerificationBanner(provider: p, user: user),
                _SetupBanner(provider: p, user: user),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Reveal(
                    child: AnimatedContainer(
                      duration: Motion.medium,
                      curve: Motion.emphasized,
                      decoration: BoxDecoration(
                        color: p.isAvailable ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.isAvailable ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(p.isAvailable ? 'Available for bookings' : 'Not taking bookings'),
                          subtitle: Text('Clients only see you in search when this is on',
                              style: p.isAvailable ? TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer) : null),
                          value: p.isAvailable,
                          onChanged: (v) => runGuarded(context, () => Db.instance.updateProvider(user.uid, {'isAvailable': v})),
                        ),
                      ),
                    ),
                  ),
                ),
                _Stats(bookings: bookings, provider: p),
                _Requests(bookings: bookings, user: user),
                _Upcoming(bookings: bookings, user: user),
                _RecentReviews(provider: p),
              ]);
            },
          ),
        );
      },
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  final ProviderProfile provider;
  final AppUser user;
  const _VerificationBanner({required this.provider, required this.user});
  @override
  Widget build(BuildContext context) {
    if (provider.isVerified) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    final rejected = provider.verificationStatus == 'rejected';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Reveal(
        child: _Banner(
          color: rejected ? c.errorContainer : c.tertiaryContainer,
          foreground: rejected ? c.onErrorContainer : c.onTertiaryContainer,
          icon: rejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
          title: rejected ? 'Verification unsuccessful' : 'Verification pending',
          subtitle: rejected ? 'Reason: ${provider.rejectionReason ?? 'not given'}. Tap to resubmit.' : 'Upload your ID and selfie. Clients will see you once approved.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationScreen(user: user))),
        ),
      ),
    );
  }
}

class _SetupBanner extends StatelessWidget {
  final ProviderProfile provider;
  final AppUser user;
  const _SetupBanner({required this.provider, required this.user});
  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (provider.categoryIds.isEmpty) 'services',
      if (provider.baseLocation == null) 'location',
      if (provider.bio.isEmpty) 'bio',
    ];
    if (missing.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Reveal(
        index: 1,
        child: _Banner(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          foreground: Theme.of(context).colorScheme.onSurface,
          icon: Icons.storefront_outlined,
          title: 'Finish your profile',
          subtitle: 'Add your ${missing.join(', ')} so clients can find you.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderSetupScreen(user: user))),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final List<Booking> bookings;
  final ProviderProfile provider;
  const _Stats({required this.bookings, required this.provider});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    int earned(DateTime from) =>
        bookings.where((b) => b.status == BookingStatus.closed && !b.serviceDate.isBefore(from)).fold(0, (s, b) => s + (b.quotedFeeCents ?? 0) - (b.commissionCents ?? 0));
    int jobs(DateTime from) => bookings.where((b) => b.status == BookingStatus.closed && !b.serviceDate.isBefore(from)).length;

    final t = Theme.of(context).textTheme;
    final palette = context.palette;

    Widget tile(String label, Widget value, String sub) => Expanded(
          child: HoverCard(
            hoverable: true,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: t.bodySmall),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
              const SizedBox(height: 2),
              Text(sub, style: t.bodySmall),
            ]),
          ),
        );

    Widget moneyValue(int cents, TextStyle? style) => CountUp(value: cents.toDouble(), format: (v) => money(v.round()), style: style);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Reveal(
          index: 1,
          child: HoverCard(
            hoverable: true,
            gradient: palette.heroGradient,
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: double.infinity,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Earned this month', style: t.bodyMedium?.copyWith(color: Colors.white.withAlpha(215))),
                const SizedBox(height: 6),
                moneyValue(earned(monthStart), t.displaySmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text('${jobs(monthStart)} jobs', style: t.bodySmall?.copyWith(color: palette.accent, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Reveal(
          index: 2,
          child: Row(children: [
            tile('Today', moneyValue(earned(today), t.titleLarge), '${jobs(today)} jobs'),
            const SizedBox(width: 10),
            tile('This week', moneyValue(earned(weekStart), t.titleLarge), '${jobs(weekStart)} jobs'),
          ]),
        ),
        const SizedBox(height: 10),
        Reveal(
          index: 3,
          child: Row(children: [
            tile('Rating', CountUp(value: provider.avgRating, format: (v) => v.toStringAsFixed(1), style: t.titleLarge), '${provider.reviewCount} reviews'),
            const SizedBox(width: 10),
            tile('All-time jobs', CountUp(value: provider.completedJobs.toDouble(), format: (v) => '${v.round()}', style: t.titleLarge), 'completed'),
          ]),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final Color foreground;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Banner({required this.color, required this.foreground, required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HoverCard(
      color: color,
      onTap: onTap,
      builder: (context, hovered) => Row(children: [
        Icon(icon, color: foreground),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium?.copyWith(color: foreground)),
            Text(subtitle, style: t.bodySmall?.copyWith(color: foreground)),
          ]),
        ),
        AnimatedSlide(
          offset: hovered ? const Offset(0.25, 0) : Offset.zero,
          duration: Motion.medium,
          curve: Motion.emphasized,
          child: Icon(Icons.chevron_right_rounded, color: foreground),
        ),
      ]),
    );
  }
}

class _Requests extends StatelessWidget {
  final List<Booking> bookings;
  final AppUser user;
  const _Requests({required this.bookings, required this.user});
  @override
  Widget build(BuildContext context) {
    final pending = bookings.where((b) => b.status == BookingStatus.pending).toList();
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SectionTitle('New requests (${pending.length})'),
      for (final b in pending)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Reveal(
            child: _Banner(
              color: Theme.of(context).colorScheme.secondaryContainer,
              foreground: Theme.of(context).colorScheme.onSecondaryContainer,
              icon: Icons.notifications_active_rounded,
              title: b.serviceTitle,
              subtitle: '${b.clientName} · ${fmtDate(b.serviceDate)} ${b.timeSlot}\n${b.address}',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id, user: user))),
            ),
          ),
        ),
    ]);
  }
}

class _Upcoming extends StatelessWidget {
  final List<Booking> bookings;
  final AppUser user;
  const _Upcoming({required this.bookings, required this.user});
  @override
  Widget build(BuildContext context) {
    final upcoming = bookings.where((b) => BookingStatus.onSite.contains(b.status) || b.status == BookingStatus.awaitingPayment).toList()
      ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
    final byDay = <String, List<Booking>>{};
    for (final b in upcoming) {
      byDay.putIfAbsent(fmtDate(b.serviceDate), () => []).add(b);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Schedule'),
      if (upcoming.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No upcoming jobs.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      for (final entry in byDay.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
        ),
        for (final b in entry.value)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Reveal(
              child: HoverCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id, user: user))),
                child: Row(children: [
                  Text(b.timeSlot.split('-').first, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.serviceTitle, style: Theme.of(context).textTheme.titleSmall),
                      Text(b.clientName, style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  StatusChip(b.status),
                ]),
              ),
            ),
          ),
      ],
    ]);
  }
}

class _RecentReviews extends StatelessWidget {
  final ProviderProfile provider;
  const _RecentReviews({required this.provider});

  Future<void> _reply(BuildContext context, Review r) async {
    final text = await textPrompt(context, 'Reply to ${r.clientName}', hint: 'Your public reply (once only)', minLength: 2);
    if (text == null || !context.mounted) return;
    await runGuarded(context, () => Db.instance.replyToReview(r.id, text), success: 'Reply posted');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: Db.instance.reviewsFor(provider.uid, limit: 5),
      builder: (context, snap) {
        final reviews = snap.data ?? [];
        if (reviews.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          const SectionTitle('Recent reviews'),
          for (final r in reviews)
            ReviewTile(
              review: r,
              trailing: r.providerReply == null ? IconButton(icon: const Icon(Icons.reply), tooltip: 'Reply', onPressed: () => _reply(context, r)) : null,
            ),
        ]);
      },
    );
  }
}
