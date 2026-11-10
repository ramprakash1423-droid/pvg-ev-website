import 'package:flutter/material.dart';
import 'ui.dart';
import 'experience.dart';

/// Compact, task-focused controls for the doorstep charging home.
class ServiceBanner extends StatelessWidget {
  const ServiceBanner({super.key, required this.reducedMotion});
  final bool reducedMotion;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
    duration: Duration(milliseconds: reducedMotion ? 0 : 550),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: child,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/pvg-truck.webp',
              fit: BoxFit.cover,
              alignment: const Alignment(.35, 0),
              semanticLabel: 'Illustration of PVG doorstep charging',
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xf509291f),
                    Color(0xb509291f),
                    Color(0x5509291f),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: lime,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'CHENNAI · DOORSTEP CHARGING',
                        style: TextStyle(
                          color: Color(0xffe3f5cf),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const Text(
                  'Your day.\nFully charged.',
                  style: TextStyle(
                    fontSize: 33,
                    height: 1.02,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 240,
                  child: Text(
                    'Energy delivered where you park.\nMore time for what matters.',
                    style: TextStyle(
                      color: Color(0xffe0e9df),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroPill(Icons.location_on_outlined, 'At your address'),
                    _heroPill(Icons.verified_outlined, 'You approve the bill'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _heroPill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0x221fff99),
      border: Border.all(color: const Color(0x33ffffff)),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: lime),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

class TariffOverview extends StatelessWidget {
  const TariffOverview({super.key, required this.tariff});
  final Map<String, dynamic>? tariff;
  @override
  Widget build(BuildContext context) {
    if (tariff == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xffeaf2df),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffdce8cb)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Clear pricing. Before you book.', color: forest),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _price(
                  money(tariff!['unit_rate_paise']),
                  'per kWh delivered',
                  Icons.bolt_rounded,
                ),
              ),
              Container(width: 1, height: 44, color: const Color(0xffcbd9bc)),
              const SizedBox(width: 18),
              Expanded(
                child: _price(
                  money(tariff!['visit_fee_paise']),
                  'per doorstep visit',
                  Icons.local_shipping_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            '${(tariff!['tax_basis_points'] as num? ?? 0) / 100}% tax applies to energy + visit fee.',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _price(String amount, String label, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 19, color: forest),
      const SizedBox(height: 6),
      Text(
        amount,
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 10, color: muted)),
    ],
  );
}

class ChargingJourney extends StatelessWidget {
  const ChargingJourney({super.key, required this.onHelp});
  final VoidCallback onHelp;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Kicker('A smoother way to recharge'),
        const SizedBox(height: 9),
        const Text(
          'Every step, in your hands.',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 20),
        _step(
          '01',
          Icons.pin_drop_outlined,
          'Choose your place & time',
          'Add your EV, parking address and preferred visit.',
        ),
        _step(
          '02',
          Icons.route_outlined,
          'Follow your charging team',
          'Once assigned, see their shared GPS location here.',
        ),
        _step(
          '03',
          Icons.fact_check_outlined,
          'Review your charge',
          'Check the meter photo and approve the units and bill.',
        ),
        _step(
          '04',
          Icons.receipt_long_outlined,
          'Pay with confidence',
          'Pay after accepting. Keep every visit in your history.',
          last: true,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onHelp,
          child: const Row(
            children: [
              Icon(Icons.help_outline, size: 17),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your charging questions, answered',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _step(
    String number,
    IconData icon,
    String title,
    String copy, {
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 17),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: softLime,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: forest, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                copy,
                style: const TextStyle(fontSize: 11, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          number,
          style: const TextStyle(
            fontSize: 10,
            color: muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class SelectionRow extends StatelessWidget {
  const SelectionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.detail,
  });
  final IconData icon;
  final String label, value;
  final String? detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xffedf3ef),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.expand_more_rounded, size: 20, color: muted),
        ],
      ),
    ),
  );
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      onTap: onTap,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Icon(icon, size: 21, color: forest),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CompactVisitCard extends StatelessWidget {
  const CompactVisitCard({
    super.key,
    required this.booking,
    required this.onOpen,
    required this.onAgain,
    this.highlight = false,
  });
  final Map<String, dynamic> booking;
  final VoidCallback onOpen, onAgain;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final b = booking;
    final action = {
      'assigned': 'Track vehicle',
      'on_the_way': 'Track vehicle',
      'arrived': 'View location',
      'charging': 'View location',
      'awaiting_acceptance': 'Review units & bill',
      'awaiting_payment': 'View bill & pay',
      'disputed': 'View reading query',
    }[b['status']];
    final bill =
        b['invoice']?['bill'] ?? b['reading']?['bill'] ?? b['estimate'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: highlight ? const Color(0xffd6e5ba) : line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        b['reference'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Flexible(child: StatusChip(b['status'])),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xfff2f5f3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.electric_car_outlined, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b['ev']['model'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeLabel(b['slot']),
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b['address'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: muted,
                    ),
                  ],
                ),
              ),
              if (action != null || b['status'] == 'paid')
                Container(
                  color: highlight
                      ? const Color(0xfff4f8e9)
                      : const Color(0xfff7f9f8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  child: Row(
                    children: [
                      if (bill != null)
                        Expanded(
                          child: Text(
                            [
                                  'assigned',
                                  'on_the_way',
                                  'arrived',
                                  'charging',
                                ].contains(b['status'])
                                ? b['fleet_name'] ?? 'Vehicle assigned'
                                : money(bill['total_paise']),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Flexible(
                        child: TextButton(
                          onPressed: b['status'] == 'paid' ? onAgain : onOpen,
                          child: Text(
                            action ?? 'Book again',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EstimateSheet extends StatefulWidget {
  const EstimateSheet({
    super.key,
    required this.tariff,
    required this.initialEnergy,
  });
  final Map<String, dynamic>? tariff;
  final double initialEnergy;
  @override
  State<EstimateSheet> createState() => _EstimateSheetState();
}

class _EstimateSheetState extends State<EstimateSheet> {
  late double energy = widget.initialEnergy;
  @override
  Widget build(BuildContext context) {
    final bill = estimateBill(widget.tariff, energy);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan your top-up',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Adjust the energy to see your estimated total.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                const Icon(Icons.bolt, color: forest),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${energy.toInt()} kWh',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 29,
                    ),
                  ),
                ),
                Text(
                  money(bill['total_paise']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            Slider(
              value: energy,
              min: 5,
              max: 60,
              divisions: 11,
              label: '${energy.toInt()} kWh',
              semanticFormatterCallback: (v) => '${v.toInt()} kilowatt hours',
              onChanged: (v) => setState(() => energy = v),
            ),
            BillLines(bill, estimated: true),
            const Notice(
              'Final charges use actual delivered energy and the agreed tariff. You accept the meter reading and final bill before paying.',
            ),
            PrimaryButton(
              'Use this estimate',
              onPressed: () => Navigator.pop(context, energy),
            ),
          ],
        ),
      ),
    );
  }
}
