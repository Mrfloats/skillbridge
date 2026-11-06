import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';
import 'booking_request_screen.dart';

/// Provider profile seen by clients (FR-3.4, FR-2.6).
class ProviderDetailScreen extends StatelessWidget {
  final String providerId;
  final AppUser user;
  final double? distanceKm;
  const ProviderDetailScreen({super.key, required this.providerId, required this.user, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final palette = context.palette;
    return StreamBuilder<ProviderProfile?>(
      stream: Db.instance.provider(providerId),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return const Scaffold(body: Loading());
        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 270,
              backgroundColor: palette.heroStart,
              foregroundColor: Colors.white,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  onSelected: (_) async {
                    final reason = await textPrompt(context, 'Report this provider', hint: 'What happened?', minLength: 5);
                    if (reason == null || !context.mounted) return;
                    await runGuarded(context, () => Api.instance.reportContent('provider', p.uid, reason), success: 'Thanks. Our team will review it.');
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report provider'))],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                expandedTitleScale: 1.3,
                titlePadding: const EdgeInsets.fromLTRB(56, 0, 56, 16),
                title: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(
                      p.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge?.copyWith(color: Colors.white, fontSize: 19),
                    ),
                  ),
                  if (p.isVerified) ...[const SizedBox(width: 5), VerifiedBadge(color: palette.accent)],
                ]),
                background: Aurora(
                  child: SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: const Alignment(0, -0.1),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: palette.accent, width: 2)),
                        child: Hero(tag: 'provider-${p.uid}', child: Avatar(url: p.photoUrl, name: p.fullName, radius: 56)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverList.list(children: [
              const SizedBox(height: 18),
              Reveal(child: Center(child: RatingStars(p.avgRating, count: p.reviewCount, size: 20))),
              const SizedBox(height: 14),
              Reveal(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _Stat(label: 'Jobs done', icon: Icons.task_alt_rounded, value: '${p.completedJobs}'),
                    const SizedBox(width: 10),
                    _Stat(label: 'Experience', icon: Icons.workspace_premium_outlined, value: '${p.experienceYears} yrs'),
                    const SizedBox(width: 10),
                    _Stat(label: 'Distance', icon: Icons.near_me_outlined, value: distanceKm == null ? '-' : '${distanceKm!.toStringAsFixed(1)} km'),
                  ]),
                ),
              ),
              if (p.bio.isNotEmpty) ...[
                const SectionTitle('About'),
                Reveal(index: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(p.bio))),
              ],
              const SectionTitle('Working hours'),
              Reveal(
                index: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('${p.workingHours}\nBased in ${p.baseAddress.isEmpty ? 'Harare' : p.baseAddress} · covers ${p.serviceRadiusKm.round()} km'),
                ),
              ),
              const SectionTitle('Services'),
              StreamBuilder<List<ProviderService>>(
                stream: Db.instance.providerServices(p.uid),
                builder: (context, s) {
                  final services = s.data ?? [];
                  if (services.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No services listed yet.'));
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      for (var i = 0; i < services.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Reveal(index: i, child: _ServiceCard(service: services[i], provider: p, user: user)),
                        ),
                    ]),
                  );
                },
              ),
              if (p.portfolioUrls.isNotEmpty) ...[
                const SectionTitle('Past work'),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    itemCount: p.portfolioUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => HoverCard(
                      hoverable: true,
                      padding: EdgeInsets.zero,
                      child: Image(image: StoredImage(p.portfolioUrls[i]), width: 120, height: 120, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
              const SectionTitle('Reviews'),
              StreamBuilder<List<Review>>(
                stream: Db.instance.reviewsFor(p.uid, limit: 20),
                builder: (context, s) {
                  final reviews = s.data ?? [];
                  if (reviews.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No reviews yet.'));
                  return Column(children: [for (final r in reviews) ReviewTile(review: r)]);
                },
              ),
              const SizedBox(height: 32),
            ]),
          ]),
          bottomNavigationBar: !p.isAvailable
              ? const SafeArea(child: Padding(padding: EdgeInsets.all(16), child: Text('This provider is not taking bookings right now.', textAlign: TextAlign.center)))
              : null,
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ProviderService service;
  final ProviderProfile provider;
  final AppUser user;
  const _ServiceCard({required this.service, required this.provider, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final svc = service;
    return HoverCard(
      hoverable: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(svc.title, style: t.titleMedium),
            const SizedBox(height: 2),
            Text(svc.priceType == 'fixed' ? 'Fixed price' : 'From ${money(svc.basePriceCents)}, final quote after request', style: t.bodySmall),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: !provider.isAvailable
              ? null
              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingRequestScreen(user: user, provider: provider, service: svc))),
          child: Text(svc.priceType == 'fixed' ? money(svc.basePriceCents) : 'Request'),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: HoverCard(
        hoverable: true,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Icon(icon, size: 20, color: c.brightness == Brightness.dark ? c.primary : c.secondary),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: t.titleLarge)),
          Text(label, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class ReviewTile extends StatelessWidget {
  final Review review;
  final Widget? trailing;
  const ReviewTile({super.key, required this.review, this.trailing});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: HoverCard(
        hoverable: true,
        lift: 2,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: review.clientName, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(review.clientName, style: t.titleSmall),
                RatingStars(review.rating.toDouble(), size: 14),
              ]),
              if (review.comment.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(review.comment)),
              const SizedBox(height: 4),
              Text(fmtDate(review.createdAt), style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
              if (review.providerReply != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                  child: Text('Reply: ${review.providerReply}'),
                ),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}
