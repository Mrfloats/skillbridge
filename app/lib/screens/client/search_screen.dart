import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';
import 'provider_detail_screen.dart';

enum SortBy { distance, rating, jobs }

/// Search, filter and sort verified providers near the client (FR-4).
class SearchScreen extends StatefulWidget {
  final AppUser user;
  final ServiceCategory? category;
  final String query;
  final bool nearestMode;
  const SearchScreen({super.key, required this.user, this.category, this.query = '', this.nearestMode = false});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  ServiceCategory? _category;
  double _maxKm = 15;
  double _minRating = 0;
  SortBy _sort = SortBy.distance;
  GeoPoint? _here;
  bool _usingFallback = false;
  Future<List<ProviderMatch>>? _results;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _locateAndSearch();
  }

  Future<void> _locateAndSearch() async {
    final real = await LocationService.instance.current();
    final here = real ?? await LocationService.instance.current(fallbackToHarare: true);
    if (!mounted) return;
    setState(() {
      _here = here;
      _usingFallback = real == null;
    });
    _search();
  }

  void _search() {
    if (_here == null) return;
    setState(() {
      _results = Db.instance.searchProviders(
        categoryId: _category?.id,
        lat: _here!.latitude,
        lng: _here!.longitude,
        maxDistanceKm: _maxKm,
        minRating: _minRating,
        query: widget.query,
      );
    });
  }

  List<ProviderMatch> _sorted(List<ProviderMatch> list) {
    final l = [...list];
    switch (_sort) {
      case SortBy.distance:
        l.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      case SortBy.rating:
        l.sort((a, b) => b.provider.avgRating.compareTo(a.provider.avgRating));
      case SortBy.jobs:
        l.sort((a, b) => b.provider.completedJobs.compareTo(a.provider.completedJobs));
    }
    return l;
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Filters', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text('Distance: up to ${_maxKm.round()} km', style: Theme.of(ctx).textTheme.titleSmall),
            Slider(value: _maxKm, min: 2, max: 50, divisions: 24, onChanged: (v) => setSheet(() => _maxKm = v)),
            Text(_minRating == 0 ? 'Any rating' : 'Rating: ${_minRating.toStringAsFixed(1)}★ and up', style: Theme.of(ctx).textTheme.titleSmall),
            Slider(value: _minRating, min: 0, max: 5, divisions: 10, onChanged: (v) => setSheet(() => _minRating = v)),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Apply')),
          ]),
        ),
      ),
    );
    _search();
  }

  Widget _chip(String label, bool selected, VoidCallback onSelected) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, showCheckmark: false, onSelected: (_) => onSelected()),
      );

  @override
  Widget build(BuildContext context) {
    final title = widget.nearestMode
        ? 'Nearest providers'
        : _category?.name ?? (widget.query.isNotEmpty ? '"${widget.query}"' : 'All providers');
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(icon: const Icon(Icons.tune_rounded), tooltip: 'Filters', onPressed: _openFilters),
      ]),
      body: Column(children: [
        SizedBox(
          height: 56,
          child: StreamBuilder<List<ServiceCategory>>(
            stream: Db.instance.categories(),
            builder: (context, snap) {
              final cats = snap.data ?? [];
              return ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), children: [
                _chip('All', _category == null, () {
                  _category = null;
                  _search();
                }),
                for (final cat in cats)
                  _chip(cat.name, _category?.id == cat.id, () {
                    _category = cat;
                    _search();
                  }),
              ]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Sort:'),
            const SizedBox(width: 8),
            DropdownButton<SortBy>(
              value: _sort,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(16),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              items: const [
                DropdownMenuItem(value: SortBy.distance, child: Text('Nearest')),
                DropdownMenuItem(value: SortBy.rating, child: Text('Top rated')),
                DropdownMenuItem(value: SortBy.jobs, child: Text('Most jobs')),
              ],
              onChanged: (v) => setState(() => _sort = v ?? SortBy.distance),
            ),
            const Spacer(),
            if (_usingFallback)
              const Tooltip(
                message: 'Location is off, so distances are from Harare CBD',
                child: Chip(avatar: Icon(Icons.location_off_rounded, size: 16), label: Text('Harare CBD')),
              ),
          ]),
        ),
        Expanded(
          child: _results == null
              ? const SkeletonList()
              : FutureBuilder<List<ProviderMatch>>(
                  future: _results,
                  builder: (context, snap) => AnimatedSwitcher(duration: Motion.medium, child: _body(snap)),
                ),
        ),
      ]),
    );
  }

  Widget _body(AsyncSnapshot<List<ProviderMatch>> snap) {
    if (snap.connectionState != ConnectionState.done) return const SkeletonList(key: ValueKey('loading'));
    if (snap.hasError) {
      return EmptyState(
        key: const ValueKey('error'),
        icon: Icons.wifi_off_rounded,
        title: 'Could not load providers',
        message: 'Check your connection.',
        action: OutlinedButton(onPressed: _search, child: const Text('Try again')),
      );
    }
    var list = _sorted(snap.data ?? []);
    if (widget.nearestMode && list.isNotEmpty) list = list.take(5).toList();
    if (list.isEmpty) {
      return EmptyState(
        key: const ValueKey('empty'),
        icon: Icons.person_search_rounded,
        title: 'No providers found',
        message: 'Try a larger distance or another service.',
        action: OutlinedButton(onPressed: _openFilters, child: const Text('Change filters')),
      );
    }
    return RefreshIndicator(
      key: ValueKey('results-${list.map((m) => m.provider.uid).join()}'),
      onRefresh: () async => _search(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Reveal(index: i, child: _ProviderCard(match: list[i], user: widget.user)),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final ProviderMatch match;
  final AppUser user;
  const _ProviderCard({required this.match, required this.user});

  @override
  Widget build(BuildContext context) {
    final p = match.provider;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    Widget fact(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: c.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(text, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ]);
    return HoverCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderDetailScreen(providerId: p.uid, user: user, distanceKm: match.distanceKm))),
      builder: (context, hovered) => Row(children: [
        Hero(tag: 'provider-${p.uid}', child: Avatar(url: p.photoUrl, name: p.fullName, radius: 30)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(p.fullName, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              const VerifiedBadge(),
            ]),
            const SizedBox(height: 3),
            RatingStars(p.avgRating, count: p.reviewCount, size: 15),
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 2, children: [
              fact(Icons.near_me_outlined, '${match.distanceKm.toStringAsFixed(1)} km away'),
              fact(Icons.task_alt_rounded, '${p.completedJobs} jobs'),
              fact(Icons.workspace_premium_outlined, '${p.experienceYears} yrs exp'),
            ]),
          ]),
        ),
        AnimatedSlide(
          offset: hovered ? const Offset(0.25, 0) : Offset.zero,
          duration: Motion.medium,
          curve: Motion.emphasized,
          child: Icon(Icons.chevron_right_rounded, color: hovered ? c.onSurface : c.onSurfaceVariant),
        ),
      ]),
    );
  }
}
