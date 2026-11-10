import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/service_availability.dart';
import 'package:pvg_customer/visit_controls.dart';

void main() {
  testWidgets(
    'area check shows the server waiting state, never invented slots',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final api = PvgApi(
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, '/api/availability');
          expect(r.url.queryParameters['pincode'], '600020');
          return http.Response(
            jsonEncode({
              'state': 'confirmation_required',
              'slots': [],
              'message': 'PVG will confirm your preferred time.',
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceAvailability(api: api, onBook: () {}),
          ),
        ),
      );
      await tester.tap(find.text('Check area'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check availability'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Enter a six-digit pincode.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '600020');
      await tester.tap(find.text('Check availability'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.text('PVG will confirm your preferred time.'),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets(
    'support sends the owned booking version and displays staff response',
    (tester) async {
      Map<String, dynamic>? sent;
      var refreshed = false;
      final api = PvgApi(
        client: MockClient((r) async {
          expect(r.url.path, '/api/bookings/owned-visit/support');
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );
      Map<String, dynamic> booking = {
        'id': 'owned-visit',
        'version': 7,
        'status': 'assigned',
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
      expect(find.text('Change visit time'), findsOneWidget);
      await tester.tap(find.text('Send a support request'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send request'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byType(TextField),
        'Please confirm the visit timing.',
      );
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(sent, {
        'version': 7,
        'category': 'arrival',
        'message': 'Please confirm the visit timing.',
      });
      expect(refreshed, isTrue);
      expect(tester.takeException(), isNull);
      booking = {
        ...booking,
        'status': 'on_the_way',
        'support_request': {
          'status': 'in_progress',
          'message': 'Please confirm the visit timing.',
          'response': 'Your charging team has departed.',
        },
      };
      await tester.pumpWidget(screen());
      expect(find.text('Change visit time'), findsNothing);
      expect(find.text('Send a support request'), findsNothing);
      expect(find.text('Support · In progress'), findsOneWidget);
      expect(
        find.text('PVG: Your charging team has departed.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
}
