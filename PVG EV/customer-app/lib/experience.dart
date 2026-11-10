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
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
      ),
    );
    final link = action == null
        ? null
        : TextButton(onPressed: onTap, child: Text(action!));
    return Padding(
      padding: const EdgeInsets.only(top: 19, bottom: 10),
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
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: softLime,
          ),
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 13),
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          PrimaryButton(action!, onPressed: onTap),
        ],
      ],
    ),
  );
}

Map<String, dynamic> estimateBill(Map<String, dynamic>? tariff, double kwh) {
  final rate = (tariff?['unit_rate_paise'] as num?)?.toInt() ?? 2200;
  final visit = (tariff?['visit_fee_paise'] as num?)?.toInt() ?? 25000;
  final taxRate = (tariff?['tax_basis_points'] as num?)?.toInt() ?? 0;
  final milli = (kwh * 1000).round();
  final energy = (milli * rate / 1000).round();
  final tax = ((visit + energy) * taxRate / 10000).round();
  return {
    'energy_milli': milli,
    'unit_rate_paise': rate,
    'energy_paise': energy,
    'visit_fee_paise': visit,
    'tax_basis_points': taxRate,
    'tax_paise': tax,
    'total_paise': visit + energy + tax,
  };
}

const eventLabels = {
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
