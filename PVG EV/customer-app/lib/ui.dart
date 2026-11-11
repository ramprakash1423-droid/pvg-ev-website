import 'package:flutter/material.dart';
import 'visit_schedule.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

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
  final d = indiaWallTime(DateTime.parse(value as String));
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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: lime,
        foregroundColor: forest,
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          if (icon != null && !busy) ...[
            const SizedBox(width: 9),
            Icon(icon, size: 17),
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
    this.padding = const EdgeInsets.all(16),
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
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: total ? forest : muted,
              fontSize: total ? 14 : 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: total ? 19 : 13,
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

/// A short entrance on navigation, not on polling or each GPS update.
/// One child stays mounted so forms never duplicate controllers or validation.
class MotionEntrance extends StatelessWidget {
  const MotionEntrance({super.key, required this.child, this.disabled = false});
  final Widget child;
  final bool disabled;
  @override
  Widget build(BuildContext context) {
    if (disabled || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: .35 + .65 * value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class PvgPageTransitions extends PageTransitionsBuilder {
  const PvgPageTransitions({this.cupertino = false});
  final bool cupertino;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    if (cupertino) {
      return const CupertinoPageTransitionsBuilder().buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(.025, 0),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}

ThemeData pvgTheme() => ThemeData(
  useMaterial3: true,
  visualDensity: VisualDensity.standard,
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: forest,
    primary: forest,
    secondary: lime,
    surface: canvas,
  ),
  iconTheme: const IconThemeData(size: 20, color: forest),
  appBarTheme: const AppBarTheme(
    toolbarHeight: 52,
    backgroundColor: Colors.white,
    foregroundColor: forest,
    centerTitle: false,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      color: forest,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: forest, size: 20),
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 21,
      color: forest,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      color: forest,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 14,
      color: forest,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      color: forest,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 14, color: forest, height: 1.4),
    bodyMedium: TextStyle(fontSize: 13, color: forest, height: 1.45),
    bodySmall: TextStyle(fontSize: 11, color: muted, height: 1.4),
    labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    labelStyle: const TextStyle(fontSize: 13, color: muted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: forest, width: 1.5),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(40, 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(40, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  chipTheme: ChipThemeData(
    labelStyle: const TextStyle(fontSize: 12, color: forest),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  listTileTheme: const ListTileThemeData(
    minVerticalPadding: 6,
    minLeadingWidth: 28,
    titleTextStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: forest,
    ),
    subtitleTextStyle: TextStyle(fontSize: 11, color: muted, height: 1.4),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: const Color(0xffe8f3d1),
    iconTheme: WidgetStateProperty.all(
      const IconThemeData(size: 20, color: forest),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 10,
        color: forest,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    ),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: PvgPageTransitions(),
      TargetPlatform.iOS: PvgPageTransitions(cupertino: true),
      TargetPlatform.macOS: PvgPageTransitions(),
      TargetPlatform.windows: PvgPageTransitions(),
      TargetPlatform.linux: PvgPageTransitions(),
    },
  ),
);
