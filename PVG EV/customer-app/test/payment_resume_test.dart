import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/booking_detail.dart';

Map<String, dynamic> booking(String status) => {
  'id': 'owned-payment-visit',
  'reference': 'PVG-UNIT-TEST',
  'version': 8,
  'status': status,
  'slot': '2030-01-02T04:30:00Z',
  'ev': {'model': 'Isolated EV', 'registration': 'UNIT TEST'},
  'address': 'Isolated widget-test address',
  'technician': null,
  'reading': null,
  'events': [],
  'invoice': {
    'payment_status': status == 'paid' ? 'paid' : 'unpaid',
    'bill': {'total_paise': 70800},
  },
};

Future<void> returnToApp(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  // Reconciliation and its following GET are separate asynchronous requests.
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  for (final captured in [true, false]) {
    testWidgets(
      'returning from checkout reconciles ${captured ? 'captured' : 'unpaid'} payment and reloads the visit',
      (tester) async {
        String status = 'awaiting_payment';
        final requests = <String>[];
        Map<String, dynamic>? refreshPayload;
        final api = PvgApi(
          client: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.url.path.endsWith('/payment-refresh')) {
              refreshPayload = jsonDecode(request.body) as Map<String, dynamic>;
              if (captured) status = 'paid';
              return http.Response(jsonEncode({'paid': captured}), 200);
            }
            return http.Response(jsonEncode(booking(status)), 200);
          }),
        );
        addTearDown(api.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: BookingDetail(api: api, bookingId: 'owned-payment-visit'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ready to pay'), findsOneWidget);
        expect(requests, ['GET /api/bookings/owned-payment-visit']);

        await returnToApp(tester);

        expect(requests, [
          'GET /api/bookings/owned-payment-visit',
          'POST /api/bookings/owned-payment-visit/payment-refresh',
          'GET /api/bookings/owned-payment-visit',
        ]);
        expect(refreshPayload, isEmpty);
        if (captured) {
          expect(find.text('Paid · test payment'), findsOneWidget);
          expect(find.text('All charged up.'), findsOneWidget);
          expect(find.text('Pay ₹708.00 · test'), findsNothing);
        } else {
          expect(find.text('Ready to pay'), findsOneWidget);
          expect(find.text('All charged up.'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'resuming another visit status refreshes data without checking the payment provider',
    (tester) async {
      final requests = <String>[];
      final api = PvgApi(
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          expect(request.method, 'GET');
          expect(request.url.path, '/api/bookings/owned-payment-visit');
          return http.Response(jsonEncode(booking('cancelled')), 200);
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: BookingDetail(api: api, bookingId: 'owned-payment-visit'),
        ),
      );
      await tester.pumpAndSettle();
      await returnToApp(tester);
      expect(requests, [
        'GET /api/bookings/owned-payment-visit',
        'GET /api/bookings/owned-payment-visit',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
