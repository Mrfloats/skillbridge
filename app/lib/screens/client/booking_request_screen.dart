import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';
import '../shared/booking_detail_screen.dart';

/// Client requests a booking: date, slot, address, description, photos (FR-5.1).
class BookingRequestScreen extends StatefulWidget {
  final AppUser user;
  final ProviderProfile provider;
  final ProviderService service;
  const BookingRequestScreen({super.key, required this.user, required this.provider, required this.service});
  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _description = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _slot;
  GeoPoint? _location;
  final List<XFile> _photos = [];
  bool _busy = false;

  DateTime _slotStart(DateTime day, String slot) {
    final h = int.parse(slot.substring(0, 2));
    return DateTime(day.year, day.month, day.day, h);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (d != null) {
      setState(() {
        _date = d;
        _slot = null;
      });
    }
  }

  Future<void> _useMyLocation() async {
    final loc = await LocationService.instance.current();
    if (!mounted) return;
    if (loc == null) {
      showSnack(context, 'Turn on location to share it, or type your address.', error: true);
      return;
    }
    setState(() => _location = loc);
    showSnack(context, 'Location attached to your request');
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 4) return;
    final f = await PhotoService.instance.pick();
    if (f != null) setState(() => _photos.add(f));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_slot == null) {
      showSnack(context, 'Choose a time slot.', error: true);
      return;
    }
    final start = _slotStart(_date, _slot!);
    if (start.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      showSnack(context, 'Pick a time at least 1 hour from now.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        urls.add(await PhotoService.instance.uploadPublic(_photos[i], widget.user.uid));
      }
      final id = await Db.instance.createBooking({
        'clientId': widget.user.uid,
        'clientName': widget.user.fullName,
        'clientPhone': widget.user.phone,
        'providerId': widget.provider.uid,
        'providerName': widget.provider.fullName,
        'providerPhotoUrl': widget.provider.photoUrl,
        'providerServiceId': widget.service.id,
        'categoryId': widget.service.categoryId,
        'serviceTitle': widget.service.title,
        'serviceDate': Timestamp.fromDate(start),
        'timeSlot': _slot,
        'address': _address.text.trim(),
        'location': _location,
        'description': _description.text.trim(),
        'photoUrls': urls,
      });
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: id, user: widget.user)));
      showSnack(context, 'Request sent to ${widget.provider.fullName}');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not send request: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Request booking')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: ListTile(
              leading: Avatar(url: widget.provider.photoUrl, name: widget.provider.fullName),
              title: Text(widget.service.title),
              subtitle: Text(widget.provider.fullName),
              trailing: Text(widget.service.priceType == 'fixed' ? money(widget.service.basePriceCents) : 'Quote'),
            ),
          ),
          const SizedBox(height: 16),
          Text('When', style: t.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today), label: Text(fmtDate(_date))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in AppConfig.timeSlots)
              ChoiceChip(
                label: Text(s),
                showCheckmark: false,
                selected: _slot == s,
                onSelected: _slotStart(_date, s).isBefore(DateTime.now().add(const Duration(hours: 1))) ? null : (_) => setState(() => _slot = s),
              ),
          ]),
          const SizedBox(height: 20),
          Text('Where', style: t.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Address', hintText: 'e.g. 12 Fife Ave, Avondale'),
            validator: (v) => (v ?? '').trim().length >= 5 ? null : 'Enter the job address',
          ),
          TextButton.icon(
            onPressed: _useMyLocation,
            icon: Icon(_location == null ? Icons.my_location : Icons.check_circle),
            label: Text(_location == null ? 'Attach my current location' : 'Location attached'),
          ),
          const SizedBox(height: 12),
          Text('What needs doing', style: t.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Describe the problem so the provider can quote accurately'),
            validator: (v) => (v ?? '').trim().length >= 10 ? null : 'Add a few more details',
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _photos.length; i++)
              Chip(label: Text('Photo ${i + 1}'), onDeleted: () => setState(() => _photos.removeAt(i))),
            if (_photos.length < 4) ActionChip(avatar: const Icon(Icons.add_a_photo, size: 18), label: const Text('Add photo'), onPressed: _addPhoto),
          ]),
          const SizedBox(height: 24),
          Text('You pay only after the provider sends a quote and you accept it. Your money is held until the job is done.', style: t.bodySmall),
          const SizedBox(height: 12),
          GlowButton(label: 'Send request', busy: _busy, onPressed: _submit),
        ]),
      ),
    );
  }
}
