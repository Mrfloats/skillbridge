import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : null;
List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
int _int(dynamic v) => v is num ? v.toInt() : 0;
double _double(dynamic v) => v is num ? v.toDouble() : 0;

class TrustedContact {
  final String name;
  final String phone;
  const TrustedContact(this.name, this.phone);
  factory TrustedContact.fromMap(Map<String, dynamic> m) => TrustedContact(m['name'] ?? '', m['phone'] ?? '');
  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
}

class AppUser {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String? photoUrl;
  final bool isSuspended;
  final bool phoneVerified;
  final List<TrustedContact> trustedContacts;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.photoUrl,
    this.isSuspended = false,
    this.phoneVerified = false,
    this.trustedContacts = const [],
    this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      uid: d.id,
      fullName: m['fullName'] ?? '',
      email: m['email'] ?? '',
      phone: m['phone'] ?? '',
      role: m['role'] ?? 'client',
      photoUrl: m['photoUrl'],
      isSuspended: m['isSuspended'] == true,
      phoneVerified: m['phoneVerified'] == true,
      trustedContacts: (m['trustedContacts'] as List? ?? [])
          .map((e) => TrustedContact.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: _dt(m['createdAt']),
    );
  }
}

class ProviderProfile {
  final String uid;
  final String fullName;
  final String? photoUrl;
  final String phone;
  final String bio;
  final int experienceYears;
  final List<String> categoryIds;
  final GeoPoint? baseLocation;
  final String baseAddress;
  final double serviceRadiusKm;
  final String workingHours;
  final bool isAvailable;
  final bool isVerified;
  final bool isSuspended;
  final String verificationStatus;
  final String? rejectionReason;
  final double avgRating;
  final int reviewCount;
  final int completedJobs;
  final List<String> portfolioUrls;

  ProviderProfile({
    required this.uid,
    required this.fullName,
    this.photoUrl,
    this.phone = '',
    this.bio = '',
    this.experienceYears = 0,
    this.categoryIds = const [],
    this.baseLocation,
    this.baseAddress = '',
    this.serviceRadiusKm = 10,
    this.workingHours = 'Mon-Sat 08:00-18:00',
    this.isAvailable = true,
    this.isVerified = false,
    this.isSuspended = false,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.avgRating = 0,
    this.reviewCount = 0,
    this.completedJobs = 0,
    this.portfolioUrls = const [],
  });

  factory ProviderProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ProviderProfile(
      uid: d.id,
      fullName: m['fullName'] ?? '',
      photoUrl: m['photoUrl'],
      phone: m['phone'] ?? '',
      bio: m['bio'] ?? '',
      experienceYears: _int(m['experienceYears']),
      categoryIds: _strings(m['categoryIds']),
      baseLocation: m['baseLocation'] as GeoPoint?,
      baseAddress: m['baseAddress'] ?? '',
      serviceRadiusKm: m['serviceRadiusKm'] == null ? 10 : _double(m['serviceRadiusKm']),
      workingHours: m['workingHours'] ?? '',
      isAvailable: m['isAvailable'] != false,
      isVerified: m['isVerified'] == true,
      isSuspended: m['isSuspended'] == true,
      verificationStatus: m['verificationStatus'] ?? 'pending',
      rejectionReason: m['rejectionReason'],
      avgRating: _double(m['avgRating']),
      reviewCount: _int(m['reviewCount']),
      completedJobs: _int(m['completedJobs']),
      portfolioUrls: _strings(m['portfolioUrls']),
    );
  }

  /// Editable fields only; rating and verification fields are server-managed.
  Map<String, dynamic> toEditableMap() => {
        'fullName': fullName,
        'photoUrl': photoUrl,
        'phone': phone,
        'bio': bio,
        'experienceYears': experienceYears,
        'categoryIds': categoryIds,
        'baseLocation': baseLocation,
        'baseAddress': baseAddress,
        'serviceRadiusKm': serviceRadiusKm,
        'workingHours': workingHours,
        'isAvailable': isAvailable,
        'portfolioUrls': portfolioUrls,
      };
}

class ServiceCategory {
  final String id;
  final String name;
  final String icon;
  final int order;
  ServiceCategory(this.id, this.name, this.icon, this.order);
  factory ServiceCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ServiceCategory(d.id, m['name'] ?? d.id, m['icon'] ?? 'build', _int(m['order']));
  }
}

class ProviderService {
  final String id;
  final String providerId;
  final String categoryId;
  final String title;
  final int basePriceCents;
  final String priceType; // 'fixed' | 'quote'
  ProviderService({
    required this.id,
    required this.providerId,
    required this.categoryId,
    required this.title,
    required this.basePriceCents,
    required this.priceType,
  });
  factory ProviderService.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ProviderService(
      id: d.id,
      providerId: m['providerId'] ?? '',
      categoryId: m['categoryId'] ?? '',
      title: m['title'] ?? '',
      basePriceCents: _int(m['basePriceCents']),
      priceType: m['priceType'] ?? 'quote',
    );
  }
  Map<String, dynamic> toMap() => {
        'providerId': providerId,
        'categoryId': categoryId,
        'title': title,
        'basePriceCents': basePriceCents,
        'priceType': priceType,
      };
}

class RescheduleRequest {
  final String requestedBy;
  final DateTime serviceDate;
  final String timeSlot;
  RescheduleRequest(this.requestedBy, this.serviceDate, this.timeSlot);
}

class TimelineEntry {
  final String status;
  final DateTime? at;
  TimelineEntry(this.status, this.at);
}

class Booking {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String providerId;
  final String providerName;
  final String? providerPhotoUrl;
  final String providerServiceId;
  final String categoryId;
  final String serviceTitle;
  final DateTime serviceDate;
  final String timeSlot;
  final String address;
  final GeoPoint? location;
  final String description;
  final List<String> photoUrls;
  final String status;
  final int? quotedFeeCents;
  final int? commissionCents;
  final String paymentStatus;
  final String? paymentId;
  final bool reviewed;
  final RescheduleRequest? reschedule;
  final List<TimelineEntry> timeline;
  final DateTime? createdAt;
  final DateTime? completedAt;

  Booking({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.providerId,
    required this.providerName,
    this.providerPhotoUrl,
    required this.providerServiceId,
    required this.categoryId,
    required this.serviceTitle,
    required this.serviceDate,
    required this.timeSlot,
    required this.address,
    this.location,
    required this.description,
    this.photoUrls = const [],
    required this.status,
    this.quotedFeeCents,
    this.commissionCents,
    this.paymentStatus = 'none',
    this.paymentId,
    this.reviewed = false,
    this.reschedule,
    this.timeline = const [],
    this.createdAt,
    this.completedAt,
  });

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final r = m['rescheduleRequest'];
    return Booking(
      id: d.id,
      clientId: m['clientId'] ?? '',
      clientName: m['clientName'] ?? '',
      clientPhone: m['clientPhone'] ?? '',
      providerId: m['providerId'] ?? '',
      providerName: m['providerName'] ?? '',
      providerPhotoUrl: m['providerPhotoUrl'],
      providerServiceId: m['providerServiceId'] ?? '',
      categoryId: m['categoryId'] ?? '',
      serviceTitle: m['serviceTitle'] ?? '',
      serviceDate: _dt(m['serviceDate']) ?? DateTime.now(),
      timeSlot: m['timeSlot'] ?? '',
      address: m['address'] ?? '',
      location: m['location'] as GeoPoint?,
      description: m['description'] ?? '',
      photoUrls: _strings(m['photoUrls']),
      status: m['status'] ?? 'pending',
      quotedFeeCents: m['quotedFeeCents'] == null ? null : _int(m['quotedFeeCents']),
      commissionCents: m['commissionCents'] == null ? null : _int(m['commissionCents']),
      paymentStatus: m['paymentStatus'] ?? 'none',
      paymentId: m['paymentId'],
      reviewed: m['reviewed'] == true,
      reschedule: r is Map
          ? RescheduleRequest(r['requestedBy'] ?? '', _dt(r['serviceDate']) ?? DateTime.now(), r['timeSlot'] ?? '')
          : null,
      timeline: (m['timeline'] as List? ?? [])
          .map((e) => TimelineEntry((e as Map)['status'] ?? '', _dt(e['at'])))
          .toList(),
      createdAt: _dt(m['createdAt']),
      completedAt: _dt(m['completedAt']),
    );
  }
}

class Review {
  final String id;
  final String bookingId;
  final String clientId;
  final String clientName;
  final String providerId;
  final int rating;
  final String comment;
  final String? providerReply;
  final bool isHidden;
  final DateTime? createdAt;
  Review({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.clientName,
    required this.providerId,
    required this.rating,
    required this.comment,
    this.providerReply,
    this.isHidden = false,
    this.createdAt,
  });
  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Review(
      id: d.id,
      bookingId: m['bookingId'] ?? d.id,
      clientId: m['clientId'] ?? '',
      clientName: m['clientName'] ?? '',
      providerId: m['providerId'] ?? '',
      rating: _int(m['rating']),
      comment: m['comment'] ?? '',
      providerReply: m['providerReply'],
      isHidden: m['isHidden'] == true,
      createdAt: _dt(m['createdAt']),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? readAt;
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageUrl,
    this.createdAt,
    this.readAt,
  });
  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ChatMessage(
      id: d.id,
      senderId: m['senderId'] ?? '',
      senderName: m['senderName'] ?? '',
      text: m['text'] ?? '',
      imageUrl: m['imageUrl'],
      createdAt: _dt(m['createdAt']),
      readAt: _dt(m['readAt']),
    );
  }
}

class WalletTxn {
  final String id;
  final String type;
  final int amountCents;
  final String note;
  final DateTime? createdAt;
  WalletTxn(this.id, this.type, this.amountCents, this.note, this.createdAt);
  factory WalletTxn.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return WalletTxn(d.id, m['type'] ?? '', _int(m['amountCents']), m['note'] ?? '', _dt(m['createdAt']));
  }
}

class Withdrawal {
  final String id;
  final String userId;
  final int amountCents;
  final String method;
  final String destination;
  final String status;
  final DateTime? createdAt;
  Withdrawal(this.id, this.userId, this.amountCents, this.method, this.destination, this.status, this.createdAt);
  factory Withdrawal.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Withdrawal(d.id, m['userId'] ?? '', _int(m['amountCents']), m['method'] ?? '', m['destination'] ?? '',
        m['status'] ?? 'pending', _dt(m['createdAt']));
  }
}

class SosAlert {
  final String id;
  final String bookingId;
  final String userId;
  final String userName;
  final String userPhone;
  final String otherPartyName;
  final GeoPoint? location;
  final String status;
  final DateTime? createdAt;
  SosAlert(this.id, this.bookingId, this.userId, this.userName, this.userPhone, this.otherPartyName, this.location,
      this.status, this.createdAt);
  factory SosAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return SosAlert(d.id, m['bookingId'] ?? '', m['userId'] ?? '', m['userName'] ?? '', m['userPhone'] ?? '',
        m['otherPartyName'] ?? '', m['location'] as GeoPoint?, m['status'] ?? 'open', _dt(m['createdAt']));
  }
}

class Dispute {
  final String id;
  final String bookingId;
  final String raisedBy;
  final String reason;
  final String status;
  final String? outcome;
  final DateTime? createdAt;
  Dispute(this.id, this.bookingId, this.raisedBy, this.reason, this.status, this.outcome, this.createdAt);
  factory Dispute.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Dispute(d.id, m['bookingId'] ?? d.id, m['raisedBy'] ?? '', m['reason'] ?? '', m['status'] ?? 'open',
        m['outcome'], _dt(m['createdAt']));
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? refId;
  final bool isRead;
  final DateTime? createdAt;
  AppNotification(this.id, this.title, this.body, this.type, this.refId, this.isRead, this.createdAt);
  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppNotification(d.id, m['title'] ?? '', m['body'] ?? '', m['type'] ?? '', m['refId'], m['isRead'] == true,
        _dt(m['createdAt']));
  }
}
