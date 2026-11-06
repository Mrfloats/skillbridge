import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';

/// Client-provider chat for one booking (FR-7).
class ChatScreen extends StatefulWidget {
  final Booking booking;
  final AppUser user;
  const ChatScreen({super.key, required this.booking, required this.user});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _openedAt = DateTime.now();
  bool _sending = false;

  String get _otherName => widget.user.uid == widget.booking.clientId ? widget.booking.providerName : widget.booking.clientName;

  Future<void> _send({String? imageUrl}) async {
    final text = _text.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    setState(() => _sending = true);
    try {
      await Db.instance.sendMessage(widget.booking.id, widget.user.uid, widget.user.fullName, text: text, imageUrl: imageUrl);
      _text.clear();
    } catch (e) {
      if (mounted) showSnack(context, 'Message not sent. Check your connection.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto() async {
    final f = await PhotoService.instance.pick();
    if (f == null) return;
    setState(() => _sending = true);
    try {
      final url = await PhotoService.instance.uploadPublic(f, widget.user.uid);
      await _send(imageUrl: url);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showSnack(context, 'Photo not sent.', error: true);
      }
    }
  }

  Future<void> _report(ChatMessage m) async {
    final reason = await textPrompt(context, 'Report message', hint: 'Why are you reporting this?', minLength: 3);
    if (reason == null || !mounted) return;
    await runGuarded(context, () => Api.instance.reportContent('message', '${widget.booking.id}/${m.id}', reason), success: 'Reported to admins');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Avatar(name: _otherName, radius: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_otherName, style: t.titleMedium, overflow: TextOverflow.ellipsis),
              Text(widget.booking.serviceTitle, style: t.bodySmall, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: Db.instance.messages(widget.booking.id),
            builder: (context, snap) {
              if (snap.hasError) {
                return const EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Messages could not load',
                  message: 'Check your connection and open this chat again.',
                );
              }
              if (!snap.hasData) return const Loading();
              final msgs = snap.data!;
              for (final m in msgs) {
                if (m.senderId != widget.user.uid && m.readAt == null) {
                  Db.instance.markRead(widget.booking.id, m.id).catchError((_) {});
                }
              }
              if (msgs.isEmpty) {
                return const EmptyState(icon: Icons.forum_outlined, title: 'No messages yet', message: 'Agree on details here. Keep all payments in the app.');
              }
              return ListView.custom(
                reverse: true,
                padding: const EdgeInsets.all(12),
                childrenDelegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final m = msgs[i];
                    final mine = m.senderId == widget.user.uid;
                    final isNew = m.createdAt == null || m.createdAt!.isAfter(_openedAt);
                    return KeyedSubtree(
                      key: ValueKey(m.id),
                      child: Reveal(
                        animate: isNew,
                        offset: Offset(mine ? 20 : -20, 8),
                        child: _Bubble(message: m, mine: mine, onReport: mine ? null : () => _report(m)),
                      ),
                    );
                  },
                  childCount: msgs.length,
                  // Keeps existing bubbles in place, so only a new message animates in.
                  findChildIndexCallback: (key) {
                    final i = msgs.indexWhere((m) => ValueKey(m.id) == key);
                    return i < 0 ? null : i;
                  },
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.photo_camera_outlined), tooltip: 'Send a photo', onPressed: _sending ? null : _sendPhoto),
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Send',
                style: IconButton.styleFrom(backgroundColor: context.palette.accent, foregroundColor: context.palette.onAccent),
                onPressed: _sending ? null : () => _send(),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final VoidCallback? onReport;
  const _Bubble({required this.message, required this.mine, this.onReport});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final palette = context.palette;
    final m = message;
    final foreground = mine ? Colors.white : c.onSurface;
    final faded = mine ? Colors.white.withAlpha(190) : c.onSurfaceVariant;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onReport,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
          decoration: BoxDecoration(
            gradient: mine ? palette.heroGradient : null,
            color: mine ? null : c.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 5),
              bottomRight: Radius.circular(mine ? 5 : 18),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (m.imageUrl != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image(image: StoredImage(m.imageUrl!), width: 200, fit: BoxFit.cover)),
            if (m.text.isNotEmpty) Text(m.text, style: TextStyle(color: foreground)),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(fmtTime(m.createdAt), style: TextStyle(fontSize: 10, color: faded)),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(m.readAt != null ? Icons.done_all_rounded : Icons.done_rounded, size: 13, color: m.readAt != null ? palette.accent : faded),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
