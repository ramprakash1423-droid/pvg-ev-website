import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/visit_controls.dart';

void main() {
  testWidgets(
    'customer can remove an incorrect parking pin without changing the address',
    (tester) async {
      Map<String, dynamic>? sent;
      var refreshed = false;
      final api = PvgApi(
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/bookings/owned-visit/location');
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );
      Map<String, dynamic> booking = {
        'id': 'owned-visit', 'version': 7, 'status': 'requested',
        'address': 'Owner-provided charging address',
        // Deliberately invalid coordinates in an isolated widget test only.
        'latitude': 0, 'longitude': 0,
      };
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: VisitControls(
            api: api,
            booking: booking,
            onChanged: () async {
              refreshed = true;
            },
          ),
        ),
      );
      await tester.pumpWidget(screen());
      expect(find.textContaining('outside the Chennai area'), findsOneWidget);
      expect(find.text('Update parking pin'), findsOneWidget);
      await tester.tap(find.text('Remove parking pin'));
      await tester.pumpAndSettle();
      expect(sent, {'version': 7, 'latitude': null, 'longitude': null});
      expect(sent!.containsKey('address'), isFalse);
      expect(refreshed, isTrue);
      expect(tester.takeException(), isNull);
      booking = {...booking, 'latitude': null, 'longitude': null};
      await tester.pumpWidget(screen());
      expect(find.text('Remove parking pin'), findsNothing);
      expect(find.textContaining('outside the Chennai area'), findsNothing);
      expect(find.text('Add parking pin'), findsOneWidget);
      booking = {...booking, 'status': 'on_the_way'};
      await tester.pumpWidget(screen());
      expect(find.text('Add parking pin'), findsNothing);
      expect(find.text('Update parking pin'), findsNothing);
      expect(find.text('Remove parking pin'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
}
