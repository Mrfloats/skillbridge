import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';
import '../shared/booking_detail_screen.dart';
import 'verification_review_screen.dart';

/// Admin console: verification, SOS, disputes, payouts, users, reports (FR-12).
class AdminShell extends StatelessWidget {
  final AppUser user;
  const AdminShell({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SkillBridge Admin'),
          actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Log out', onPressed: AuthService.instance.logout)],
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(child: _CountLabel('SOS', Db.instance.sosAlerts().map((l) => l.where((a) => a.status == 'open').length), urgent: true)),
            Tab(child: _CountLabel('Verify', Db.instance.pendingProviders().map((l) => l.length))),
            Tab(child: _CountLabel('Disputes', Db.instance.openDisputes().map((l) => l.length))),
            Tab(child: _CountLabel('Payouts', Db.instance.pendingWithdrawals().map((l) => l.length))),
            const Tab(text: 'Users'),
            const Tab(text: 'Reports'),
          ]),
        ),
        body: TabBarView(children: [
          _SosTab(admin: user),
          _VerifyTab(admin: user),
          _DisputesTab(admin: user),
          const _PayoutsTab(),
          const _UsersTab(),
          const _ReportsTab(),
        ]),
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  final String label;
  final Stream<int> count;
  final bool urgent;
  const _CountLabel(this.label, this.count, {this.urgent = false});
  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
        stream: count,
        builder: (context, snap) {
          final n = snap.data ?? 0;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label),
            if (n > 0) ...[
              const SizedBox(width: 6),
              Badge(label: Text('$n'), backgroundColor: urgent ? Theme.of(context).colorScheme.error : null),
            ],
          ]);
        },
      );
}

// ---------------- SOS ----------------
class _SosTab extends StatelessWidget {
  final AppUser admin;
  const _SosTab({required this.admin});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return StreamBuilder<List<SosAlert>>(
      stream: Db.instance.sosAlerts(),
      builder: (context, snap) {
        if (!snap.hasData) return const Loading();
        final alerts = snap.data!;
        if (alerts.isEmpty) return const EmptyState(icon: Icons.health_and_safety_outlined, title: 'No active SOS alerts');
        return ListView(padding: const EdgeInsets.all(12), children: [
          for (final a in alerts)
            Card(
              color: a.status == 'open' ? c.errorContainer : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.sos, color: c.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.userName, style: Theme.of(context).textTheme.titleMedium)),
                    Text(fmtDateTime(a.createdAt)),
                  ]),
                  Text('With: ${a.otherPartyName} · Status: ${a.status}'),
                  Wrap(spacing: 8, children: [
                    TextButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${a.userPhone}')), icon: const Icon(Icons.call), label: const Text('Call user')),
                    if (a.location != null)
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse('https://maps.google.com/?q=${a.location!.latitude},${a.location!.longitude}'), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.map),
                        label: const Text('Location'),
                      ),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: a.bookingId, user: admin))),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Booking'),
                    ),
                  ]),
                  Row(children: [
                    if (a.status == 'open')
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(120, 40)),
                        onPressed: () => runGuarded(context, () => Api.instance.resolveSos(a.id, 'acknowledged')),
                        child: const Text('Acknowledge'),
                      ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(120, 40)),
                      onPressed: () async {
                        final note = await textPrompt(context, 'Resolve SOS', hint: 'What happened and what action was taken?', minLength: 5);
                        if (note != null && context.mounted) await runGuarded(context, () => Api.instance.resolveSos(a.id, 'resolved', note: note));
                      },
                      child: const Text('Resolve'),
                    ),
                  ]),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ---------------- Verification ----------------
class _VerifyTab extends StatelessWidget {
  final AppUser admin;
  const _VerifyTab({required this.admin});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProviderProfile>>(
      stream: Db.instance.pendingProviders(),
      builder: (context, snap) {
        if (!snap.hasData) return const Loading();
        final list = snap.data!;
        if (list.isEmpty) return const EmptyState(icon: Icons.verified_user_outlined, title: 'No providers waiting');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = list[i];
            return ListTile(
              leading: Avatar(url: p.photoUrl, name: p.fullName),
              title: Text(p.fullName),
              subtitle: Text('${p.phone} · ${p.baseAddress.isEmpty ? 'no area set' : p.baseAddress}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationReviewScreen(provider: p))),
            );
          },
        );
      },
    );
  }
}

// ---------------- Disputes ----------------
class _DisputesTab extends StatelessWidget {
  final AppUser admin;
  const _DisputesTab({required this.admin});

  Future<void> _resolve(BuildContext context, Dispute d) async {
    var outcome = 'release';
    var percent = 50.0;
    final note = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Resolve dispute', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'release', label: Text('Pay provider')),
                ButtonSegment(value: 'refund', label: Text('Refund client')),
                ButtonSegment(value: 'split', label: Text('Split')),
              ],
              selected: {outcome},
              onSelectionChanged: (s) => setS(() => outcome = s.first),
            ),
            if (outcome == 'split') ...[
              const SizedBox(height: 12),
              Text('Provider gets ${percent.round()}%, client gets ${100 - percent.round()}%'),
              Slider(value: percent, min: 0, max: 100, divisions: 20, onChanged: (v) => setS(() => percent = v)),
            ],
            const SizedBox(height: 12),
            TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Decision note (shared in audit log)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm decision')),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await runGuarded(
      context,
      () => Api.instance.resolveDispute(d.bookingId, outcome, providerPercent: outcome == 'split' ? percent.round() : null, note: note.text),
      success: 'Dispute resolved',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Dispute>>(
      stream: Db.instance.openDisputes(),
      builder: (context, snap) {
        if (!snap.hasData) return const Loading();
        final list = snap.data!;
        if (list.isEmpty) return const EmptyState(icon: Icons.gavel_outlined, title: 'No open disputes');
        return ListView(padding: const EdgeInsets.all(12), children: [
          for (final d in list)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Opened ${fmtDateTime(d.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(d.reason),
                  const SizedBox(height: 8),
                  Row(children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: d.bookingId, user: admin))),
                      child: const Text('Booking'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ChatTranscript(chatId: d.bookingId))),
                      child: const Text('Chat log'),
                    ),
                    const Spacer(),
                    FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 40)), onPressed: () => _resolve(context, d), child: const Text('Decide')),
                  ]),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _ChatTranscript extends StatelessWidget {
  final String chatId;
  const _ChatTranscript({required this.chatId});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chat log')),
        body: StreamBuilder<List<ChatMessage>>(
          stream: Db.instance.messages(chatId),
          builder: (context, snap) {
            if (!snap.hasData) return const Loading();
            final msgs = snap.data!.reversed.toList();
            if (msgs.isEmpty) return const EmptyState(icon: Icons.forum_outlined, title: 'No messages');
            return ListView(children: [
              for (final m in msgs)
                ListTile(
                  title: Text(m.senderName),
                  subtitle: Text(m.text.isEmpty ? '[photo]' : m.text),
                  trailing: Text(fmtDateTime(m.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  onTap: m.imageUrl == null
                      ? null
                      : () => showAppDialog<void>(
                            context: context,
                            builder: (ctx) => Dialog(child: InteractiveViewer(child: Image(image: StoredImage(m.imageUrl!), fit: BoxFit.contain))),
                          ),
                ),
            ]);
          },
        ),
      );
}

// ---------------- Payouts ----------------
class _PayoutsTab extends StatelessWidget {
  const _PayoutsTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Withdrawal>>(
      stream: Db.instance.pendingWithdrawals(),
      builder: (context, snap) {
        if (!snap.hasData) return const Loading();
        final list = snap.data!;
        if (list.isEmpty) return const EmptyState(icon: Icons.payments_outlined, title: 'No pending payouts');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final w = list[i];
            return ListTile(
              title: Text('${money(w.amountCents)} → ${w.method}'),
              subtitle: Text('${w.destination}\nRequested ${fmtDateTime(w.createdAt)}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'paid') {
                    final ref = await textPrompt(context, 'Mark as paid', hint: 'Transfer reference', ok: 'Mark paid', minLength: 3, keyboard: TextInputType.text);
                    if (ref != null && context.mounted) await runGuarded(context, () => Api.instance.markWithdrawalPaid(w.id, reference: ref));
                  } else {
                    if (await confirmDialog(context, 'Reject payout?', 'Funds return to the user\'s wallet.', ok: 'Reject', danger: true) && context.mounted) {
                      await runGuarded(context, () => Api.instance.markWithdrawalPaid(w.id, reject: true));
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'paid', child: Text('Mark as paid')),
                  PopupMenuItem(value: 'reject', child: Text('Reject')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------- Users ----------------
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  Future<List<AppUser>> _results = Db.instance.searchUsers('');

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SearchBar(
          hintText: 'Search by name, phone or email',
          leading: const Icon(Icons.search),
          elevation: WidgetStateProperty.all(0.0),
          onSubmitted: (q) => setState(() => _results = Db.instance.searchUsers(q)),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<AppUser>>(
          future: _results,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            final users = snap.data ?? [];
            if (users.isEmpty) return const EmptyState(icon: Icons.person_off_outlined, title: 'No users found');
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = users[i];
                return ListTile(
                  leading: Avatar(url: u.photoUrl, name: u.fullName),
                  title: Text(u.fullName),
                  subtitle: Text('${u.role} · ${u.phone}\n${u.email}'),
                  isThreeLine: true,
                  trailing: u.role == 'admin'
                      ? const Chip(label: Text('Admin'))
                      : Switch(
                          value: !u.isSuspended,
                          onChanged: (active) async {
                            final ok = await confirmDialog(context, active ? 'Reactivate ${u.fullName}?' : 'Suspend ${u.fullName}?',
                                active ? 'They will be able to log in again.' : 'They will be logged out and blocked.', danger: !active);
                            if (!ok || !context.mounted) return;
                            await runGuarded(context, () => Api.instance.setUserSuspended(u.uid, !active));
                            setState(() => _results = Db.instance.searchUsers(''));
                          },
                        ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ---------------- Reports ----------------
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  late DateTimeRange _range;
  Future<Map<String, int>>? _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month), end: now.add(const Duration(days: 1)));
    _load();
  }

  void _load() => setState(() => _data = Db.instance.report(_range.start, _range.end));

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      OutlinedButton.icon(
        icon: const Icon(Icons.date_range),
        label: Text('${fmtDate(_range.start)} – ${fmtDate(_range.end)}'),
        onPressed: () async {
          final r = await showDateRangePicker(context: context, firstDate: DateTime(2025), lastDate: DateTime.now().add(const Duration(days: 1)), initialDateRange: _range);
          if (r != null) {
            _range = r;
            _load();
          }
        },
      ),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, int>>(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Loading();
          if (snap.hasError) return Text('Could not load report: ${snap.error}');
          final d = snap.data ?? {};
          return Card(
            child: Column(children: [
              for (final e in d.entries)
                ListTile(
                  title: Text(e.key.replaceAll(' (cents)', '')),
                  trailing: Text(e.key.contains('cents') ? money(e.value) : '${e.value}', style: Theme.of(context).textTheme.titleMedium),
                ),
            ]),
          );
        },
      ),
      const SizedBox(height: 16),
      Text('Revenue is commission on released payments. Server timestamps are used for all dates.',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text('Live data from Firestore at ${fmtDateTime(Timestamp.now().toDate())}.', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
