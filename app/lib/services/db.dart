import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../models/models.dart';

/// Firestore reads and the few writes the security rules allow from the app.
class Db {
  Db._();
  static final instance = Db._();
  final fs = FirebaseFirestore.instance;

  // ---------- Users ----------
  Stream<AppUser?> user(String uid) =>
      fs.collection('users').doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser?> getUser(String uid) async {
    final d = await fs.collection('users').doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) => fs.collection('users').doc(uid).update(data);

  Future<void> saveTrustedContacts(String uid, List<TrustedContact> contacts) =>
      updateUser(uid, {'trustedContacts': contacts.map((c) => c.toMap()).toList()});

  Future<void> addFcmToken(String uid, String token) =>
      updateUser(uid, {'fcmTokens': FieldValue.arrayUnion([token])});

  // ---------- Categories ----------
  Stream<List<ServiceCategory>> categories() => fs
      .collection('categories')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(ServiceCategory.fromDoc).toList()..sort((a, b) => a.order.compareTo(b.order)));

  // ---------- Providers ----------
  Stream<ProviderProfile?> provider(String uid) =>
      fs.collection('providers').doc(uid).snapshots().map((d) => d.exists ? ProviderProfile.fromDoc(d) : null);

  Future<void> updateProvider(String uid, Map<String, dynamic> data) =>
      fs.collection('providers').doc(uid).update(data);

  /// Verified, available, not suspended providers in a category, filtered by
  /// distance and the provider's own service radius (FR-4.1 – FR-4.5).
  /// For Harare-scale data this filters on the device; switch to geohash
  /// queries (e.g. geoflutterfire_plus) beyond ~5,000 providers.
  Future<List<ProviderMatch>> searchProviders({
    String? categoryId,
    required double lat,
    required double lng,
    double maxDistanceKm = AppConfig.defaultSearchRadiusKm,
    double minRating = 0,
    String query = '',
    String? excludeUid,
  }) async {
    Query<Map<String, dynamic>> q = fs.collection('providers').where('isVerified', isEqualTo: true);
    if (categoryId != null) q = q.where('categoryIds', arrayContains: categoryId);
    final snap = await q.limit(300).get();
    final needle = query.trim().toLowerCase();
    final results = <ProviderMatch>[];
    for (final d in snap.docs) {
      final p = ProviderProfile.fromDoc(d);
      // excludeUid: someone who is also a provider does not see themselves while booking.
      if (p.uid == excludeUid || p.isSuspended || !p.isAvailable || p.baseLocation == null) continue;
      if (p.avgRating < minRating) continue;
      if (needle.isNotEmpty && !p.fullName.toLowerCase().contains(needle) && !p.bio.toLowerCase().contains(needle)) {
        continue;
      }
      final km = distanceKm(lat, lng, p.baseLocation!.latitude, p.baseLocation!.longitude);
      if (km > maxDistanceKm || km > p.serviceRadiusKm) continue;
      results.add(ProviderMatch(p, km));
    }
    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  Stream<List<ProviderService>> providerServices(String providerId) => fs
      .collection('providerServices')
      .where('providerId', isEqualTo: providerId)
      .snapshots()
      .map((s) => s.docs.map(ProviderService.fromDoc).toList());

  Future<void> saveProviderService(ProviderService s) {
    final col = fs.collection('providerServices');
    return s.id.isEmpty ? col.add(s.toMap()) : col.doc(s.id).set(s.toMap());
  }

  Future<void> deleteProviderService(String id) => fs.collection('providerServices').doc(id).delete();

  Future<void> submitVerification(String uid, Map<String, dynamic> paths) async {
    await fs.collection('providers').doc(uid).collection('private').doc('verification').set({
      ...paths,
      'submittedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> verificationDocs(String uid) async =>
      (await fs.collection('providers').doc(uid).collection('private').doc('verification').get()).data();

  // ---------- Bookings ----------
  Future<String> createBooking(Map<String, dynamic> data) async {
    final ref = await fs.collection('bookings').add({
      ...data,
      'status': BookingStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<Booking> booking(String id) => fs.collection('bookings').doc(id).snapshots().map(Booking.fromDoc);

  Stream<List<Booking>> bookingsFor(String uid, {required bool asProvider}) => fs
      .collection('bookings')
      .where(asProvider ? 'providerId' : 'clientId', isEqualTo: uid)
      .orderBy('serviceDate', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Booking.fromDoc).toList());

  Future<void> proposeReschedule(String bookingId, String uid, DateTime date, String slot) =>
      fs.collection('bookings').doc(bookingId).update({
        'rescheduleRequest': {'requestedBy': uid, 'serviceDate': Timestamp.fromDate(date), 'timeSlot': slot},
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ---------- Reviews ----------
  Stream<List<Review>> reviewsFor(String providerId, {int limit = 50}) => fs
      .collection('reviews')
      .where('providerId', isEqualTo: providerId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Review.fromDoc).where((r) => !r.isHidden).toList());

  /// Review id = booking id, so one review per booking (FR-8.2).
  Future<void> submitReview(Booking b, String clientName, int rating, String comment) =>
      fs.collection('reviews').doc(b.id).set({
        'bookingId': b.id,
        'clientId': b.clientId,
        'clientName': clientName,
        'providerId': b.providerId,
        'rating': rating,
        'comment': comment.trim(),
        'isHidden': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> replyToReview(String reviewId, String reply) => fs.collection('reviews').doc(reviewId).update({
        'providerReply': reply.trim(),
        'repliedAt': FieldValue.serverTimestamp(),
      });

  /// A client's average rating from providers (FR-8.5). Null until they have been rated.
  Stream<RatingSummary?> clientRating(String clientId) => fs.collection('clientRatings').doc(clientId).snapshots().map((d) {
        final m = d.data();
        if (m == null) return null;
        return (average: (m['avgRating'] as num? ?? 0).toDouble(), count: (m['reviewCount'] as num? ?? 0).toInt());
      });

  // ---------- Chat ----------
  Stream<List<ChatMessage>> messages(String chatId) => fs
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  Future<void> sendMessage(String chatId, String senderId, String senderName, {String text = '', String? imageUrl}) =>
      fs.collection('chats').doc(chatId).collection('messages').add({
        'senderId': senderId,
        'senderName': senderName,
        'text': text.trim(),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> markRead(String chatId, String messageId) => fs
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId)
      .update({'readAt': FieldValue.serverTimestamp()});

  // ---------- Wallet ----------
  Stream<int> walletBalance(String uid) =>
      fs.collection('wallets').doc(uid).snapshots().map((d) => (d.data()?['balanceCents'] as num?)?.toInt() ?? 0);

  Stream<List<WalletTxn>> walletTxns(String uid) => fs
      .collection('wallets')
      .doc(uid)
      .collection('transactions')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(WalletTxn.fromDoc).toList());

  Stream<List<Withdrawal>> withdrawalsFor(String uid) => fs
      .collection('withdrawals')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Withdrawal.fromDoc).toList());

  // ---------- SOS ----------
  Future<void> raiseSos({
    required Booking booking,
    required AppUser user,
    required GeoPoint? location,
  }) {
    final isClient = user.uid == booking.clientId;
    return fs.collection('sosAlerts').add({
      'bookingId': booking.id,
      'userId': user.uid,
      'userName': user.fullName,
      'userPhone': user.phone,
      'otherPartyId': isClient ? booking.providerId : booking.clientId,
      'otherPartyName': isClient ? booking.providerName : booking.clientName,
      'location': location,
      'address': booking.address,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Notifications ----------
  Stream<List<AppNotification>> notifications(String uid) => fs
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  Future<void> markNotificationRead(String id) => fs.collection('notifications').doc(id).update({'isRead': true});

  // ---------- Support ----------
  /// The user's own messages to support, newest first. Sorted here, so no extra index is needed.
  Stream<List<SupportTicket>> mySupportTickets(String uid) => fs
      .collection('supportTickets')
      .where('userId', isEqualTo: uid)
      .limit(50)
      .snapshots()
      .map((s) => _newestFirst(s.docs.map(SupportTicket.fromDoc).toList()));

  Stream<List<SupportTicket>> openSupportTickets() => fs
      .collection('supportTickets')
      .where('status', isEqualTo: 'open')
      .limit(200)
      .snapshots()
      .map((s) => _newestFirst(s.docs.map(SupportTicket.fromDoc).toList()));

  static List<SupportTicket> _newestFirst(List<SupportTicket> l) => l..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

  // ---------- Admin ----------
  Stream<List<ProviderProfile>> pendingProviders() => fs
      .collection('providers')
      .where('verificationStatus', isEqualTo: 'pending')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ProviderProfile.fromDoc).toList());

  Stream<List<SosAlert>> sosAlerts({bool openOnly = true}) {
    Query<Map<String, dynamic>> q = fs.collection('sosAlerts');
    if (openOnly) q = q.where('status', whereIn: ['open', 'acknowledged']);
    return q.orderBy('createdAt', descending: true).limit(100).snapshots().map((s) => s.docs.map(SosAlert.fromDoc).toList());
  }

  Stream<List<Dispute>> openDisputes() => fs
      .collection('disputes')
      .where('status', isEqualTo: 'open')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Dispute.fromDoc).toList());

  Stream<List<Withdrawal>> pendingWithdrawals() => fs
      .collection('withdrawals')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Withdrawal.fromDoc).toList());

  Future<List<AppUser>> searchUsers(String text) async {
    final t = text.trim().toLowerCase();
    if (t.contains('@')) {
      final s = await fs.collection('users').where('email', isEqualTo: t).limit(10).get();
      return s.docs.map(AppUser.fromDoc).toList();
    }
    final s = await fs.collection('users').orderBy('createdAt', descending: true).limit(100).get();
    return s.docs.map(AppUser.fromDoc).where((u) => t.isEmpty || u.fullName.toLowerCase().contains(t) || u.phone.contains(t)).toList();
  }

  /// Report counts for a date range (FR-12.5).
  Future<Map<String, int>> report(DateTime from, DateTime to) async {
    Future<int> count(Query<Map<String, dynamic>> q) async => (await q.count().get()).count ?? 0;
    final f = Timestamp.fromDate(from), t = Timestamp.fromDate(to);
    final bookings = fs.collection('bookings').where('createdAt', isGreaterThanOrEqualTo: f).where('createdAt', isLessThan: t);
    final revenueSnap = await fs.collection('revenue').where('createdAt', isGreaterThanOrEqualTo: f).where('createdAt', isLessThan: t).get();
    final commission = revenueSnap.docs.fold<int>(0, (sum, d) => sum + ((d.data()['commissionCents'] as num?)?.toInt() ?? 0));
    return {
      'New users': await count(fs.collection('users').where('createdAt', isGreaterThanOrEqualTo: f).where('createdAt', isLessThan: t)),
      'Bookings': await count(bookings),
      'Completed bookings': await count(bookings.where('status', isEqualTo: BookingStatus.closed)),
      'Cancelled bookings': await count(bookings.where('status', isEqualTo: BookingStatus.cancelled)),
      'Disputes': await count(fs.collection('disputes').where('createdAt', isGreaterThanOrEqualTo: f).where('createdAt', isLessThan: t)),
      'SOS alerts': await count(fs.collection('sosAlerts').where('createdAt', isGreaterThanOrEqualTo: f).where('createdAt', isLessThan: t)),
      'Commission (cents)': commission,
    };
  }
}

class ProviderMatch {
  final ProviderProfile provider;
  final double distanceKm;
  ProviderMatch(this.provider, this.distanceKm);
}
