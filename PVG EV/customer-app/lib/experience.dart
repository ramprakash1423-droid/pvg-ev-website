import 'package:flutter/material.dart';
import 'ui.dart';

const midnight = Color(0xff09291f);
const softLime = Color(0xffedf5dc);

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
      ),
    );
    final link = action == null
        ? null
        : TextButton(onPressed: onTap, child: Text(action!));
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: LayoutBuilder(
        builder: (context, box) {
          if (link != null &&
              (box.maxWidth < 380 ||
                  MediaQuery.textScalerOf(context).scale(14) > 16)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, link],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              ?link,
            ],
          );
        },
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onTap,
  });
  final IconData icon;
  final String title, text;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: softLime,
          ),
          child: Icon(icon, size: 25),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 13),
        ),
        if (action != null) ...[
          const SizedBox(height: 14),
          PrimaryButton(action!, onPressed: onTap),
        ],
      ],
    ),
  );
}

const eventLabels = {
  'rescheduled': 'New visit time requested',
  'support_requested': 'Support request received',
  'support_updated': 'PVG replied to your support request',
  'service_update': 'An update from your charging team',
  'visit_unavailable': 'Visit could not proceed',
  'gps_started': 'Technician enabled GPS sharing',
  'gps_stopped': 'GPS sharing stopped',
  'requested': 'Charging visit requested',
  'assigned': 'Your visit is confirmed',
  'on_the_way': 'Your technician is on the way',
  'arrived': 'Your technician has arrived',
  'charging': 'Charging has started',
  'reading_submitted': 'Meter reading ready to review',
  'accepted': 'You accepted the reading',
  'customer_accepted': 'You accepted the reading',
  'disputed': 'Your reading query was received',
  'customer_reported_issue': 'Your reading query was received',
  'cancelled': 'Visit cancelled',
  'payment_verified': 'Payment verified',
};
String eventLabel(String action) =>
    eventLabels[action] ?? statuses[action] ?? action.replaceAll('_', ' ');
