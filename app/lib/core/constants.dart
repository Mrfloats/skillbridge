/// App-wide constants. Business rules that affect money live in functions/src/config.ts.
class AppConfig {
  static const appName = 'SkillBridge';
  static const tagline = 'Trusted help, close to home';
  static const functionsRegion = 'europe-west1';
  static const currencySymbol = 'US\$';
  static const maxTrustedContacts = 3;
  static const defaultSearchRadiusKm = 15.0;

  /// Harare city centre, used when location permission is denied.
  static const harareLat = -17.8292;
  static const harareLng = 31.0522;

  /// Bookable time slots (FR-5.1). Must match the slot ids the backend locks.
  static const timeSlots = [
    '08:00-10:00',
    '10:00-12:00',
    '12:00-14:00',
    '14:00-16:00',
    '16:00-18:00',
  ];
}

/// Booking statuses, matching functions/src/config.ts.
class BookingStatus {
  static const pending = 'pending';
  static const awaitingPayment = 'awaiting_payment';
  static const confirmed = 'confirmed';
  static const inTransit = 'in_transit';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const closed = 'closed';
  static const cancelled = 'cancelled';
  static const declined = 'declined';
  static const expired = 'expired';
  static const disputed = 'disputed';

  static const active = [pending, awaitingPayment, confirmed, inTransit, inProgress, completed, disputed];
  static const onSite = [confirmed, inTransit, inProgress];
}

class Roles {
  static const client = 'client';
  static const provider = 'provider';
  static const admin = 'admin';
}
