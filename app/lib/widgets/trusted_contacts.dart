import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/db.dart';
import 'common.dart';

/// The people who get an SMS if the user presses SOS (FR-9.3). Shown on the profile and
/// the Safety page. It follows the user's record itself, so changes show straight away
/// even on a page that was opened with an older copy of the user.
class TrustedContactsSection extends StatefulWidget {
  final AppUser user;
  const TrustedContactsSection({super.key, required this.user});
  @override
  State<TrustedContactsSection> createState() => _TrustedContactsSectionState();
}

class _TrustedContactsSectionState extends State<TrustedContactsSection> {
  late final _user = Db.instance.user(widget.user.uid);

  Future<void> _add(List<TrustedContact> current) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add trusted contact'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(88, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || phone.text.trim().length < 9 || !mounted) return;
    final list = [...current, TrustedContact(name.text.trim(), phone.text.trim())];
    await runGuarded(context, () => Db.instance.saveTrustedContacts(widget.user.uid, list));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return StreamBuilder<AppUser?>(
      stream: _user,
      initialData: widget.user,
      builder: (context, snap) {
        final contacts = (snap.data ?? widget.user).trustedContacts;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle('Trusted contacts',
              trailing: contacts.length < AppConfig.maxTrustedContacts ? TextButton.icon(onPressed: () => _add(contacts), icon: const Icon(Icons.add_rounded), label: const Text('Add')) : null),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('These people get an SMS with your location if you press SOS during a job.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ),
          if (contacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(children: [
                  for (final tc in contacts)
                    ListTile(
                      leading: const Icon(Icons.contact_emergency_outlined),
                      title: Text(tc.name),
                      subtitle: Text(tc.phone),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Remove',
                        onPressed: () => Db.instance.saveTrustedContacts(widget.user.uid, contacts.where((x) => x != tc).toList()),
                      ),
                    ),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
