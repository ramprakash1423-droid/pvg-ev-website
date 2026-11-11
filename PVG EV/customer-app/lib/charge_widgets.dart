import 'package:flutter/material.dart';
import 'ui.dart';
import 'experience.dart';

/// Compact, task-focused controls for the doorstep charging home.
class ServiceBanner extends StatelessWidget {
  const ServiceBanner({super.key, required this.reducedMotion});
  final bool reducedMotion;
  @override
  Widget build(BuildContext context) => MotionEntrance(
    disabled: reducedMotion,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 14),
                const Text(
                  'Your day. Fully charged.',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.02,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.65,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  width: 280,
                  child: Text(
                    'Doorstep charging. On your schedule.',
                    style: TextStyle(
                      color: Color(0xffe0e9df),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

class ChargingJourney extends StatelessWidget {
  const ChargingJourney({super.key, required this.onHelp});
  final VoidCallback onHelp;
  @override
  Widget build(BuildContext context) => Panel(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      key: const PageStorageKey('doorstep-guide'),
      expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 200)),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      childrenPadding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      leading: const Icon(Icons.route_outlined, size: 21),
      title: const Text(
        'How doorstep charging works',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Book · track · review · pay',
        style: TextStyle(fontSize: 11, color: muted),
      ),
      children: [
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline, size: 17),
            label: const Text('Help & charging guide'),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Icon(icon, size: 18, color: forest),
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
    final action =
        {
          'requested': 'View request',
          'assigned': 'Track vehicle',
          'on_the_way': 'Track vehicle',
          'arrived': 'View visit',
          'charging': 'View visit',
          'awaiting_acceptance': 'Review units & bill',
          'awaiting_payment': 'View bill & pay',
          'disputed': 'View reading query',
          'paid': 'Book again',
          'cancelled': 'Book again',
        }[b['status']] ??
        'View visit';
    final bill = b['invoice']?['bill'] ?? b['reading']?['bill'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: highlight ? const Color(0xffb7cd8a) : line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b['reference'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                    Flexible(child: StatusChip(b['status'])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: canvas,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.electric_car_outlined, size: 20),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b['ev']['model'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            timeLabel(b['slot']),
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            b['address'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (bill != null)
                      Expanded(
                        child: Text(
                          money(bill['total_paise']),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Flexible(
                      child: TextButton.icon(
                        onPressed: ['paid', 'cancelled'].contains(b['status'])
                            ? onAgain
                            : onOpen,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                        label: Text(action),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
