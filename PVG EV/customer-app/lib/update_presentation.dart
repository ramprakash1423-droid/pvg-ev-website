import 'package:flutter/material.dart';
import 'visit_schedule.dart';

/// Keep GPS permission/session changes available in the audit history without
/// making them compete with customer-facing service updates.
bool isCustomerUpdate(Map<String, dynamic> event) =>
    !['gps_started', 'gps_stopped'].contains(event['action']);

String customerUpdateNote(Map<String, dynamic> event) {
  const visibleNotes = {
    'support_updated',
    'support_requested',
    'service_update',
    'visit_unavailable',
    'customer_reported_issue',
  };
  return visibleNotes.contains(event['action']) && event['note'] is String
      ? (event['note'] as String).trim()
      : '';
}

bool visitNeedsAttention(Map<String, dynamic> booking) => [
  'awaiting_acceptance',
  'awaiting_payment',
  'disputed',
].contains(booking['status']);

String visitActionLabel(Map<String, dynamic> booking) =>
    switch (booking['status']) {
      'awaiting_acceptance' => 'Review units & bill',
      'awaiting_payment' => 'View bill & pay',
      'disputed' => 'View reading query',
      _ => 'View visit',
    };

IconData updateIcon(String? action) => switch (action) {
  'assigned' => Icons.verified_outlined,
  'on_the_way' => Icons.local_shipping_outlined,
  'arrived' || 'location_updated' => Icons.location_on_outlined,
  'charging' => Icons.bolt_rounded,
  'reading_submitted' => Icons.fact_check_outlined,
  'accepted' || 'customer_accepted' => Icons.task_alt,
  'payment_verified' => Icons.receipt_long_outlined,
  'support_updated' ||
  'support_requested' ||
  'service_update' => Icons.chat_bubble_outline_rounded,
  'cancelled' ||
  'visit_unavailable' ||
  'customer_reported_issue' ||
  'disputed' => Icons.info_outline_rounded,
  'gps_started' || 'gps_stopped' => Icons.gps_fixed_rounded,
  _ => Icons.event_outlined,
};

String updateDayLabel(String value, {DateTime? now}) {
  final date = indiaWallTime(DateTime.parse(value));
  final today = indiaWallTime(now ?? DateTime.now());
  final difference = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}${date.year == today.year ? '' : ' ${date.year}'}';
}
