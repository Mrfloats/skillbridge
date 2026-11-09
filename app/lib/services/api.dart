import 'package:cloud_functions/cloud_functions.dart';

import '../core/constants.dart';

/// Calls to Cloud Functions. Every money or status change goes through here (NFR-2.4).
class Api {
  Api._();
  static final instance = Api._();

  final _fn = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final res = await _fn.httpsCallable(name).call(data);
      final raw = res.data;
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw ApiException(e.message ?? 'Request failed. Please try again.');
    }
  }

  // Bookings
  Future<void> respondToBooking(String bookingId, {required bool accept, int? feeCents}) => _call('respondToBooking', {'bookingId': bookingId, 'accept': accept, 'feeCents': feeCents});
  Future<void> acceptQuote(String bookingId) => _call('acceptQuote', {'bookingId': bookingId});
  Future<void> updateJobStatus(String bookingId, String status) => _call('updateJobStatus', {'bookingId': bookingId, 'status': status});
  Future<void> confirmCompletion(String bookingId) => _call('confirmCompletion', {'bookingId': bookingId});
  Future<int> cancelBooking(String bookingId, String reason) async {
    final r = await _call('cancelBooking', {'bookingId': bookingId, 'reason': reason});
    return (r['refundCents'] as num?)?.toInt() ?? 0;
  }

  Future<void> raiseDispute(String bookingId, String reason) => _call('raiseDispute', {'bookingId': bookingId, 'reason': reason});
  Future<void> respondToReschedule(String bookingId, bool accept) => _call('respondToReschedule', {'bookingId': bookingId, 'accept': accept});

  // Payments
  Future<PaymentStart> startTopUp(int amountCents, String method, String? phone) async {
    final r = await _call('startTopUp', {'amountCents': amountCents, 'method': method, 'phone': phone});
    return PaymentStart(r['paymentId'] as String, r['redirectUrl'] as String?, r['instructions'] as String?);
  }

  Future<String> checkPayment(String paymentId) async => (await _call('checkPayment', {'paymentId': paymentId}))['status'] as String;
  Future<void> requestWithdrawal(int amountCents, String method, String destination) => _call('requestWithdrawal', {'amountCents': amountCents, 'method': method, 'destination': destination});

  // Account and support
  Future<void> deleteAccount() => _call('deleteAccount', {});
  Future<void> contactSupport(String topic, String message) => _call('contactSupport', {'topic': topic, 'message': message});
  Future<void> resolveSupportTicket(String ticketId, {String? note}) => _call('resolveSupportTicket', {'ticketId': ticketId, 'note': note});

  // Trust & safety
  Future<void> rateClient(String bookingId, int rating) => _call('rateClient', {'bookingId': bookingId, 'rating': rating});
  Future<void> reportContent(String targetType, String targetId, String reason) => _call('reportContent', {'targetType': targetType, 'targetId': targetId, 'reason': reason});

  // Admin
  Future<void> reviewProvider(String providerId, bool approve, {String? reason}) => _call('reviewProvider', {'providerId': providerId, 'approve': approve, 'reason': reason});
  Future<void> setUserSuspended(String userId, bool suspended) => _call('setUserSuspended', {'userId': userId, 'suspended': suspended});
  Future<void> setReviewHidden(String reviewId, bool hidden) => _call('setReviewHidden', {'reviewId': reviewId, 'hidden': hidden});
  Future<void> resolveDispute(String bookingId, String outcome, {int? providerPercent, String? note}) =>
      _call('resolveDispute', {'bookingId': bookingId, 'outcome': outcome, 'providerPercent': providerPercent, 'note': note});
  Future<void> resolveSos(String alertId, String status, {String? note}) => _call('resolveSos', {'alertId': alertId, 'status': status, 'note': note});
  Future<void> markWithdrawalPaid(String withdrawalId, {String? reference, bool reject = false}) =>
      _call('markWithdrawalPaid', {'withdrawalId': withdrawalId, 'reference': reference, 'reject': reject});
}

class PaymentStart {
  final String paymentId;
  final String? redirectUrl;
  final String? instructions;
  PaymentStart(this.paymentId, this.redirectUrl, this.instructions);
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
