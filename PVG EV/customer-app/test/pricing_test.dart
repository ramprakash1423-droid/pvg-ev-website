import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pvg_customer/ui.dart';

void main() {
  testWidgets('completed-reading bill renders the server-calculated charges', (
    tester,
  ) async {
    // Only the server calculates the bill from the technician's delivered units.
    final bill = <String, dynamic>{
      'energy_milli': 15000,
      'unit_rate_paise': 2000,
      'energy_paise': 30000,
      'visit_fee_paise': 30000,
      'tax_basis_points': 1800,
      'tax_paise': 10800,
      'total_paise': 70800,
    };
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BillLines(bill))));
    expect(find.text('Energy delivered'), findsOneWidget);
    expect(find.text('₹20.00'), findsOneWidget);
    expect(find.text('Tax (18.0%)'), findsOneWidget);
    expect(find.text('₹108.00'), findsOneWidget);
    expect(find.text('₹708.00'), findsOneWidget);
  });
}
