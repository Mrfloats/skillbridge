import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';

/// Provider business profile, service area and price list (FR-3.1 – FR-3.4).
class ProviderSetupScreen extends StatefulWidget {
  final AppUser user;
  const ProviderSetupScreen({super.key, required this.user});
  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  final _bio = TextEditingController();
  final _years = TextEditingController();
  final _hours = TextEditingController();
  final _address = TextEditingController();
  double _radius = 10;
  ProviderProfile? _loaded;
  bool _saving = false;

  void _load(ProviderProfile p) {
    if (_loaded != null) return;
    _loaded = p;
    _bio.text = p.bio;
    _years.text = p.experienceYears.toString();
    _hours.text = p.workingHours;
    _address.text = p.baseAddress;
    _radius = p.serviceRadiusKm;
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    await runGuarded(context, () => Db.instance.updateProvider(widget.user.uid, {
          'bio': _bio.text.trim(),
          'experienceYears': int.tryParse(_years.text) ?? 0,
          'workingHours': _hours.text.trim(),
          'baseAddress': _address.text.trim(),
          'serviceRadiusKm': _radius,
        }), success: 'Profile saved');
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _setLocation() async {
    final loc = await LocationService.instance.current();
    if (!mounted) return;
    if (loc == null) {
      showSnack(context, 'Turn on location and try again.', error: true);
      return;
    }
    await runGuarded(context, () => Db.instance.updateProvider(widget.user.uid, {'baseLocation': loc}), success: 'Base location set to where you are now');
  }

  Future<void> _editService(List<ServiceCategory> cats, ProviderProfile p, [ProviderService? existing]) async {
    String categoryId = existing?.categoryId ?? (cats.isNotEmpty ? cats.first.id : '');
    String priceType = existing?.priceType ?? 'quote';
    final title = TextEditingController(text: existing?.title ?? '');
    final price = TextEditingController(text: existing == null ? '' : (existing.basePriceCents / 100).toStringAsFixed(2));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(existing == null ? 'Add a service' : 'Edit service', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: categoryId.isEmpty ? null : categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setS(() => categoryId = v ?? categoryId),
            ),
            const SizedBox(height: 12),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Service name', hintText: 'e.g. Fix leaking geyser')),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'quote', label: Text('Quote on request')),
                ButtonSegment(value: 'fixed', label: Text('Fixed price')),
              ],
              selected: {priceType},
              onSelectionChanged: (s) => setS(() => priceType = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: priceType == 'fixed' ? 'Price' : 'Starting from (call-out fee)'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final cents = parseMoneyToCents(price.text) ?? 0;
    if (title.text.trim().length < 3 || categoryId.isEmpty) {
      showSnack(context, 'Enter a service name and category.', error: true);
      return;
    }
    await runGuarded(context, () async {
      await Db.instance.saveProviderService(ProviderService(
        id: existing?.id ?? '',
        providerId: widget.user.uid,
        categoryId: categoryId,
        title: title.text.trim(),
        basePriceCents: cents,
        priceType: priceType,
      ));
      if (!p.categoryIds.contains(categoryId)) {
        await Db.instance.updateProvider(widget.user.uid, {'categoryIds': [...p.categoryIds, categoryId]});
      }
    });
  }

  Future<void> _deleteService(ProviderService s, List<ProviderService> all, ProviderProfile p) async {
    if (!await confirmDialog(context, 'Remove service?', s.title, ok: 'Remove', danger: true)) return;
    if (!mounted) return;
    await runGuarded(context, () async {
      await Db.instance.deleteProviderService(s.id);
      final stillUsed = all.any((x) => x.id != s.id && x.categoryId == s.categoryId);
      if (!stillUsed) {
        await Db.instance.updateProvider(widget.user.uid, {'categoryIds': p.categoryIds.where((c) => c != s.categoryId).toList()});
      }
    });
  }

  Future<void> _addPortfolio(ProviderProfile p) async {
    final f = await PhotoService.instance.pick();
    if (f == null || !mounted) return;
    await runGuarded(context, () async {
      final url = await PhotoService.instance.uploadPublic(f, widget.user.uid);
      await Db.instance.updateProvider(widget.user.uid, {'portfolioUrls': [...p.portfolioUrls, url]});
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProviderProfile?>(
      stream: Db.instance.provider(widget.user.uid),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return const Scaffold(body: Loading());
        _load(p);
        return Scaffold(
          appBar: AppBar(title: const Text('Business profile')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: _bio, maxLines: 4, maxLength: 400, decoration: const InputDecoration(labelText: 'About you', hintText: 'Skills, experience, what makes your work stand out')),
            const SizedBox(height: 12),
            TextField(controller: _years, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Years of experience')),
            const SizedBox(height: 12),
            TextField(controller: _hours, decoration: const InputDecoration(labelText: 'Working hours', hintText: 'Mon-Sat 08:00-18:00')),
            const SizedBox(height: 12),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Area you are based in', hintText: 'e.g. Kuwadzana')),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(p.baseLocation == null ? Icons.location_off : Icons.location_on, color: p.baseLocation == null ? Theme.of(context).colorScheme.error : Colors.green),
                title: Text(p.baseLocation == null ? 'Base location not set' : 'Base location set'),
                subtitle: const Text('Used to match you with nearby clients'),
                trailing: TextButton(onPressed: _setLocation, child: const Text('Use my location')),
              ),
            ),
            const SizedBox(height: 8),
            Text('I travel up to ${_radius.round()} km'),
            Slider(value: _radius.clamp(2.0, 50.0).toDouble(), min: 2, max: 50, divisions: 24, label: '${_radius.round()} km', onChanged: (v) => setState(() => _radius = v)),
            FilledButton(onPressed: _saving ? null : _saveProfile, child: const Text('Save profile')),
            StreamBuilder<List<ServiceCategory>>(
              stream: Db.instance.categories(),
              builder: (context, cSnap) {
                final cats = cSnap.data ?? [];
                final names = {for (final c in cats) c.id: c.name};
                return StreamBuilder<List<ProviderService>>(
                  stream: Db.instance.providerServices(widget.user.uid),
                  builder: (context, sSnap) {
                    final services = sSnap.data ?? [];
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SectionTitle('Services & prices',
                          trailing: TextButton.icon(onPressed: cats.isEmpty ? null : () => _editService(cats, p), icon: const Icon(Icons.add), label: const Text('Add'))),
                      if (services.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Add at least one service so clients can book you.')),
                      for (final s in services)
                        ListTile(
                          title: Text(s.title),
                          subtitle: Text('${names[s.categoryId] ?? s.categoryId} · ${s.priceType == 'fixed' ? money(s.basePriceCents) : 'From ${money(s.basePriceCents)}'}'),
                          onTap: () => _editService(cats, p, s),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteService(s, services, p)),
                        ),
                    ]);
                  },
                );
              },
            ),
            SectionTitle('Portfolio', trailing: TextButton.icon(onPressed: () => _addPortfolio(p), icon: const Icon(Icons.add_a_photo), label: const Text('Add'))),
            if (p.portfolioUrls.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Photos of past work help clients choose you.')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final url in p.portfolioUrls)
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image(image: StoredImage(url), width: 100, height: 100, fit: BoxFit.cover)),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      iconSize: 16,
                      icon: const Icon(Icons.close),
                      onPressed: () => Db.instance.updateProvider(widget.user.uid, {'portfolioUrls': p.portfolioUrls.where((u) => u != url).toList()}),
                    ),
                  ),
                ]),
            ]),
          ]),
        );
      },
    );
  }
}
