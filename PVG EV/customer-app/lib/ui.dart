import 'package:flutter/material.dart';

const forest = Color(0xff12352a),
    lime = Color(0xffcef25b),
    canvas = Color(0xfff5f7f8),
    muted = Color(0xff6b7b70),
    line = Color(0xffe5eaec);
String money(dynamic paise) =>
    '₹${((paise as num? ?? 0) / 100).toStringAsFixed(2)}';
String errorText(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
String timeLabel(dynamic value) {
  final d = DateTime.parse(value as String).toLocal();
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
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${months[d.month - 1]} · $hour:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

const statuses = {
  'requested': 'Request received',
  'assigned': 'Visit confirmed',
  'on_the_way': 'On the way',
  'arrived': 'Technician arrived',
  'charging': 'Charging in progress',
  'awaiting_acceptance': 'Ready for your review',
  'awaiting_payment': 'Ready to pay',
  'paid': 'Paid · test payment',
  'disputed': 'Issue reported',
  'cancelled': 'Cancelled',
};

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color = muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: color,
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.text, {
    required this.onPressed,
    this.busy = false,
    this.icon = Icons.arrow_forward_rounded,
    super.key,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: lime,
        foregroundColor: forest,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          if (icon != null && !busy) ...[
            const SizedBox(width: 14),
            Icon(icon, size: 20),
          ],
        ],
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    super.key,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color == Colors.white ? line : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xffffeee4) : const Color(0xffeaf1df),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: error ? const Color(0xff8e4228) : const Color(0xff526b40),
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: status == 'disputed'
          ? const Color(0xffffe9dd)
          : const Color(0xffe9f1db),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      statuses[status] ?? status,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: forest,
      ),
    ),
  );
}

class BillLines extends StatelessWidget {
  const BillLines(this.bill, {super.key, this.estimated = false});
  final Map<String, dynamic> bill;
  final bool estimated;
  Widget row(String title, String value, {bool total = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: total ? forest : muted,
              fontSize: total ? 17 : 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: total ? 23 : 14,
            fontWeight: total ? FontWeight.w700 : FontWeight.w500,
            color: forest,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      row(
        estimated ? 'Estimated energy' : 'Energy delivered',
        '${(bill['energy_milli'] as num) / 1000} kWh',
      ),
      row('Rate per kWh', money(bill['unit_rate_paise'])),
      row('Energy charge', money(bill['energy_paise'])),
      row('Visit fee', money(bill['visit_fee_paise'])),
      row(
        'Tax (${(bill['tax_basis_points'] as num? ?? 0) / 100}%)',
        money(bill['tax_paise']),
      ),
      const Divider(color: line, height: 22),
      row('Total', money(bill['total_paise']), total: true),
    ],
  );
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
