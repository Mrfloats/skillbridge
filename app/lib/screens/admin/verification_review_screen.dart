import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';

/// Admin compares ID, selfie and details, then approves or rejects (FR-2.4, FR-12.1).
class VerificationReviewScreen extends StatelessWidget {
  final ProviderProfile provider;
  const VerificationReviewScreen({super.key, required this.provider});

  Future<List<(String, String)>> _loadImages() async {
    final docs = await Db.instance.verificationDocs(provider.uid);
    if (docs == null) return [];
    final out = <(String, String)>[];
    void add(String label, dynamic path) {
      if (path is String && path.isNotEmpty) out.add((label, path));
    }

    add('National ID', docs['idImagePath']);
    add('Selfie', docs['selfiePath']);
    final certs = docs['certificatePaths'];
    if (certs is List) {
      for (var i = 0; i < certs.length; i++) {
        add('Certificate ${i + 1}', certs[i]);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Scaffold(
      appBar: AppBar(title: Text(p.fullName)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Column(children: [
            ListTile(title: const Text('Name'), subtitle: Text(p.fullName)),
            ListTile(title: const Text('Phone'), subtitle: Text(p.phone)),
            ListTile(title: const Text('Area'), subtitle: Text(p.baseAddress.isEmpty ? 'Not set' : p.baseAddress)),
            ListTile(title: const Text('Experience'), subtitle: Text('${p.experienceYears} years')),
          ]),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<(String, String)>>(
          future: _loadImages(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(32), child: Loading());
            final images = snap.data ?? [];
            if (images.isEmpty) {
              return const EmptyState(icon: Icons.hourglass_empty, title: 'No documents uploaded yet', message: 'The provider has not submitted their ID.');
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (label, reference) in images) ...[
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(child: Image(image: StoredImage(reference), fit: BoxFit.contain)),
                ),
                const SizedBox(height: 16),
              ],
            ]);
          },
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final reason = await textPrompt(context, 'Reject verification', hint: 'Reason the provider will see, e.g. "ID photo is blurry"', ok: 'Reject', minLength: 5);
                  if (reason == null || !context.mounted) return;
                  final ok = await runGuarded(context, () => Api.instance.reviewProvider(p.uid, false, reason: reason), success: 'Provider rejected');
                  if (ok && context.mounted) Navigator.pop(context);
                },
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  final ok = await runGuarded(context, () => Api.instance.reviewProvider(p.uid, true), success: '${p.fullName} is now verified');
                  if (ok && context.mounted) Navigator.pop(context);
                },
                child: const Text('Approve'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
