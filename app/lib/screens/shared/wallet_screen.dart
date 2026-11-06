import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

/// Balance, history and withdrawals (FR-6.6, FR-6.8).
class WalletScreen extends StatelessWidget {
  final AppUser user;
  const WalletScreen({super.key, required this.user});

  Future<void> _withdraw(BuildContext context, int balance) async {
    final amount = TextEditingController(text: (balance / 100).toStringAsFixed(2));
    final dest = TextEditingController(text: toLocalPhone(user.phone));
    var method = 'ecocash';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Withdraw funds', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(labelText: 'Send to'),
              borderRadius: BorderRadius.circular(16),
              items: const [
                DropdownMenuItem(value: 'ecocash', child: Text('EcoCash')),
                DropdownMenuItem(value: 'onemoney', child: Text('OneMoney')),
                DropdownMenuItem(value: 'bank', child: Text('Bank account')),
              ],
              onChanged: (v) => setS(() => method = v ?? 'ecocash'),
            ),
            const SizedBox(height: 12),
            TextField(controller: dest, decoration: InputDecoration(labelText: method == 'bank' ? 'Bank, branch and account number' : 'Mobile number')),
            const SizedBox(height: 8),
            Text('Withdrawals are processed by our team within 1 business day.', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request withdrawal')),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final cents = parseMoneyToCents(amount.text);
    if (cents == null || cents <= 0 || cents > balance) {
      showSnack(context, 'Enter an amount up to ${money(balance)}', error: true);
      return;
    }
    await runGuarded(context, () => Api.instance.requestWithdrawal(cents, method, dest.text.trim()), success: 'Withdrawal requested');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        StreamBuilder<int>(
          stream: Db.instance.walletBalance(user.uid),
          builder: (context, snap) {
            final bal = snap.data ?? 0;
            final canWithdraw = bal >= 500;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Reveal(
                child: HoverCard(
                  hoverable: true,
                  gradient: palette.heroGradient,
                  padding: const EdgeInsets.all(22),
                  borderRadius: BorderRadius.circular(26),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 18, color: palette.accent),
                      const SizedBox(width: 6),
                      Text('Available balance', style: t.bodyMedium?.copyWith(color: Colors.white.withAlpha(215))),
                    ]),
                    const SizedBox(height: 8),
                    CountUp(
                      value: bal.toDouble(),
                      format: (v) => money(v.round()),
                      style: t.displayMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 18),
                    if (canWithdraw)
                      GlowButton(label: 'Withdraw', onPressed: () => _withdraw(context, bal))
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(22), borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          'Minimum withdrawal ${money(500)}',
                          textAlign: TextAlign.center,
                          style: t.labelLarge?.copyWith(color: Colors.white.withAlpha(215)),
                        ),
                      ),
                  ]),
                ),
              ),
            );
          },
        ),
        StreamBuilder<List<Withdrawal>>(
          stream: Db.instance.withdrawalsFor(user.uid),
          builder: (context, snap) {
            final pending = (snap.data ?? []).where((w) => w.status == 'pending').toList();
            if (pending.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Pending withdrawals'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Column(children: [
                    for (final w in pending)
                      ListTile(
                        leading: Icon(Icons.hourglass_top_rounded, color: palette.warning),
                        title: Text(money(w.amountCents)),
                        subtitle: Text('${w.method} · ${w.destination}'),
                        trailing: Text(fmtDate(w.createdAt), style: t.bodySmall),
                      ),
                  ]),
                ),
              ),
            ]);
          },
        ),
        const SectionTitle('History'),
        StreamBuilder<List<WalletTxn>>(
          stream: Db.instance.walletTxns(user.uid),
          builder: (context, snap) {
            final txns = snap.data ?? [];
            if (txns.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Reveal(
                  index: 1,
                  child: Row(children: [
                    Icon(Icons.receipt_long_outlined, color: c.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text('No transactions yet.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                  ]),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                for (var i = 0; i < txns.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Reveal(
                      index: i,
                      child: _TxnRow(txn: txns[i]),
                    ),
                  ),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final WalletTxn txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final credit = txn.amountCents >= 0;
    final color = credit ? context.palette.success : c.error;
    return HoverCard(
      hoverable: true,
      lift: 2,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withAlpha(32), shape: BoxShape.circle),
          child: Icon(credit ? Icons.south_west_rounded : Icons.north_east_rounded, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txn.note, style: t.titleSmall),
            Text(fmtDateTime(txn.createdAt), style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(
          '${credit ? '+' : '-'}${money(txn.amountCents.abs())}',
          style: t.titleMedium?.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ]),
    );
  }
}
