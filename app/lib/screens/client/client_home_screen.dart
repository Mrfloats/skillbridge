import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import '../shared/booking_detail_screen.dart';
import '../shared/bookings_list_screen.dart';
import '../shared/notifications_screen.dart';
import 'search_screen.dart';

class ClientHomeScreen extends StatelessWidget {
  final AppUser user;
  const ClientHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final firstName = user.fullName.split(' ').first;
    return Scaffold(
      body: HeroScrollView(
        hero: HeroPanel(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 68),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Reveal(child: BrandLogo(height: 40)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                tooltip: 'Notifications',
                style: IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(26), hoverColor: Colors.white.withAlpha(46)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(user: user))),
              ),
            ]),
            const SizedBox(height: 14),
            Reveal(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hi, $firstName', style: t.displaySmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text('Who can we find for you today?', style: t.bodyMedium?.copyWith(color: Colors.white.withAlpha(205))),
              ]),
            ),
            const SizedBox(height: 20),
            Reveal(
              index: 1,
              child: SearchBar(
                hintText: 'What do you need done?',
                leading: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.search_rounded, color: c.onSurfaceVariant),
                ),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(c.surfaceContainerLowest),
                overlayColor: WidgetStatePropertyAll(c.primary.withAlpha(12)),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                constraints: const BoxConstraints(minHeight: 56),
                onSubmitted: (q) => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(user: user, query: q))),
              ),
            ),
          ]),
        ),
        children: [
          // Everything below is pulled up so the nearest-provider card overlaps the header.
          Transform.translate(
            offset: const Offset(0, -44),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Reveal(
                  index: 2,
                  child: _NearestCard(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(user: user, nearestMode: true))),
                  ),
                ),
              ),
              _UpcomingBooking(user: user),
              const SectionTitle('Services'),
              StreamBuilder<List<ServiceCategory>>(
                stream: Db.instance.categories(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Loading());
                  final cats = snap.data!;
                  if (cats.isEmpty) return const EmptyState(icon: Icons.category_outlined, title: 'No services yet');
                  return GridView.extent(
                    maxCrossAxisExtent: 150,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.88,
                    children: [
                      for (var i = 0; i < cats.length; i++)
                        Reveal(
                          index: i,
                          child: _CategoryTile(
                            category: cats[i],
                            tint: i % 3,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(user: user, category: cats[i]))),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NearestCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NearestCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final palette = context.palette;
    return HoverCard(
      gradient: palette.accentGradient,
      spotlightColor: Colors.white,
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      builder: (context, hovered) => Row(children: [
        AnimatedRotation(
          turns: hovered ? 0.06 : 0,
          duration: Motion.medium,
          curve: Motion.overshoot,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: palette.heroStart, shape: BoxShape.circle),
            child: Icon(Icons.near_me_rounded, color: palette.accent, size: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Find nearest provider', style: t.titleLarge?.copyWith(color: palette.onAccent)),
            const SizedBox(height: 2),
            Text('Verified help closest to you right now', style: t.bodySmall?.copyWith(color: palette.onAccent.withAlpha(215), fontWeight: FontWeight.w500)),
          ]),
        ),
        AnimatedSlide(
          offset: hovered ? const Offset(0.25, 0) : Offset.zero,
          duration: Motion.medium,
          curve: Motion.emphasized,
          child: Icon(Icons.arrow_forward_rounded, color: palette.onAccent),
        ),
      ]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ServiceCategory category;
  final int tint;
  final VoidCallback onTap;
  const _CategoryTile({required this.category, required this.tint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tint) {
      0 => (c.primaryContainer, c.onPrimaryContainer),
      1 => (c.secondaryContainer, c.onSecondaryContainer),
      _ => (c.tertiaryContainer, c.onTertiaryContainer),
    };
    return HoverCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
      builder: (context, hovered) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedScale(
          scale: hovered ? 1.14 : 1,
          duration: Motion.medium,
          curve: Motion.overshoot,
          child: AnimatedRotation(
            turns: hovered ? -0.035 : 0,
            duration: Motion.medium,
            curve: Motion.overshoot,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
              child: Icon(categoryIcon(category.icon), color: foreground, size: 25),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.labelMedium?.copyWith(height: 1.2),
          ),
        ),
      ]),
    );
  }
}

class _UpcomingBooking extends StatelessWidget {
  final AppUser user;
  const _UpcomingBooking({required this.user});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: Db.instance.bookingsFor(user.uid, asProvider: false),
      builder: (context, snap) {
        final active = (snap.data ?? []).where((b) => BookingStatus.active.contains(b.status)).toList()..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
        return AnimatedSize(
          duration: Motion.medium,
          curve: Motion.emphasized,
          alignment: Alignment.topCenter,
          child: active.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionTitle('Next booking', trailing: active.length > 1 ? Text('+${active.length - 1} more') : null),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Reveal(
                      child: BookingCard(
                        booking: active.first,
                        otherName: active.first.providerName,
                        photoUrl: active.first.providerPhotoUrl,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: active.first.id, user: user))),
                      ),
                    ),
                  ),
                ]),
        );
      },
    );
  }
}
