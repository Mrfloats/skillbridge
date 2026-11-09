import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

/// One booking, from either side: status timeline and the actions allowed now (FR-5, FR-6, FR-8, FR-9).
class BookingDetailScreen extends StatelessWidget {
  final String bookingId;
  final AppUser user;
  const BookingDetailScreen({super.key, required this.bookingId, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Booking>(
      stream: Db.instance.booking(bookingId),
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.lock, title: 'Booking not available'));
        final b = snap.data;
        if (b == null) return const Scaffold(body: Loading());
        final isProvider = user.uid == b.providerId;
        final isAdmin = user.role == Roles.admin;
        final chatOpen = !isAdmin && ![BookingStatus.cancelled, BookingStatus.declined, BookingStatus.expired].contains(b.status);
        return Scaffold(
          appBar: AppBar(title: Text(b.serviceTitle), actions: [
            if (chatOpen)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Chat',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(booking: b, user: user))),
              ),
          ]),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (BookingStatus.onSite.contains(b.status) && !isAdmin) ...[Reveal(child: _SosBanner(booking: b, user: user)), const SizedBox(height: 12)],
            Reveal(index: 1, child: _Header(booking: b, isProvider: isProvider)),
            if (b.reschedule != null) ...[const SizedBox(height: 12), Reveal(child: _RescheduleBanner(booking: b, user: user))],
            const SizedBox(height: 12),
            Reveal(index: 2, child: _Details(booking: b, isProvider: isProvider)),
            const SizedBox(height: 12),
            Reveal(index: 3, child: _Timeline(booking: b)),
            const SizedBox(height: 16),
            if (!isAdmin) Reveal(index: 4, child: _Actions(booking: b, user: user, isProvider: isProvider)),
          ]),
        );
      },
    );
  }
}

/// The client's rating from other providers, so a provider can see it before taking the job.
class _ClientRating extends StatefulWidget {
  final String clientId;
  const _ClientRating({required this.clientId});
  @override
  State<_ClientRating> createState() => _ClientRatingState();
}

class _ClientRatingState extends State<_ClientRating> {
  // Kept across rebuilds, so booking updates do not restart the listener.
  late final _rating = Db.instance.clientRating(widget.clientId);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return StreamBuilder<RatingSummary?>(
      stream: _rating,
      builder: (context, snap) {
        final r = snap.data;
        if (r == null || r.count == 0) return Text(snap.connectionState == ConnectionState.waiting ? 'Client' : 'Client · no ratings yet', style: style);
        return Row(children: [Text('Client · ', style: style), Flexible(child: RatingStars(r.average, count: r.count, size: 14))]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Booking booking;
  final bool isProvider;
  const _Header({required this.booking, required this.isProvider});

  /// How the quote gets paid: the provider sees their charge, the client who to pay.
  String? get _paymentNote {
    final b = booking;
    if (const [BookingStatus.cancelled, BookingStatus.declined, BookingStatus.expired].contains(b.status)) return null;
    if (isProvider) {
      final charge = money(b.commissionCents ?? commissionOn(b.quotedFeeCents!));
      return b.status == BookingStatus.closed ? 'Service charge: $charge' : 'Service charge when the job closes: $charge';
    }
    final viaEscrow = const ['held', 'released', 'refunded'].contains(b.paymentStatus);
    return viaEscrow ? null : 'Pay ${b.providerName.split(' ').first} directly. SkillBridge does not hold this money.';
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final t = Theme.of(context).textTheme;
    final name = isProvider ? b.clientName : b.providerName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(url: isProvider ? null : b.providerPhotoUrl, name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
                  if (!isProvider) ...[const SizedBox(width: 4), const VerifiedBadge()],
                ]),
                if (isProvider) _ClientRating(clientId: b.clientId) else Text('Your provider', style: t.bodySmall),
              ]),
            ),
            StatusChip(b.status),
          ]),
          const Divider(height: 24),
          Row(children: [
            const Icon(Icons.event, size: 18),
            const SizedBox(width: 8),
            Text('${fmtDate(b.serviceDate)} · ${b.timeSlot}'),
          ]),
          if (b.quotedFeeCents != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.payments_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Quote: ${money(b.quotedFeeCents!)}', style: t.titleSmall),
              const SizedBox(width: 8),
              if (b.paymentStatus == 'held') const Chip(label: Text('Paid · held safely'), visualDensity: VisualDensity.compact),
              if (b.paymentStatus == 'released') const Chip(label: Text('Paid out'), visualDensity: VisualDensity.compact),
              if (b.paymentStatus == 'refunded') const Chip(label: Text('Refunded'), visualDensity: VisualDensity.compact),
            ]),
            if (_paymentNote != null) ...[
              const SizedBox(height: 4),
              Padding(padding: const EdgeInsets.only(left: 26), child: Text(_paymentNote!, style: t.bodySmall)),
            ],
          ],
        ]),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final Booking booking;
  final bool isProvider;
  const _Details({required this.booking, required this.isProvider});
  @override
  Widget build(BuildContext context) {
    final b = booking;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Job details', style: t.titleSmall),
          const SizedBox(height: 8),
          Text(b.description),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.place_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(b.address)),
            if (b.location != null)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${b.location!.latitude},${b.location!.longitude}'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Directions'),
              ),
          ]),
          if (isProvider && BookingStatus.onSite.contains(b.status) && b.clientPhone.isNotEmpty)
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${b.clientPhone}')),
              icon: const Icon(Icons.call),
              label: Text('Call ${b.clientName.split(' ').first}'),
            ),
          if (b.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: b.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(image: StoredImage(b.photoUrls[i]), width: 90, height: 90, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final Booking booking;
  const _Timeline({required this.booking});
  @override
  Widget build(BuildContext context) {
    final entries = booking.timeline;
    if (entries.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Progress', style: t.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < entries.length; i++)
            // A vertical track joins the dots, and each step draws in after the last.
            Reveal(
              index: i,
              offset: const Offset(-10, 0),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 20,
                    child: Column(children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor(entries[i].status, Theme.of(context).colorScheme),
                          shape: BoxShape.circle,
                          boxShadow: i == entries.length - 1 ? [BoxShadow(color: statusColor(entries[i].status, Theme.of(context).colorScheme).withAlpha(90), spreadRadius: 4)] : null,
                        ),
                      ),
                      if (i != entries.length - 1) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: Theme.of(context).colorScheme.outlineVariant)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(children: [
                        Expanded(child: Text(statusLabel(entries[i].status), style: t.bodyMedium?.copyWith(fontWeight: i == entries.length - 1 ? FontWeight.w700 : FontWeight.w500))),
                        Text(fmtDateTime(entries[i].at), style: t.bodySmall),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _SosBanner extends StatelessWidget {
  final Booking booking;
  final AppUser user;
  const _SosBanner({required this.booking, required this.user});

  Future<void> _sos(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      'Send SOS alert?',
      'SkillBridge admins and your trusted contacts will get your location and booking details right away.',
      ok: 'Send SOS',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final loc = await LocationService.instance.current();
    if (!context.mounted) return;
    await runGuarded(context, () => Db.instance.raiseSos(booking: booking, user: user, location: loc), success: 'SOS sent. Help is being contacted. If in danger call 999 (police).');
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      color: c.errorContainer,
      child: ListTile(
        leading: Icon(Icons.sos, color: c.onErrorContainer, size: 32),
        title: Text('Feel unsafe?', style: TextStyle(color: c.onErrorContainer, fontWeight: FontWeight.w700)),
        subtitle: Text('Tap SOS to alert admins and your trusted contacts', style: TextStyle(color: c.onErrorContainer)),
        trailing: PulseRing(
          color: c.error,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.error, foregroundColor: c.onError, minimumSize: const Size(72, 44)),
            onPressed: () => _sos(context),
            child: const Text('SOS'),
          ),
        ),
      ),
    );
  }
}

class _RescheduleBanner extends StatelessWidget {
  final Booking booking;
  final AppUser user;
  const _RescheduleBanner({required this.booking, required this.user});
  @override
  Widget build(BuildContext context) {
    final r = booking.reschedule!;
    final mine = r.requestedBy == user.uid;
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mine ? 'You proposed a new time' : 'New time proposed', style: Theme.of(context).textTheme.titleSmall),
          Text('${fmtDate(r.serviceDate)} · ${r.timeSlot}'),
          if (!mine)
            Row(children: [
              TextButton(
                onPressed: () => runGuarded(context, () => Api.instance.respondToReschedule(booking.id, false)),
                child: const Text('Decline'),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
                onPressed: () => runGuarded(context, () => Api.instance.respondToReschedule(booking.id, true), success: 'Booking moved'),
                child: const Text('Accept'),
              ),
            ])
          else
            const Text('Waiting for the other party to respond.'),
        ]),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final Booking booking;
  final AppUser user;
  final bool isProvider;
  const _Actions({required this.booking, required this.user, required this.isProvider});

  Booking get b => booking;

  Future<void> _accept(BuildContext context) async {
    final input = await textPrompt(context, 'Your quote (${AppConfig.currencySymbol})',
        message: 'The client pays you directly. A $commissionLabel service charge comes off your balance when the job closes.',
        hint: 'e.g. 35.00',
        ok: 'Send quote',
        keyboard: const TextInputType.numberWithOptions(decimal: true));
    if (input == null || !context.mounted) return;
    final cents = parseMoneyToCents(input);
    if (cents == null || cents < 100) {
      showSnack(context, 'Enter an amount of at least 1.00', error: true);
      return;
    }
    await runGuarded(context, () => Api.instance.respondToBooking(b.id, accept: true, feeCents: cents), success: 'Quote sent');
  }

  Future<void> _cancel(BuildContext context) async {
    final late = !isProvider && b.paymentStatus == 'held' && b.serviceDate.difference(DateTime.now()).inHours < 24;
    final reason = await textPrompt(
      context,
      'Cancel booking',
      hint: late ? 'Reason. Less than 24 h before the job, a 20% late fee goes to the provider.' : 'Reason for cancelling',
      ok: 'Cancel booking',
      minLength: 3,
    );
    if (reason == null || !context.mounted) return;
    await runGuarded(context, () async {
      final refund = await Api.instance.cancelBooking(b.id, reason);
      if (refund > 0 && context.mounted) showSnack(context, '${money(refund)} refunded to your wallet');
    });
  }

  Future<void> _reschedule(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: b.serviceDate.isAfter(now) ? b.serviceDate : now, firstDate: now, lastDate: now.add(const Duration(days: 60)));
    if (d == null || !context.mounted) return;
    final slot = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in AppConfig.timeSlots) ListTile(title: Text(s), onTap: () => Navigator.pop(ctx, s)),
        ]),
      ),
    );
    if (slot == null || !context.mounted) return;
    final start = DateTime(d.year, d.month, d.day, int.parse(slot.substring(0, 2)));
    if (start.isBefore(now)) {
      showSnack(context, 'Pick a time in the future.', error: true);
      return;
    }
    await runGuarded(context, () => Db.instance.proposeReschedule(b.id, user.uid, start, slot), success: 'New time proposed');
  }

  Future<void> _dispute(BuildContext context) async {
    final reason = await textPrompt(context, 'Report a problem', hint: 'What went wrong? An admin will review it.', minLength: 10);
    if (reason == null || !context.mounted) return;
    await runGuarded(context, () => Api.instance.raiseDispute(b.id, reason), success: 'Dispute opened. An admin will contact you.');
  }

  /// Asks for 1 to 5 stars, plus a comment when [comment] is given. Returns null if the user backs out.
  Future<int?> _askStars(BuildContext context, String title, {TextEditingController? comment, String? note}) async {
    var rating = 5;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: context.palette.star, size: 36),
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  onPressed: () => setD(() => rating = i),
                ),
            ]),
            if (comment != null) TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(hintText: 'Tell others about the job (optional)')),
            if (note != null) Text(note, style: Theme.of(ctx).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(88, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    return ok == true ? rating : null;
  }

  Future<void> _review(BuildContext context) async {
    final comment = TextEditingController();
    final rating = await _askStars(context, 'Rate ${b.providerName.split(' ').first}', comment: comment);
    if (rating == null || !context.mounted) return;
    await runGuarded(context, () => Db.instance.submitReview(b, user.fullName, rating, comment.text), success: 'Thanks for your review');
  }

  Future<void> _rateClient(BuildContext context) async {
    final rating = await _askStars(context, 'Rate ${b.clientName.split(' ').first}', note: 'Other providers see the client\'s average rating, not who gave it.');
    if (rating == null || !context.mounted) return;
    await runGuarded(context, () => Api.instance.rateClient(b.id, rating), success: 'Thanks for rating your client');
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    void primary(String label, VoidCallback onTap, {IconData? icon}) => buttons.add(FilledButton.icon(onPressed: onTap, icon: Icon(icon ?? Icons.check), label: Text(label)));
    void secondary(String label, VoidCallback onTap, {IconData? icon}) => buttons.add(OutlinedButton.icon(onPressed: onTap, icon: Icon(icon ?? Icons.more_horiz), label: Text(label)));
    void danger(String label, VoidCallback onTap) => buttons.add(TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, minimumSize: const Size.fromHeight(44)),
          child: Text(label),
        ));

    final canReschedule = b.reschedule == null && [BookingStatus.pending, BookingStatus.awaitingPayment, BookingStatus.confirmed].contains(b.status);

    if (isProvider) {
      switch (b.status) {
        case BookingStatus.pending:
          primary('Accept & send quote', () => _accept(context), icon: Icons.request_quote);
          danger('Decline', () => runGuarded(context, () => Api.instance.respondToBooking(b.id, accept: false)));
        case BookingStatus.awaitingPayment:
          buttons.add(const Text('Waiting for the client to accept your quote. You will be notified.', textAlign: TextAlign.center));
        case BookingStatus.confirmed:
          primary("I'm on my way", () => runGuarded(context, () => Api.instance.updateJobStatus(b.id, BookingStatus.inTransit)), icon: Icons.directions_car);
        case BookingStatus.inTransit:
          primary('Start job', () => runGuarded(context, () => Api.instance.updateJobStatus(b.id, BookingStatus.inProgress)), icon: Icons.play_arrow);
        case BookingStatus.inProgress:
          primary('Mark job complete', () async {
            final ok = await confirmDialog(context, 'Job complete?', 'The client will be asked to confirm. The job closes when they do, or automatically after 48 hours.');
            if (ok && context.mounted) await runGuarded(context, () => Api.instance.updateJobStatus(b.id, BookingStatus.completed));
          }, icon: Icons.task_alt);
        case BookingStatus.completed:
          buttons.add(const Text('Waiting for client confirmation. The job closes automatically after 48 hours.', textAlign: TextAlign.center));
        case BookingStatus.closed:
          if (!b.clientRated) primary('Rate ${b.clientName.split(' ').first}', () => _rateClient(context), icon: Icons.star);
      }
    } else {
      switch (b.status) {
        case BookingStatus.awaitingPayment:
          primary('Accept quote of ${money(b.quotedFeeCents ?? 0)}', () async {
            final ok = await confirmDialog(context, 'Accept this quote?', 'You pay ${b.providerName} ${money(b.quotedFeeCents ?? 0)} directly. SkillBridge does not hold this money.', ok: 'Accept');
            if (ok && context.mounted) await runGuarded(context, () => Api.instance.acceptQuote(b.id), success: 'Booking confirmed');
          }, icon: Icons.handshake_outlined);
        case BookingStatus.completed:
          primary('Confirm job done', () async {
            final ok = await confirmDialog(context, 'Is the job done?', 'Only confirm if the work is finished. This closes the booking.');
            if (ok && context.mounted) await runGuarded(context, () => Api.instance.confirmCompletion(b.id), success: 'Job closed. Thank you!');
          }, icon: Icons.verified);
          secondary('Report a problem', () => _dispute(context), icon: Icons.report_problem_outlined);
        case BookingStatus.closed:
          if (!b.reviewed) primary('Rate this job', () => _review(context), icon: Icons.star);
      }
      if ([BookingStatus.confirmed, BookingStatus.inTransit, BookingStatus.inProgress].contains(b.status)) {
        secondary('Report a problem', () => _dispute(context), icon: Icons.report_problem_outlined);
      }
    }

    if (canReschedule) secondary('Propose new time', () => _reschedule(context), icon: Icons.schedule);
    if ([BookingStatus.pending, BookingStatus.awaitingPayment, BookingStatus.confirmed].contains(b.status)) {
      danger('Cancel booking', () => _cancel(context));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final w in buttons) Padding(padding: const EdgeInsets.only(bottom: 8), child: w),
    ]);
  }
}
