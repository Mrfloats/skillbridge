import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import 'db.dart';

/// Picks photos and keeps them in Firestore, one document per photo, so the app
/// needs no Cloud Storage bucket. A Firestore document holds about 1 MB, so photos
/// are resized to fit, which also keeps them small on 3G (NFR-6.2).
class PhotoService {
  PhotoService._();
  static final instance = PhotoService._();

  /// Also enforced for public photos in firestore.rules.
  static const maxBytes = 1000000;

  final _picker = ImagePicker();
  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  Future<XFile?> pick({bool camera = false}) => _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );

  /// Saves a photo that any signed-in user holding the returned reference can open.
  Future<String> uploadPublic(XFile file, String ownerId) => _save(_fs.collection('images').doc(), file, ownerId);

  /// Saves a verification photo that only its owner and admins can open.
  Future<String> uploadPrivate(XFile file, String uid) =>
      _save(_fs.collection('providers').doc(uid).collection('private').doc(), file, uid);

  Future<String> _save(DocumentReference<Map<String, dynamic>> doc, XFile file, String ownerId) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) throw Exception('That photo is too large. Please choose a different one.');
    await doc.set({'ownerId': ownerId, 'data': Blob(bytes), 'createdAt': FieldValue.serverTimestamp()});
    return doc.path;
  }

  /// Photos never change once saved, so the device's copy is used when it has one.
  Future<Uint8List> read(String reference) async {
    final doc = _fs.doc(reference);
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await doc.get(const GetOptions(source: Source.cache));
    } on FirebaseException {
      snap = null;
    }
    if (snap == null || !snap.exists) snap = await doc.get();
    final data = snap.data()?['data'];
    if (data is! Blob) throw StateError('No photo at $reference');
    return data.bytes;
  }
}

/// Shows a photo saved by [PhotoService]. Works anywhere an [ImageProvider] does.
class StoredImage extends ImageProvider<StoredImage> {
  final String reference;
  const StoredImage(this.reference);

  @override
  Future<StoredImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(StoredImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _decode(key, decode), scale: 1, debugLabel: key.reference);

  static Future<ui.Codec> _decode(StoredImage key, ImageDecoderCallback decode) async {
    final bytes = await PhotoService.instance.read(key.reference);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is StoredImage && other.reference == reference;

  @override
  int get hashCode => reference.hashCode;
}

/// GPS access with a Harare fallback (FR-4.4).
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  Future<GeoPoint?> current({bool fallbackToHarare = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return fallbackToHarare ? const GeoPoint(AppConfig.harareLat, AppConfig.harareLng) : null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return fallbackToHarare ? const GeoPoint(AppConfig.harareLat, AppConfig.harareLng) : null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return fallbackToHarare ? const GeoPoint(AppConfig.harareLat, AppConfig.harareLng) : null;
    }
  }
}

/// Push notifications via FCM (FR-10.1).
class PushService {
  PushService._();
  static final instance = PushService._();

  Future<void> register(String uid, {bool isAdmin = false}) async {
    final fcm = FirebaseMessaging.instance;
    final settings = await fcm.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await fcm.getToken();
    if (token != null) await Db.instance.addFcmToken(uid, token);
    fcm.onTokenRefresh.listen((t) => Db.instance.addFcmToken(uid, t));
    if (isAdmin) await fcm.subscribeToTopic('admins');
  }
}
