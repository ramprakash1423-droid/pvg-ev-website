import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pvg_customer/experience.dart';
import 'package:pvg_customer/ui.dart';

void main() {
  testWidgets(
    'bill shows the configured tax rate alongside its amount and total',
    (tester) async {
      final bill = estimateBill({
        'unit_rate_paise': 5000,
        'visit_fee_paise': 30000,
        'tax_basis_points': 1800,
      }, 15);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BillLines(bill, estimated: true))),
      );
      expect(find.text('Tax (18.0%)'), findsOneWidget);
      expect(find.text('₹189.00'), findsOneWidget);
      expect(find.text('₹1239.00'), findsOneWidget);
    },
  );
}
