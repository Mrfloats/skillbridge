import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';

/// Upload national ID, selfie and certificates for admin review (FR-2.1, FR-2.2, FR-2.7).
class VerificationScreen extends StatefulWidget {
  final AppUser user;
  const VerificationScreen({super.key, required this.user});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  XFile? _id;
  XFile? _selfie;
  final List<XFile> _certs = [];
  bool _busy = false;

  Future<void> _submit(ProviderProfile p) async {
    if (_id == null || _selfie == null) {
      showSnack(context, 'Add both your national ID and a selfie.', error: true);
      return;
    }
    setState(() => _busy = true);
    final uid = widget.user.uid;
    final ok = await runGuarded(context, () async {
      final photos = PhotoService.instance;
      final idPath = await photos.uploadPrivate(_id!, uid);
      final selfiePath = await photos.uploadPrivate(_selfie!, uid);
      final certPaths = <String>[];
      for (final cert in _certs) {
        certPaths.add(await photos.uploadPrivate(cert, uid));
      }
      await Db.instance.submitVerification(uid, {'idImagePath': idPath, 'selfiePath': selfiePath, 'certificatePaths': certPaths});
      if (p.verificationStatus == 'rejected') await Db.instance.updateProvider(uid, {'verificationStatus': 'pending'});
    }, success: 'Documents submitted. We will notify you after review.');
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) Navigator.pop(context);
  }

  Widget _picker(String title, String hint, XFile? file, ValueChanged<XFile> onPicked, {bool camera = false}) {
    return Card(
      child: ListTile(
        leading: Icon(file == null ? Icons.add_photo_alternate_outlined : Icons.check_circle, color: file == null ? null : context.palette.success),
        title: Text(title),
        subtitle: Text(file == null ? hint : 'Ready to upload'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final f = await PhotoService.instance.pick(camera: camera);
          if (f != null) onPicked(f);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<ProviderProfile?>(
      stream: Db.instance.provider(widget.user.uid),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return const Scaffold(body: Loading());
        return Scaffold(
          appBar: AppBar(title: const Text('ID verification')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (p.isVerified)
              Card(child: ListTile(leading: Icon(Icons.verified_rounded, color: context.palette.success), title: const Text('You are verified'), subtitle: const Text('Your Verified badge is showing to clients.')))
            else ...[
              Text('Clients trust verified providers. Your documents are seen only by SkillBridge admins.', style: t.bodyMedium),
              const SizedBox(height: 16),
              _picker('National ID', 'Photo of the front of your ID', _id, (f) => setState(() => _id = f)),
              _picker('Selfie', 'A clear photo of your face', _selfie, (f) => setState(() => _selfie = f), camera: true),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Trade certificates (optional)'),
                  subtitle: Text(_certs.isEmpty ? 'Add qualifications to stand out' : '${_certs.length} added'),
                  trailing: const Icon(Icons.add),
                  onTap: () async {
                    final f = await PhotoService.instance.pick();
                    if (f != null) setState(() => _certs.add(f));
                  },
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : () => _submit(p),
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit for review'),
              ),
            ],
          ]),
        );
      },
    );
  }
}
