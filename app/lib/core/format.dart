import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'theme.dart';

String money(num cents) => '${AppConfig.currencySymbol}${(cents / 100).toStringAsFixed(2)}';

int? parseMoneyToCents(String input) {
  final v = double.tryParse(input.replaceAll(RegExp(r'[^0-9.]'), ''));
  if (v == null) return null;
  return (v * 100).round();
}

final _date = DateFormat('EEE d MMM yyyy');
final _dateTime = DateFormat('d MMM yyyy, HH:mm');
final _time = DateFormat('HH:mm');

String fmtDate(DateTime? d) => d == null ? '' : _date.format(d);
String fmtDateTime(DateTime? d) => d == null ? '' : _dateTime.format(d);
String fmtTime(DateTime? d) => d == null ? '' : _time.format(d);

String statusLabel(String s) => switch (s) {
      BookingStatus.pending => 'Requested',
      BookingStatus.awaitingPayment => 'Awaiting payment',
      BookingStatus.confirmed => 'Confirmed',
      BookingStatus.inTransit => 'On the way',
      BookingStatus.inProgress => 'In progress',
      BookingStatus.completed => 'Done - confirm',
      BookingStatus.closed => 'Completed',
      BookingStatus.cancelled => 'Cancelled',
      BookingStatus.declined => 'Declined',
      BookingStatus.expired => 'Expired',
      BookingStatus.disputed => 'In dispute',
      _ => s,
    };

Color statusColor(String s, ColorScheme c) => switch (s) {
      BookingStatus.pending || BookingStatus.awaitingPayment => AppTheme.warningFor(c),
      BookingStatus.confirmed || BookingStatus.inTransit || BookingStatus.inProgress => c.primary,
      BookingStatus.completed || BookingStatus.closed => AppTheme.successFor(c),
      BookingStatus.disputed => c.error,
      _ => c.outline,
    };

/// Great-circle distance in kilometres.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Normalises Zimbabwean numbers to +263 format for phone auth.
String toE164(String phone) {
  var p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.startsWith('+')) return p;
  if (p.startsWith('263')) return '+$p';
  if (p.startsWith('0')) return '+263${p.substring(1)}';
  return '+263$p';
}

/// Local format (07XXXXXXXX) used by PayNow mobile payments.
String toLocalPhone(String phone) {
  final e = toE164(phone);
  return e.startsWith('+263') ? '0${e.substring(4)}' : phone;
}
